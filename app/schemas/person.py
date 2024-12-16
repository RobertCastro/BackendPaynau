from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class PersonBase(BaseModel):
    name: str
    email: str
    phone_number: Optional[str] = None
    birth_date: Optional[str] = None

class PersonCreate(PersonBase):
    pass

class PersonUpdate(PersonBase):
    pass

class PersonResponse(PersonBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True  # Antes era orm_mode = True