from __future__ import annotations

from uuid import UUID

from supabase import Client, create_client

from app.config import get_settings
from app.models.schemas import IngredientSummary, PantryIngredient


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
