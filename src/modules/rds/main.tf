resource "aws_db_subnet_group" "this" {
  name       = "rds-postgres-subnets"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

data "aws_ssm_parameter" "username" {
  name            = var.username_ssm
  with_decryption = true
}

data "aws_ssm_parameter" "password" {
  name            = var.password_ssm
  with_decryption = true
}

resource "aws_db_instance" "this" {
  identifier     = "insizon-postgres"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  multi_az          = var.multi_az
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = data.aws_ssm_parameter.username.value
  password = data.aws_ssm_parameter.password.value

  backup_retention_period = var.backup_retention
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.sg_ids

  deletion_protection = false
  skip_final_snapshot = true

  tags = var.tags
}
