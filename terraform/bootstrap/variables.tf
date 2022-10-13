variable "aws_access_key" {
  type = string
  description = "Access key"
}
variable "aws_secret_key" {
  type = string
  description = "SECRET"
}
variable "aws_session_token" {
  type = string
  description = "SESSION"
}
variable "aws_region" {
  type = string
  description = "region of deployment"
}
variable "bucket_name" {
  type = string
  description = "name of your state file bucket"
}

variable "environment" {
  type = string
  description = "environment name"
}

variable "project" {
  type = string
  description = "name of project"
}

variable "component" {
  type = string
  description = "name of the component"
}
