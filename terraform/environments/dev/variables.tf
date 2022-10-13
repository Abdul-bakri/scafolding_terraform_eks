#####
#Credentials
####
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
# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = ""
}
