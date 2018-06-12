variable "access_key" {}
variable "secret_key" {}

variable "region" {
  default = "cn-north-1"
}

variable "ami" {
  default = "ami-4f508c22"
}

variable "public_key_path" {
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
