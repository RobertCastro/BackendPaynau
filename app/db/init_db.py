import logging
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import text
from .base import Base, engine

logger = logging.getLogger(__name__)

async def init_db():
    try:
        async with engine.begin() as conn:
            logger.info("Iniciando creación de tablas...")
            await conn.run_sync(Base.metadata.create_all)
            logger.info("Tablas creadas exitosamente")
            
        async with engine.connect() as conn:
            result = await conn.execute(text("SHOW TABLES LIKE 'persons'"))
            if result.rowcount == 0:
                logger.warning("La tabla 'persons' no existe")
            else:
                logger.info("Tabla 'persons' verificada correctamente")
                
    except SQLAlchemyError as e:
        logger.error(f"Error inicializando la base de datos: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Error inesperado: {str(e)}")
        raise