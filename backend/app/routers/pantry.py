from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import AuthUser, get_current_user
from app.models.schemas import PantryResponse, PantryToggleRequest
from app.services.db_service import DBService

router = APIRouter(prefix="/pantry", tags=["pantry"])


def get_user_db(user: AuthUser = Depends(get_current_user)) -> DBService:
    return DBService(access_token=user.access_token)


@router.get("", response_model=PantryResponse)
def get_pantry(
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> PantryResponse:
    try:
        db.ensure_profile(user.id)
        items = db.get_pantry(user.id)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return PantryResponse(items=items)


@router.post("/toggle", response_model=PantryResponse)
def toggle_pantry_item(
    payload: PantryToggleRequest,
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> PantryResponse:
    body = payload.model_dump(exclude_unset=True)
    quantity_provided = "quantity" in body
    try:
        db.ensure_profile(user.id)
        db.upsert_pantry_item(
            user_id=user.id,
            ingredient_id=payload.ingredient_id,
            is_in_stock=payload.status,
            quantity=payload.quantity,
            quantity_provided=quantity_provided,
        )
        items = db.get_pantry(user.id)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return PantryResponse(items=items)
