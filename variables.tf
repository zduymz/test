variable "stack_name" {
  default = "something"
}

variable "region" {
  default = "us-west-2"
}

variable "vpc_cidr" {
  default     = "10.99.0.0/18"
  description = ""
}
variable "vpc_public_subnets" {
  default     = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  description = ""
}
variable "vpc_private_subnets" {
  default     = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  description = ""
}
variable "vpc_db_subnets" {
  default     = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]
  description = ""
}
variable "db_instance_type" {
  default     = "db.t4g.large"
  description = ""
}
variable "db_engine_version" {
  default     = "14.1"
  description = ""
}
variable "db_major_engine_version" {
  default     = "14"
  description = ""
}
variable "db_size" {
  default     = 20
  description = ""
}
variable "db_username" {
  default     = "complete_postgresql"
  description = ""
}
variable "db_default_db_name" {
  default     = "complete_postgresql"
  description = ""
}

variable "ec2_instance_type" {
  default     = "c5.large"
  description = ""
}

variable "ec2_ebs_vol_size" {
  default     = 1
  description = ""
}

variable "tags" {
  default = {
    Owner = "user"
    StackName = "something"
  }
}