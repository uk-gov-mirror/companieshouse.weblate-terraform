
# ------------------------------------------------------------------------------
# Docker Container
# ------------------------------------------------------------------------------
variable "docker_registry" {
  type        = string
  description = "The FQDN of the Docker registry."
}

# ------------------------------------------------------------------------------
# Service performance and scaling configs
# ------------------------------------------------------------------------------
variable "use_fargate" {
  type        = bool
  description = "If true, sets the required capabilities for all containers in the task definition to use FARGATE, false uses EC2"
  default     = true
}
variable "use_capacity_provider" {
  type        = bool
  description = "Whether to use a capacity provider instead of setting a launch type for the service"
  default     = true
}
variable "service_autoscale_enabled" {
  type        = bool
  description = "Whether to enable service autoscaling, including scheduled autoscaling"
  default     = true
}
variable "service_scaledown_schedule" {
  type        = string
  description = "The schedule to use when scaling down the number of tasks to zero."
  # Typically used to stop all tasks in a service to save resource costs overnight.
  # E.g. a value of '55 19 * * ? *' would be Mon-Sun 7:55pm.  An empty string indicates that no schedule should be created.
  default = "55 19 * * ? *"
}
variable "service_scaleup_schedule" {
  type        = string
  description = "The schedule to use when scaling up the number of tasks to their normal desired level."
  # Typically used to start all tasks in a service after it has been shutdown overnight.
  # E.g. a value of '5 6 * * ? *' would be Mon-Sun 6:05am.  An empty string indicates that no schedule should be created.
  default = "5 6 * * ? *"
}

# ----------------------------------------------------------------------
# Cloudwatch alerts
# ----------------------------------------------------------------------
variable "cloudwatch_alarms_enabled" {
  description = "Whether to create a standard set of cloudwatch alarms for the service.  Requires an SNS topic to have already been created for the stack."
  type        = bool
  default     = false
}


# ------------------------------------------------------------------------------
# Service environment variable configs
# ------------------------------------------------------------------------------
variable "use_set_environment_files" {
  type        = bool
  default     = true
  description = "Toggle default global and shared  environment files"
}

variable "weblate_image_version" {
  type        = string
  description = "The version of the weblate-image to run."
  default     = "latest"
}

# ------------------------------------------------------------------------------
# ECS Services - environment variable configs
# ------------------------------------------------------------------------------
#  !
#  ! NOTE:
#  ! the names of these keys are defined by Weblate:
#  ! https://docs.weblate.org/en/latest/admin/install/docker.html#envvar-WEBLATE_SERVICE
#  !
variable "ecs_configs" {
  type = map(object({
    desired_task_count = number
    max_task_count     = number
    required_cpus      = number
    required_memory    = number
  }))
  default = {
    "web" = {
      desired_task_count = 1
      max_task_count     = 2
      required_cpus      = 256
      required_memory    = 1024
    }
    "celery-celery" = {
      desired_task_count = 1
      max_task_count     = 2
      required_cpus      = 256
      required_memory    = 2048
    }
    "celery-translate" = {
      desired_task_count = 1
      max_task_count     = 2
      required_cpus      = 512
      required_memory    = 4096
    }
    "celery-notify" = {
      desired_task_count = 1
      max_task_count     = 1
      required_cpus      = 256
      required_memory    = 512
    }
    "celery-memory" = {
      desired_task_count = 1
      max_task_count     = 2
      required_cpus      = 1024
      required_memory    = 4096
    }
    "celery-backup" = {
      desired_task_count = 1
      max_task_count     = 1
      required_cpus      = 256
      required_memory    = 1024
    }
    "celery-beat" = {
      desired_task_count = 1
      max_task_count     = 1
      required_cpus      = 256
      required_memory    = 512
    }
  }
}
