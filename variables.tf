// tags
variable "tags" {
  type        = map(string)
  description = "tags add to all resources created with this module"
  default = {
    Variable1 = "Variable1Value"
    Variable2 = "Variable2Value"
    Variable3 = "Variable3Value"
  }
}

// app variables
variable "app_name" {
  type        = string
  description = "application name"
  default     = "test"
}

variable "AWS_REGION" {
  type        = string
  description = "region where to create resources"
  default     = "us-east-1"
}


variable "onmostealth_username" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  default     = "admin"
}

variable "onmostealth_password" {
  description = "A list of availability zones names or ids in the region"
}

variable "onmostealth_port" {
  description = "A list of public subnets inside the VPC"
  default     = 3306
}

variable "profile" {
  type        = string
  description = "profile"
  default     = "default"
}

#-- var.tf -------------------------------------------------------------------

variable "provider_env_roles" {
  type = map(string)
  default = {
    "default" = ""
  }
}
