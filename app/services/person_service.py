from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.person import Person
from app.schemas.person import PersonCreate, PersonUpdate
from fastapi import HTTPException

async def get_person_by_id(person_id: int, db: AsyncSession) -> Person:
    query = select(Person).where(Person.id == person_id)
    result = await db.execute(query)
    person = result.scalar_one_or_none()

    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    return person

async def list_all_people(db: AsyncSession) -> list[Person]:
    query = select(Person)
    result = await db.execute(query)
    return result.scalars().all()

async def create_person(person_data: PersonCreate, db: AsyncSession) -> Person:
    # Validar correo
    query = select(Person).where(Person.email == person_data.email)
    result = await db.execute(query)
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email is already in use")
    
    new_person = Person(**person_data.dict())
    db.add(new_person)
    await db.commit()
    await db.refresh(new_person)
    return new_person

async def update_person(person_id: int, person_data: PersonUpdate, db: AsyncSession) -> Person:
    person = await get_person_by_id(person_id, db)
    for key, value in person_data.dict(exclude_unset=True).items():
        setattr(person, key, value)
    await db.commit()
    await db.refresh(person)
    return person

async def delete_person(person_id: int, db: AsyncSession) -> None:
    person = await get_person_by_id(person_id, db)
    await db.delete(person)
    await db.commit()
