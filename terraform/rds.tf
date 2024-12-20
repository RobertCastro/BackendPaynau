# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.main_resources_name}-lambda-sg-${var.environment}"
  description = "Security group for Lambda"

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.main_resources_name}-lambda-sg-${var.environment}"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.main_resources_name}-rds-sg-${var.environment}"
  description = "Security group for RDS MySQL instance"

  ingress {
    description     = "Allow MySQL traffic from Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  tags = {
    Name = "${var.main_resources_name}-rds-sg-${var.environment}"
  }
}

resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds_sg.id
  security_group_id        = aws_security_group.lambda_sg.id
  description             = "Allow Lambda to connect to RDS MySQL"
}

# Subnet group for RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.main_resources_name}-subnet-group-${var.environment}"
  subnet_ids = ["subnet-021ea598cba9335c6", "subnet-0e2bd5db18632bf60"]

  tags = {
    Name = "${var.main_resources_name}-subnet-group-${var.environment}"
  }
}

# RDS Instance
resource "aws_db_instance" "mysql" {
  identifier        = "${var.main_resources_name}-${var.environment}"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = var.database_name
  username = var.database_user
  password = var.database_pass

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true # For development/testing
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Enable automated backups
  multi_az               = false
  publicly_accessible    = false

  performance_insights_enabled = false

  tags = {
    Name = "${var.main_resources_name}-mysql-${var.environment}"
  }
}

# Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "The port the RDS instance is listening on"
  value       = aws_db_instance.mysql.port
}