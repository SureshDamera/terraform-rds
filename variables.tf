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
  default     = "demo"
}

variable "AWS_REGION" {
  type        = string
  description = "region where to create resources"
  default     = "us-east-1"
}


variable "onmoauth_username" {
  description = "Username for the master DB user"
  default     = "admin"
}

variable "onmoauth_password" {
  description = "Password for the master DB user"
}

variable "onmoauth_port" {
  description = "The port on which the DB accepts connections"
  default     = 3306
}

variable "onmostealth_username" {
  description = "Username for the master DB user"
  default     = "admin"
}

variable "onmostealth_password" {
  description = "Password for the master DB user"
}

variable "onmostealth_port" {
  description = "The port on which the DB accepts connections"
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
