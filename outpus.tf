outputs "rds_command" {
    value = "psql -h ${module.postgres.db_instance_endpoint} -U ${module.postgres.db_instance_username} -d ${module.postgres.db_instance_name}"
}