from fastapi import APIRouter, Depends, HTTPException, Query

from app.dependencies import AuthUser, get_current_user
from app.models.schemas import IngredientCreateRequest, IngredientListResponse, IngredientSummary
from app.services.db_service import DBService

router = APIRouter(prefix="/ingredients", tags=["ingredients"])


def get_user_db(user: AuthUser = Depends(get_current_user)) -> DBService:
    return DBService(access_token=user.access_token)


@router.get("", response_model=IngredientListResponse)
def list_ingredients(
    search: str | None = Query(default=None, min_length=1, max_length=100),
    limit: int = Query(default=50, ge=1, le=200),
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> IngredientListResponse:
    try:
        db.ensure_profile(user.id)
        items = db.list_ingredients(search=search, limit=limit)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return IngredientListResponse(items=items)


@router.post("", response_model=IngredientSummary)
def create_ingredient(
    payload: IngredientCreateRequest,
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> IngredientSummary:
    if not payload.name.strip() or not payload.category.strip() or not payload.default_unit.strip():
        raise HTTPException(status_code=400, detail="name, category, and default_unit are required")

    try:
        db.ensure_profile(user.id)
        ingredient = db.create_ingredient(
            name=payload.name,
            category=payload.category,
            default_unit=payload.default_unit,
        )
    except Exception as exc:
        detail = str(exc)
        if "duplicate key value" in detail.lower() or "ingredients_name_key" in detail:
            raise HTTPException(status_code=409, detail="Ingredient already exists") from exc
        raise HTTPException(status_code=500, detail=detail) from exc

    return ingredient
