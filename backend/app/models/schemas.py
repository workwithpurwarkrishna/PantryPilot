from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field


IngredientCategory = Literal[
    "Vegetables",
    "Fruits",
    "Grains & Cereals",
    "Dairy",
    "Proteins",
    "Spices & Seasonings",
    "Oils",
    "Sauces",
    "Others",
]


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
    category: IngredientCategory
    default_unit: str


class IngredientListResponse(BaseModel):
    items: list[IngredientSummary]


class IngredientCreateRequest(BaseModel):
    name: str
    category: IngredientCategory
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
    extra_budget_inr: str | None = None
    people_count: int | None = Field(default=None, ge=1)
    max_time_minutes: int | None = Field(default=None, ge=1, le=300)
    provider: Literal["groq"] = "groq"


class RecipeAssistantRequest(BaseModel):
    dish_name: str
    question: str | None = None
    session_id: UUID | None = None


class RecipeIngredient(BaseModel):
    name: str
    quantity: str
    notes: str | None = None


class RecipeStep(BaseModel):
    step_number: int
    instruction: str
    timer_seconds: int | None = None


class RecipeDetail(BaseModel):
    title: str
    description: str
    prep_time_minutes: int
    cook_time_minutes: int
    servings: int
    difficulty: Literal["Easy", "Medium", "Hard"]
    calories_per_serving: int | None = None
    ingredients: list[RecipeIngredient]
    steps: list[RecipeStep]
    chef_tips: list[str]


class RecipeAssistantResponse(BaseModel):
    answer: str | None = None
    recipe: RecipeDetail | None = None


class CookSessionCreateRequest(BaseModel):
    dish_name: str
    source_query: str | None = None
    people_count: int | None = Field(default=None, ge=1)
    extra_budget_inr: str | None = None
    max_time_minutes: int | None = Field(default=None, ge=1, le=300)
    recipe_snapshot: dict[str, Any] | None = None
    dish_card_snapshot: dict[str, Any] | None = None


class CookSessionResponse(BaseModel):
    id: UUID
    dish_name: str
    source_query: str | None = None
    people_count: int | None = None
    extra_budget_inr: str | None = None
    max_time_minutes: int | None = None
    recipe_snapshot: dict[str, Any] | None = None
    dish_card_snapshot: dict[str, Any] | None = None
    cooked_at: datetime
    cooked_at_ist: str
    cooked_day_ist: str
    cooked_date_ist: str
    cooked_time_ist: str


class HistoryListResponse(BaseModel):
    items: list[CookSessionResponse]


class FollowupMessage(BaseModel):
    id: UUID
    question: str
    answer: str
    created_at: datetime
    created_at_ist: str


class HistoryDetailResponse(BaseModel):
    session: CookSessionResponse
    followups: list[FollowupMessage]


class AuthLoginRequest(BaseModel):
    email: str
    password: str


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
