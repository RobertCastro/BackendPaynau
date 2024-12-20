import logging
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from app.db.init_db import init_db
from app.api.routes import people
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    root_path="/dev",
    docs_url="/api/v1/docs",
    openapi_url="/api/v1/openapi.json"
)

ALLOWED_ORIGINS = '*'

@app.options('/{rest_of_path:path}')
async def preflight_handler(request: Request, rest_of_path: str) -> Response:
    response = Response()
    response.headers['Access-Control-Allow-Origin'] = ALLOWED_ORIGINS
    response.headers['Access-Control-Allow-Methods'] = 'POST, GET, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type'
    return response

@app.middleware("http")
async def add_cors_header(request: Request, call_next):
    response = await call_next(request)
    response.headers['Access-Control-Allow-Origin'] = ALLOWED_ORIGINS
    response.headers['Access-Control-Allow-Methods'] = 'GET,HEAD,OPTIONS,PATCH,POST,PUT,DELETE'
    response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, X-Amz-Date, X-Api-Key, X-Amz-Security-Token'
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    return response

# Router de people
app.include_router(people.router, prefix="/api/v1/people", tags=["People"])

@app.on_event("startup")
async def startup_event():
    logger.info("Iniciando la aplicación...")
    await init_db()
    logger.info("Base de datos inicializada correctamente")

@app.get("/")
async def root():
    return {"message": "Hello Paynau"}

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    asgi_handler = Mangum(app, lifespan="off")
    return asgi_handler(event, context)
