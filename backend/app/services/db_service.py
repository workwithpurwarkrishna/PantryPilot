from __future__ import annotations

from uuid import UUID

from supabase import Client, create_client

from app.config import get_settings
from app.models.schemas import PantryIngredient


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
    ) -> None:
        payload = {
            "user_id": str(user_id),
            "ingredient_id": ingredient_id,
            "is_in_stock": is_in_stock,
            "quantity": quantity,
        }
        self.client.table("pantry_items").upsert(
            payload, on_conflict="user_id,ingredient_id"
        ).execute()

    def ensure_profile(self, user_id: UUID) -> None:
        self.client.table("profiles").upsert(
            {"id": str(user_id)}, on_conflict="id"
        ).execute()
