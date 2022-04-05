variable "db_password" {
  description = "RDS root user password"
  sensitive   = true
}

variable "region" {
  description = "geo for resources"
  sensitive   = true
}
