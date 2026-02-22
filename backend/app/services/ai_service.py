from __future__ import annotations

import base64
import json

from groq import Groq

from app.config import get_settings
from app.models.schemas import ChatResponse, PantryIngredient, RecipeAssistantResponse, RecipeDetail


class AIService:
    def __init__(self) -> None:
        self.settings = get_settings()

    def _resolve_api_key(self, custom_api_key: str | None) -> str:
        api_key = custom_api_key or self.settings.groq_api_key
        if not api_key:
            raise ValueError("No Groq API key provided")
        return api_key

    def transcribe_audio(self, audio_base64: str, custom_api_key: str | None) -> str:
        api_key = self._resolve_api_key(custom_api_key)
        audio_bytes = base64.b64decode(audio_base64)
        client = Groq(api_key=api_key)
        transcript = client.audio.transcriptions.create(
            file=("audio.wav", audio_bytes),
            model="whisper-large-v3",
        )
        return transcript.text

    def generate_recipe_cards(
        self,
        user_query: str,
        pantry_items: list[PantryIngredient],
        custom_api_key: str | None,
        extra_budget_inr: str | None = None,
        people_count: int | None = None,
    ) -> ChatResponse:
        api_key = self._resolve_api_key(custom_api_key)
        client = Groq(api_key=api_key)

        pantry_list = [
            f"{item.name} ({item.quantity or 'unspecified quantity'})"
            for item in pantry_items
            if item.is_in_stock
        ]

        system_prompt = (
            "Role: You are PantryPilot, a smart cooking assistant. "
            "Return strict JSON only. Keys: thought (string), dishes (array). "
            "Each dish needs name, match_score (0-100), missing_items (name,cost_est), "
            "and cooking_time. Use INR currency when estimating costs."
        )

        budget_line = (
            f"Extra Budget (INR): {extra_budget_inr}\n"
            if extra_budget_inr and extra_budget_inr.strip()
            else ""
        )
        people_line = (
            f"People to cook for: {people_count}\n"
            if people_count is not None and people_count > 0
            else ""
        )

        user_prompt = (
            f"User Inventory: {pantry_list}\n"
            f"User Query: {user_query}\n"
            f"{budget_line}"
            f"{people_line}"
            "Suggest 2 to 5 dishes based strictly on inventory + query."
        )

        completion = client.chat.completions.create(
            model="openai/gpt-oss-120b",
            temperature=0.2,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        )

        content = completion.choices[0].message.content
        data = json.loads(content)
        data = self._normalize_chat_payload(data)
        return ChatResponse.model_validate(data)

    def _normalize_chat_payload(self, data: dict) -> dict:
        dishes = data.get("dishes")
        if not isinstance(dishes, list):
            return data

        for dish in dishes:
            if not isinstance(dish, dict):
                continue

            if "cooking_time" in dish and dish["cooking_time"] is not None:
                dish["cooking_time"] = str(dish["cooking_time"])

            missing_items = dish.get("missing_items")
            if not isinstance(missing_items, list):
                continue
            for item in missing_items:
                if not isinstance(item, dict):
                    continue
                if "cost_est" in item and item["cost_est"] is not None:
                    item["cost_est"] = str(item["cost_est"])

        return data

    def generate_recipe_assistant_answer(
        self,
        dish_name: str,
        question: str | None,
        pantry_items: list[PantryIngredient],
        custom_api_key: str | None,
    ) -> RecipeAssistantResponse:
        api_key = self._resolve_api_key(custom_api_key)
        client = Groq(api_key=api_key)

        pantry_list = [
            f"{item.name} ({item.quantity or 'unspecified quantity'})"
            for item in pantry_items
            if item.is_in_stock
        ]
        user_question = question.strip() if question else ""

        if user_question:
            task = (
                f"Dish: {dish_name}\n"
                f"User follow-up question: {user_question}\n"
                "Answer specifically for this dish in concise steps and practical guidance."
            )
            completion = client.chat.completions.create(
                model="openai/gpt-oss-120b",
                temperature=0.2,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are PantryPilot's recipe assistant. Give clear, usable cooking guidance. "
                            "Keep tone concise and practical."
                        ),
                    },
                    {
                        "role": "user",
                        "content": f"Pantry in-stock items: {pantry_list}\n\n{task}",
                    },
                ],
            )
            return RecipeAssistantResponse(
                answer=(completion.choices[0].message.content or "").strip()
            )
        else:
            task = (
                f"Dish: {dish_name}\n"
                "Provide a complete practical recipe including ingredients, steps, "
                "time, tips, and substitutions based on user's pantry."
            )
            completion = client.chat.completions.create(
                model="openai/gpt-oss-120b",
                temperature=0.2,
                response_format={"type": "json_object"},
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "Role: Expert Chef. Output STRICT JSON only. "
                            "Schema: {title, description, prep_time_minutes (int), cook_time_minutes (int), "
                            "servings (int), difficulty (Easy/Medium/Hard), calories_per_serving (int|null), "
                            "ingredients: [{name, quantity, notes}], "
                            "steps: [{step_number, instruction, timer_seconds (int|null)}], "
                            "chef_tips: [str]}"
                        ),
                    },
                    {
                        "role": "user",
                        "content": f"Pantry in-stock items: {pantry_list}\n\n{task}",
                    },
                ],
            )
            data = json.loads(completion.choices[0].message.content or "{}")
            normalized = self._normalize_recipe_payload(data)
            recipe = RecipeDetail.model_validate(normalized)
            return RecipeAssistantResponse(recipe=recipe)

    def _normalize_recipe_payload(self, data: dict) -> dict:
        normalized = dict(data)

        int_fields = [
            "prep_time_minutes",
            "cook_time_minutes",
            "servings",
            "calories_per_serving",
        ]
        for field in int_fields:
            value = normalized.get(field)
            if value is None:
                continue
            try:
                normalized[field] = int(value)
            except (TypeError, ValueError):
                if field == "calories_per_serving":
                    normalized[field] = None
                else:
                    normalized[field] = 0

        ingredients = normalized.get("ingredients", [])
        if isinstance(ingredients, list):
            for item in ingredients:
                if not isinstance(item, dict):
                    continue
                if "quantity" in item and item["quantity"] is not None:
                    item["quantity"] = str(item["quantity"])

        steps = normalized.get("steps", [])
        if isinstance(steps, list):
            for i, step in enumerate(steps, start=1):
                if not isinstance(step, dict):
                    continue
                if "step_number" not in step or step["step_number"] is None:
                    step["step_number"] = i
                else:
                    try:
                        step["step_number"] = int(step["step_number"])
                    except (TypeError, ValueError):
                        step["step_number"] = i
                if "timer_seconds" in step and step["timer_seconds"] is not None:
                    try:
                        step["timer_seconds"] = int(step["timer_seconds"])
                    except (TypeError, ValueError):
                        step["timer_seconds"] = None

        tips = normalized.get("chef_tips")
        if not isinstance(tips, list):
            normalized["chef_tips"] = []

        difficulty = str(normalized.get("difficulty", "Easy")).capitalize()
        if difficulty not in {"Easy", "Medium", "Hard"}:
            difficulty = "Easy"
        normalized["difficulty"] = difficulty

        return normalized
