

variable "aws_region" {
  description = "The region to create our infrastructure"
  type        = string
  default     = "us-east-2"
}

variable "server_port" {
  description = "The port the web server will use for HTTP/S requests. Set 80 or 443 for production"
  type        = number
  default     = 443
}


variable "elb_port" {
  description     = ""
  type            = number
  default         = 443

}

variable "ami_key_pair_name" { 
  description = "AWS EC2 key pair name."
  type        = string
  sensitive   = true
}


variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}

variable "db_name" {
    description = "Database name"
    type        = string
    default     = "django_app"
}

variable "django_secret_key" {
    description = "Django secret key"
    type        = string
    sensitive   = true
}

variable "django_settings_module" {
    description = "Django settings module"
    type        = string
    default     = "django_app.settings"
}


