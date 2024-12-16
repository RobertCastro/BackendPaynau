from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import declarative_base, sessionmaker
from typing import AsyncGenerator
import os

DATABASE_URL = "mysql+aiomysql://{}:{}@{}/{}".format(
    os.environ.get('MYSQL_USER'),
    os.environ.get('MYSQL_PASSWORD'),
    os.environ.get('MYSQL_HOST'),
    os.environ.get('MYSQL_DATABASE')
)

engine = create_async_engine(
    DATABASE_URL,
    echo=True,
    pool_pre_ping=True,
    pool_recycle=3600,
)

AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()