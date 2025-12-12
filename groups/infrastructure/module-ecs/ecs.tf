module "ecs-service" {
  source = "git@github.com:companieshouse/terraform-modules//aws/ecs/ecs-service?ref=weblate" # off 1.0.340

  # Environmental configuration
  environment                = var.config.environment
  aws_region                 = var.config.aws_region
  aws_profile                = var.config.aws_profile
  vpc_id                     = var.config.vpc_id
  ecs_cluster_id             = var.config.ecs_cluster_id
  task_execution_role_arn    = var.config.task_execution_role_arn
  fargate_security_group_ids = [var.ecs_shared_security_group_id]

  # Load balancer configuration
  lb_listener_arn           = var.config.lb_listener_arn
  lb_listener_rule_priority = var.config.lb_listener_rule_priority
  lb_listener_paths         = var.config.lb_listener_paths

  # ECS Task container health check
  use_task_container_healthcheck    = var.config.use_task_container_healthcheck
  healthcheck_command               = var.config.healthcheck_command
  healthcheck_path                  = try(var.config.healthcheck_path, "")
  health_check_grace_period_seconds = var.config.health_check_grace_period_seconds
  healthcheck_healthy_threshold     = var.config.healthcheck_healthy_threshold

  # Docker container details
  docker_registry   = var.config.docker_registry
  docker_repo       = var.config.docker_repo
  container_version = var.config.container_version
  container_port    = try(var.config.container_port, 9000) # module-ecs default
  container_command = try(var.config.container_command, [])

  read_only_root_filesystem = var.config.read_only_root_filesystem
  volumes                   = var.config.volumes
  mount_points              = var.config.mount_points

  # Service configuration
  service_name  = var.config.service_name
  name_prefix   = var.config.name_prefix
  batch_service = var.config.batch_service

  # Service performance and scaling configs
  desired_task_count         = var.config.desired_task_count
  max_task_count             = var.config.max_task_count
  required_cpus              = var.config.required_cpus
  required_memory            = var.config.required_memory
  service_autoscale_enabled  = var.config.service_autoscale_enabled
  service_scaledown_schedule = var.config.service_scaledown_schedule
  service_scaleup_schedule   = var.config.service_scaleup_schedule
  use_capacity_provider      = var.config.use_capacity_provider
  use_fargate                = var.config.use_fargate
  fargate_subnets            = var.config.fargate_subnets


  # Cloudwatch
  cloudwatch_alarms_enabled = var.config.cloudwatch_alarms_enabled

  # Service environment variable and secret configs
  task_environment          = var.config.task_environment
  task_secrets              = var.config.task_secrets
  app_environment_filename  = var.config.app_environment_filename
  use_set_environment_files = var.config.use_set_environment_files

  task_role_arn          = var.config.task_role_arn
  enable_execute_command = var.config.enable_execute_command
}
