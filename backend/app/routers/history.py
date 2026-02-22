from fastapi import APIRouter, Depends, HTTPException, Query
from uuid import UUID

from app.dependencies import AuthUser, get_current_user
from app.models.schemas import (
    CookSessionCreateRequest,
    CookSessionResponse,
    HistoryDetailResponse,
    HistoryListResponse,
)
from app.services.db_service import DBService

router = APIRouter(prefix="/history", tags=["history"])


def get_user_db(user: AuthUser = Depends(get_current_user)) -> DBService:
    return DBService(access_token=user.access_token)


@router.post("/cooked", response_model=CookSessionResponse)
def create_cooked_session(
    payload: CookSessionCreateRequest,
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> CookSessionResponse:
    if not payload.dish_name.strip():
        raise HTTPException(status_code=400, detail="dish_name is required")
    try:
        db.ensure_profile(user.id)
        return db.create_cooking_session(
            user_id=user.id,
            dish_name=payload.dish_name,
            source_query=payload.source_query,
            people_count=payload.people_count,
            extra_budget_inr=payload.extra_budget_inr,
            max_time_minutes=payload.max_time_minutes,
            recipe_snapshot=payload.recipe_snapshot,
            dish_card_snapshot=payload.dish_card_snapshot,
        )
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("", response_model=HistoryListResponse)
def list_history(
    limit: int = Query(default=50, ge=1, le=200),
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> HistoryListResponse:
    try:
        db.ensure_profile(user.id)
        items = db.list_cooking_sessions(user_id=user.id, limit=limit)
        return HistoryListResponse(items=items)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/{session_id}", response_model=HistoryDetailResponse)
def get_history_detail(
    session_id: UUID,
    user: AuthUser = Depends(get_current_user),
    db: DBService = Depends(get_user_db),
) -> HistoryDetailResponse:
    try:
        db.ensure_profile(user.id)
        return db.get_cooking_session_detail(user_id=user.id, session_id=session_id)
    except RuntimeError as exc:
        if "not found" in str(exc).lower():
            raise HTTPException(status_code=404, detail="History session not found") from exc
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(exc)) from exc
