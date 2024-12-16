#!/bin/bash

# Detener contenedores existentes
docker-compose down

# Construir las imágenes
docker-compose build

# Iniciar los servicios
docker-compose up