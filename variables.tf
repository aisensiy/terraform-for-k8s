variable "access_key" {}
variable "secret_key" {}

variable "region" {
  default = "cn-north-1"
}

variable "ami" {
  default = "ami-4f508c22"
}

variable "remote_username" {
  default = "ubuntu"
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "private_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "instance_owner" {
  description = <<DESCRIPTION
As a tag for instance for better filter
DESCRIPTION
}
