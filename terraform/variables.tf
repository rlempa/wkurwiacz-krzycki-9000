variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 20
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "startup_script" {
  description = "Script to run on instance startup"
  type        = string
  default     = "../wkurwiacz-krzyckiej-9000.sh"
}
