from typing import Literal

from pydantic import BaseModel, Field


class PantryIngredient(BaseModel):
    ingredient_id: int
    name: str
    category: str
    default_unit: str
    is_in_stock: bool = False
    quantity: str | None = None


class PantryResponse(BaseModel):
    items: list[PantryIngredient]


class PantryToggleRequest(BaseModel):
    ingredient_id: int
    status: bool
    quantity: str | None = None


class IngredientSummary(BaseModel):
    id: int
    name: str
    category: str
    default_unit: str


class IngredientListResponse(BaseModel):
    items: list[IngredientSummary]


class IngredientCreateRequest(BaseModel):
    name: str
    category: str
    default_unit: str


class MissingItem(BaseModel):
    name: str
    cost_est: str


class Dish(BaseModel):
    name: str
    match_score: int = Field(ge=0, le=100)
    missing_items: list[MissingItem]
    cooking_time: str


class ChatResponse(BaseModel):
    thought: str
    dishes: list[Dish]


class ChatMessageRequest(BaseModel):
    text: str | None = None
    audio_base64: str | None = None
    provider: Literal["groq"] = "groq"


class RecipeAssistantRequest(BaseModel):
    dish_name: str
    question: str | None = None


class RecipeAssistantResponse(BaseModel):
    answer: str


class AuthLoginRequest(BaseModel):
    email: str
    password: str


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
