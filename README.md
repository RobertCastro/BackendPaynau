# PayNau Backend

Este proyecto implementa un backend serverless usando AWS Lambda, API Gateway y RDS MySQL, gestionado con Terraform.

## Prerrequisitos

### 1. Configuración de AWS CLI

1. Instalar AWS CLI:
```bash
# Para Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Para MacOS
brew install awscli
```

2. Configurar credenciales AWS:
```bash
aws configure
```
Ingresa tu:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (ej: us-east-1)
- Default output format (json)

### 2. Instalación de Terraform

1. Para Linux:
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
```

2. Para MacOS:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

3. Verificar instalación:
```bash
terraform --version
```

### 3. Crear Bucket S3 para Backend State

1. Crear bucket S3 (desde AWS CLI):
```bash
aws s3api create-bucket \
    --bucket your-terraform-state-bucket \
    --region us-east-1
```

2. Habilitar versionamiento:
```bash
aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled
```

## Configuración del Proyecto

1. Clonar el repositorio:
```bash
git clone <repositorio>
cd <directorio>
```

2. Actualizar la configuración del backend en `terraform/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "terraform.fastapi.json"
    region = "us-east-1"
  }
}
```

3. Actualizar variables en `terraform/terraform.tfvars`:
```hcl
database_user = "admin"
database_pass = "your-password"
database_name = "lambda_db"
```

## Despliegue

1. Inicializar Terraform:
```bash
cd terraform
terraform init
```

2. Verificar los cambios a realizar:
```bash
terraform plan
```

3. Aplicar los cambios:
```bash
terraform apply
```

4. Para destruir la infraestructura:
```bash
terraform destroy
```

## Estructura del Proyecto

```
.
├── app/                    # Código fuente de la aplicación
│   ├── api/               # Endpoints y rutas
│   ├── db/                # Configuración de base de datos
│   ├── models/            # Modelos de datos
│   └── main.py           # Punto de entrada de la aplicación
├── lambda-layers/         # Capas Lambda (dependencias)
├── terraform/            # Configuración de infraestructura
│   ├── lambda.tf         # Configuración de Lambda
│   ├── rds.tf           # Configuración de RDS
│   └── variables.tf     # Variables de Terraform
└── README.md
```

## Variables de Entorno

La aplicación espera las siguientes variables de entorno, que son configuradas automáticamente por Terraform:

- `ENVIRONMENT`: Entorno de despliegue (dev, prod)
- `MYSQL_USER`: Usuario de la base de datos
- `MYSQL_PASSWORD`: Contraseña de la base de datos
- `MYSQL_HOST`: Host de la base de datos RDS
- `MYSQL_DATABASE`: Nombre de la base de datos

## Recursos AWS Creados

- AWS Lambda Function
- API Gateway
- RDS MySQL Database
- VPC Security Groups
- IAM Roles y Políticas
- Lambda Layers

## URLs del Servicio

Después del despliegue, Terraform mostrará las siguientes URLs:

- API Gateway URL: `https://<api-id>.execute-api.<region>.amazonaws.com/dev`
- Swagger Documentation: `<api-url>/docs`
- OpenAPI Specification: `<api-url>/openapi.json`

## Notas Adicionales

- El backend utiliza Python 3.12 con FastAPI
- La base de datos está configurada en el tier gratuito de AWS
- La Lambda tiene un timeout de 60 segundos
- Todos los recursos incluyen tags para mejor organización