import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from app.db.init_db import init_db
from app.api.routes import people
import asyncio
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    description="FastAPI server that runs on top of Lambda Functions.",
    contact={"Robert Castro": "hola@soyrobert.co"},
    title="FastAPI Backend",
    version="1.0.0",
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    swagger_ui_parameters={
        "persistAuthorization": True,
        "displayRequestDuration": True,
    }
)

# Configuración CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=3600,
)

# Router de people
app.include_router(people.router, prefix="/api/v1/people", tags=["People"])

@app.on_event("startup")
async def startup_event():
    try:
        logger.info("Iniciando la aplicación...")
        await init_db()
        logger.info("Base de datos inicializada correctamente")
    except Exception as e:
        logger.error(f"Error durante el inicio de la aplicación: {str(e)}")
        raise

@app.get("/")
async def root():
    return {"message": "Hello Paynau"}

async def initialize_db():
    try:
        await init_db()
        return True
    except Exception as e:
        logger.error(f"Error initializing database: {str(e)}")
        return False

def setup_event_loop():
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Event loop al inicio
    loop = setup_event_loop()
    
    try:
        # Manejar eventos warmup
        if event.get('source') == 'serverless-plugin-warmup' or event.get('warmup'):
            logger.info('WarmUp - Lambda is warm!')
            return {'statusCode': 200, 'body': json.dumps({'message': 'Lambda is warm!'})}

        # Manejo eventos inicialización
        if 'requestContext' not in event:
            logger.info('Initialization or test event received')
            loop.run_until_complete(initialize_db())
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Initialization completed'})
            }

        # Configurar Mangum
        asgi_handler = Mangum(app, lifespan="off")
        
        # Manejo de solicitud HTTP
        return asgi_handler(event, context)
    
    except Exception as e:
        logger.error(f"Error handling request: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'detail': str(e)
            })
        }

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)