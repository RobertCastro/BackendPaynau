from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.person import PersonCreate, PersonResponse
from app.db.base import get_db
from app.services.person_service import (
    create_person,
)

router = APIRouter()

@router.post("/", response_model=PersonResponse)
async def create(person: PersonCreate, db: AsyncSession = Depends(get_db)):
    return await create_person(person, db)