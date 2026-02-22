from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from supabase import Client, create_client

from app.config import get_settings
from app.models.schemas import (
    CookSessionResponse,
    FollowupMessage,
    HistoryDetailResponse,
    IngredientSummary,
    PantryIngredient,
)


class DBService:
    def __init__(self, access_token: str | None = None) -> None:
        settings = get_settings()
        api_key = settings.auth_api_key() or settings.db_api_key()
        if not settings.supabase_url or not api_key:
            raise RuntimeError("Supabase database configuration is incomplete")
        self.client: Client = create_client(settings.supabase_url, api_key)
        if access_token:
            self.client.postgrest.auth(access_token)

    def get_pantry(self, user_id: UUID) -> list[PantryIngredient]:
        ingredients_result = (
            self.client.table("ingredients")
            .select("id,name,category,default_unit")
            .order("name")
            .execute()
        )
        pantry_result = (
            self.client.table("pantry_items")
            .select("ingredient_id,is_in_stock,quantity")
            .eq("user_id", str(user_id))
            .execute()
        )

        pantry_by_ingredient = {
            row["ingredient_id"]: row for row in pantry_result.data or []
        }

        items: list[PantryIngredient] = []
        for ingredient in ingredients_result.data or []:
            pantry_item = pantry_by_ingredient.get(ingredient["id"])
            items.append(
                PantryIngredient(
                    ingredient_id=ingredient["id"],
                    name=ingredient["name"],
                    category=ingredient["category"],
                    default_unit=ingredient["default_unit"],
                    is_in_stock=bool(pantry_item["is_in_stock"]) if pantry_item else False,
                    quantity=pantry_item.get("quantity") if pantry_item else None,
                )
            )
        return items

    def upsert_pantry_item(
        self,
        user_id: UUID,
        ingredient_id: int,
        is_in_stock: bool,
        quantity: str | None,
        quantity_provided: bool = True,
    ) -> None:
        resolved_quantity = quantity
        if not quantity_provided:
            existing = (
                self.client.table("pantry_items")
                .select("quantity")
                .eq("user_id", str(user_id))
                .eq("ingredient_id", ingredient_id)
                .limit(1)
                .execute()
            )
            if existing.data:
                resolved_quantity = existing.data[0].get("quantity")

        payload = {
            "user_id": str(user_id),
            "ingredient_id": ingredient_id,
            "is_in_stock": is_in_stock,
            "quantity": resolved_quantity,
        }
        self.client.table("pantry_items").upsert(
            payload, on_conflict="user_id,ingredient_id"
        ).execute()

    def ensure_profile(self, user_id: UUID) -> None:
        self.client.table("profiles").upsert(
            {"id": str(user_id)}, on_conflict="id"
        ).execute()

    def list_ingredients(
        self,
        search: str | None = None,
        limit: int = 50,
    ) -> list[IngredientSummary]:
        query = (
            self.client.table("ingredients")
            .select("id,name,category,default_unit")
            .order("name")
            .limit(limit)
        )
        if search:
            query = query.ilike("name", f"%{search}%")
        result = query.execute()
        return [IngredientSummary.model_validate(row) for row in (result.data or [])]

    def create_ingredient(
        self,
        name: str,
        category: str,
        default_unit: str,
    ) -> IngredientSummary:
        result = (
            self.client.table("ingredients")
            .insert(
                {
                    "name": name.strip(),
                    "category": category.strip(),
                    "default_unit": default_unit.strip(),
                }
            )
            .execute()
        )
        data = (result.data or [None])[0]
        if data is None:
            raise RuntimeError("Ingredient could not be created")
        return IngredientSummary.model_validate(data)

    def create_cooking_session(
        self,
        user_id: UUID,
        dish_name: str,
        source_query: str | None,
        people_count: int | None,
        extra_budget_inr: str | None,
        max_time_minutes: int | None,
        recipe_snapshot: dict[str, Any] | None,
        dish_card_snapshot: dict[str, Any] | None,
    ) -> CookSessionResponse:
        result = (
            self.client.table("cooking_sessions")
            .insert(
                {
                    "user_id": str(user_id),
                    "dish_name": dish_name.strip(),
                    "source_query": source_query.strip() if source_query else None,
                    "people_count": people_count,
                    "extra_budget_inr": extra_budget_inr.strip() if extra_budget_inr else None,
                    "max_time_minutes": max_time_minutes,
                    "recipe_snapshot": recipe_snapshot,
                    "dish_card_snapshot": dish_card_snapshot,
                }
            )
            .execute()
        )
        data = (result.data or [None])[0]
        if data is None:
            raise RuntimeError("Cooking session could not be created")
        return self._session_row_to_response(data)

    def list_cooking_sessions(self, user_id: UUID, limit: int = 50) -> list[CookSessionResponse]:
        result = (
            self.client.table("cooking_sessions")
            .select(
                "id,dish_name,source_query,people_count,extra_budget_inr,max_time_minutes,"
                "recipe_snapshot,dish_card_snapshot,cooked_at"
            )
            .eq("user_id", str(user_id))
            .order("cooked_at", desc=True)
            .limit(limit)
            .execute()
        )
        return [self._session_row_to_response(row) for row in (result.data or [])]

    def get_cooking_session_detail(self, user_id: UUID, session_id: UUID) -> HistoryDetailResponse:
        session_result = (
            self.client.table("cooking_sessions")
            .select(
                "id,dish_name,source_query,people_count,extra_budget_inr,max_time_minutes,"
                "recipe_snapshot,dish_card_snapshot,cooked_at"
            )
            .eq("user_id", str(user_id))
            .eq("id", str(session_id))
            .limit(1)
            .execute()
        )
        session_row = (session_result.data or [None])[0]
        if session_row is None:
            raise RuntimeError("Cooking session not found")

        followup_result = (
            self.client.table("cooking_followups")
            .select("id,question,answer,created_at")
            .eq("user_id", str(user_id))
            .eq("session_id", str(session_id))
            .order("created_at", desc=False)
            .execute()
        )
        followups = [self._followup_row_to_response(row) for row in (followup_result.data or [])]
        return HistoryDetailResponse(session=self._session_row_to_response(session_row), followups=followups)

    def create_cooking_followup(
        self,
        user_id: UUID,
        session_id: UUID,
        question: str,
        answer: str,
    ) -> None:
        self.client.table("cooking_followups").insert(
            {
                "user_id": str(user_id),
                "session_id": str(session_id),
                "question": question.strip(),
                "answer": answer.strip(),
            }
        ).execute()

    def _session_row_to_response(self, row: dict[str, Any]) -> CookSessionResponse:
        cooked_at = self._parse_timestamptz(row.get("cooked_at"))
        ist = cooked_at.astimezone(ZoneInfo("Asia/Kolkata"))
        return CookSessionResponse(
            id=row["id"],
            dish_name=row["dish_name"],
            source_query=row.get("source_query"),
            people_count=row.get("people_count"),
            extra_budget_inr=row.get("extra_budget_inr"),
            max_time_minutes=row.get("max_time_minutes"),
            recipe_snapshot=row.get("recipe_snapshot"),
            dish_card_snapshot=row.get("dish_card_snapshot"),
            cooked_at=cooked_at,
            cooked_at_ist=ist.strftime("%Y-%m-%d %I:%M %p IST"),
            cooked_day_ist=ist.strftime("%A"),
            cooked_date_ist=ist.strftime("%d %b %Y"),
            cooked_time_ist=ist.strftime("%I:%M %p IST"),
        )

    def _followup_row_to_response(self, row: dict[str, Any]) -> FollowupMessage:
        created_at = self._parse_timestamptz(row.get("created_at"))
        ist = created_at.astimezone(ZoneInfo("Asia/Kolkata"))
        return FollowupMessage(
            id=row["id"],
            question=row["question"],
            answer=row["answer"],
            created_at=created_at,
            created_at_ist=ist.strftime("%Y-%m-%d %I:%M %p IST"),
        )

    @staticmethod
    def _parse_timestamptz(value: Any) -> datetime:
        if isinstance(value, datetime):
            return value
        if isinstance(value, str):
            normalized = value.replace("Z", "+00:00")
            return datetime.fromisoformat(normalized)
        raise RuntimeError("Invalid timestamp format returned by database")
