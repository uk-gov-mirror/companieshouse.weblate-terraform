locals {

  # GLOBAL: create a map of secret name => secret arn to pass into ecs service module
  global_secrets_arn_map = {
    for sec in module.common_secrets.global_secret_list :
    trimprefix(sec.name, "/${local.global_prefix}/") => sec.arn
  }

  # GLOBAL: create a list of secret name => secret arn to pass into ecs service module
  global_secret_list = flatten([for key, value in local.global_secrets_arn_map :
    { "name" = upper(key), "valueFrom" = value }
  ])

  # SERVICE: create a map of secret name => secret arn to pass into ecs service module
  service_secrets_arn_map = {
    for sec in module.secrets.secrets :
    trimprefix(sec.name, "/${local.whole_service_name}-${var.environment}/") => sec.arn
  }

  # SERVICE: create a list of secret name => secret arn to pass into ecs service module
  service_secret_list = flatten([for key, value in local.service_secrets_arn_map :
    { "name" = upper(key), "valueFrom" = value }
  ])

  # GLOBAL: create a map of secret name and secret version to pass into ecs service module
  ssm_global_version_map = [
    for sec in module.common_secrets.global_secret_list : {
      name = "GLOBAL_${var.ssm_version_prefix}${replace(upper(basename(sec.name)), "-", "_")}", value = sec.version
    }
  ]

  # SERVICE: create a map of secret name and secret version to pass into ecs service module
  ssm_service_version_map = [
    for sec in module.secrets.secrets : {
      name = "${replace(upper(local.whole_service_name), "-", "_")}_${var.ssm_version_prefix}${replace(upper(basename(sec.name)), "-", "_")}", value = sec.version
    }
  ]


  # TASK SECRET: GLOBAL SECRET + SERVICE SECRET
  task_secrets = concat(local.global_secret_list, local.service_secret_list, [
  ])

  # TASK ENVIRONMENT: GLOBAL SECRET Version + SERVICE SECRET Version
  task_environment = concat(local.ssm_global_version_map, local.ssm_service_version_map, [
    { name : "DUMMY_VALUE", value : "29" },
    { name : "AWS_STORAGE_BUCKET_NAME", value : local.s3_bucket_name },
    { name : "AWS_S3_REGION_NAME", value : var.aws_region },
    { name : "WEBLATE_DEBUG", value : "1" },
    { name : "WEBLATE_LOGLEVEL", value : "DEBUG" },
    { name : "POSTGRES_HOST", value : data.aws_db_instance.weblate.address },
    { name : "POSTGRES_DB", value : var.postgres_db },
    { name : "POSTGRES_PORT", value : "5432" },
    { name : "REDIS_HOST", value : data.aws_elasticache_replication_group.weblate.primary_endpoint_address }
  ])

  efs_shared_volume_name = "weblate-efs-shared"
  efs_mounts = [
    "data",
    "static",
    "media"
  ]

  # ECS SETTINGS (COMMON)
  ecs_common = {
    use_set_environment_files = var.use_set_environment_files

    # Environmental configuration
    environment             = var.environment
    aws_region              = var.aws_region
    aws_profile             = var.aws_profile
    vpc_id                  = data.aws_vpc.vpc.id
    ecs_cluster_id          = data.aws_ecs_cluster.ecs_cluster.id
    task_execution_role_arn = data.aws_iam_role.ecs_cluster_iam_role.arn

    batch_service = true # default to true for all services (only web will override with false)
    # Load balancer configuration (empty apart from web)
    lb_listener_arn           = ""
    lb_listener_rule_priority = 1
    lb_listener_paths         = []

    # ECS Task container health check
    use_task_container_healthcheck    = true
    healthcheck_command               = "/app/bin/health_check"
    health_check_grace_period_seconds = 300
    healthcheck_healthy_threshold     = "2"

    # Docker container details
    docker_registry   = var.docker_registry
    docker_repo       = "weblate-image"
    container_version = var.weblate_image_version

    read_only_root_filesystem = false

    volumes = [
      {
        name = local.efs_shared_volume_name
        efs_volume_configuration = {
          file_system_id     = aws_efs_file_system.weblate.id
          transit_encryption = "ENABLED"
          authorization_config = {
            access_point_id = aws_efs_access_point.weblate_accp.id
          }
        }
      }
    ]

    # Define the container mount points using that EFS volume
    mount_points = [
      for name in local.efs_mounts : {
        sourceVolume  = local.efs_shared_volume_name
        containerPath = "/app/${name}"
        readOnly      = false
      }
    ]

    # Service configuration
    name_prefix = local.name_prefix

    # Service performance and scaling configs
    service_autoscale_enabled  = var.service_autoscale_enabled
    service_scaledown_schedule = var.service_scaledown_schedule
    service_scaleup_schedule   = var.service_scaleup_schedule
    use_capacity_provider      = var.use_capacity_provider
    use_fargate                = var.use_fargate
    fargate_subnets            = local.application_subnet_ids

    # Cloudwatch
    cloudwatch_alarms_enabled = var.cloudwatch_alarms_enabled

    # Service environment variable and secret configs
    task_environment = local.task_environment
    task_secrets     = local.task_secrets

    task_role_arn          = aws_iam_role.ecs_task_role.arn
    enable_execute_command = true
  }

  # ECS SETTINGS (SERVICE-SPECIFIC)
  ecs_custom_vars = [
    #  !
    #  ! NOTE:
    #  ! these "service_name" strings are defined by Weblate:
    #  ! https://docs.weblate.org/en/latest/admin/install/docker.html#envvar-WEBLATE_SERVICE
    #  !
    {
      service_name   = "web"
      batch_service  = false
      container_port = 8080

      # Load balancer configuration
      lb_listener_arn           = data.aws_lb_listener.rand_lb_listener.arn
      lb_listener_rule_priority = 35
      lb_listener_paths         = ["/weblate", "/weblate/*"]

      healthcheck_path                  = "/weblate/healthz/"
      health_check_grace_period_seconds = 300
      healthcheck_healthy_threshold     = "2"
    },
    {
      service_name = "celery-celery"
    },
    {
      service_name = "celery-translate"
    },
    {
      service_name = "celery-notify"
    },
    {
      service_name = "celery-memory"
    },
    {
      service_name = "celery-backup"
    },
    {
      service_name = "celery-beat" // being the 1st container it also executes our custom db-init
      task_environment = [
        { name : "PGPASSWORD", value : module.common_secrets.db_master_password },
        { name : "PSQL_MASTER_USER", value : module.common_secrets.db_master_username }
      ]
    }
  ]

  # Define a local that builds the config map for all services
  ecs_service_configs = {
    for c in local.ecs_custom_vars :
    c.service_name => merge(
      local.ecs_common,
      c,
      var.ecs_configs[c.service_name],
      {
        service_name = "weblate-${c.service_name}"
        app_environment_filename = (
          lookup(c, "env_file", null) != null ?
          "weblate-${lookup(c, "env_file", c.service_name)}.env" :
          "weblate-${c.service_name}.env"
        )

        task_environment = concat(
          local.ecs_common.task_environment,
          lookup(c, "task_environment", []), # service-specific (if any)
          [
            {
              name  = "WEBLATE_SERVICE"
              value = c.service_name
            }
          ]
        )
      }
    )
  }

}
