from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas.person import PersonCreate, PersonUpdate, PersonResponse
from app.db.base import get_db
from app.services.person_service import (
    create_person,
    list_all_people,
    get_person_by_id,
    update_person,
    delete_person,
)

router = APIRouter()

@router.post("/", response_model=PersonResponse)
async def create(person: PersonCreate, db: AsyncSession = Depends(get_db)):
    return await create_person(person, db)

@router.get("/", response_model=list[PersonResponse])
async def read_all(db: AsyncSession = Depends(get_db)):
    return await list_all_people(db)

@router.get("/{person_id}", response_model=PersonResponse)
async def read_one(person_id: int, db: AsyncSession = Depends(get_db)):
    return await get_person_by_id(person_id, db)

@router.put("/{person_id}", response_model=PersonResponse)
async def update(person_id: int, person: PersonUpdate, db: AsyncSession = Depends(get_db)):
    return await update_person(person_id, person, db)

@router.delete("/{person_id}")
async def delete(person_id: int, db: AsyncSession = Depends(get_db)):
    await delete_person(person_id, db)
    return {"message": f"Person {person_id} deleted successfully"}
