from sqlalchemy.exc import SQLAlchemyError
from .base import Base, engine
import logging

logger = logging.getLogger(__name__)

async def init_db():
    try:
        # Crear todas las tablas
        async with engine.begin() as conn:
            logger.info("Iniciando creación de tablas")
            await conn.run_sync(Base.metadata.create_all)
            logger.info("Tablas creadas")
            
        # Verificar que las tablas se crearon
        async with engine.connect() as conn:
            # Verificar tabla persons
            result = await conn.execute("SHOW TABLES LIKE 'persons'")
            if result.rowcount == 0:
                logger.error("La tabla 'persons' no se creó correctamente")
            else:
                logger.info("Tabla 'persons' verificada correctamente")
                
    except SQLAlchemyError as e:
        logger.error(f"Error inicializando la base de datos: {str(e)}")
        raise