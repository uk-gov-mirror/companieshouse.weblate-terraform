# this single config var is used for values already known at plan time
variable "config" {
  description = "1 single config var to expand"
  type        = any
}


# keep it outside for clarity as this is known only at apply time
# (the alternative is to merge in the root module:
#   config = merge(each.value,
#     { efs_security_group_id = aws_security_group.efs.id }
#   ) but this is less clear
# )
variable "efs_security_group_id" {
  description = "The security group ID of the EFS filesystem"
  type        = string
}

variable "ecs_shared_security_group_id" {
  description = "The weblate ECS shared security group ID"
  type        = string
}

variable "rds_security_group_id" {
  description = "The security group ID of the RDS instance"
  type        = string
}

variable "redis_security_group_id" {
  description = "The security group ID of the Redis instance"
  type        = string
}
