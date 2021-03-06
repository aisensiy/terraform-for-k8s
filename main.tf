provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "kubernetes" {
  cidr_block           = "10.43.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "kubernetes-${terraform.workspace}"
  }
}

resource "aws_subnet" "kubernetes" {
  vpc_id            = "${aws_vpc.kubernetes.id}"
  cidr_block        = "10.43.0.0/16"
  availability_zone = "cn-north-1a"

  tags {
    Name = "kubernetes-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.kubernetes.id}"

  tags {
    Name = "kubernetes-${terraform.workspace}"
  }
}

resource "aws_route_table" "kubernetes" {
  vpc_id = "${aws_vpc.kubernetes.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "kubernetes" {
  subnet_id      = "${aws_subnet.kubernetes.id}"
  route_table_id = "${aws_route_table.kubernetes.id}"
}

/*
resource "aws_key_pair" "default_keypair" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}
*/

resource "aws_security_group" "kubernetes" {
  name   = "kubernetes"
  vpc_id = "${aws_vpc.kubernetes.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "kubernetes-${terraform.workspace}"
  }
}

/*
resource "aws_iam_role" "kubernetes_master" {
  name = "kubernetes-master"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [ { "Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com.cn" }, "Action": "sts:AssumeRole" } ]
}
EOF
}

resource "aws_iam_role_policy" "kubernetes_master" {
  name = "kubernetes"
  role = "${aws_iam_role.kubernetes_master.id}"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"ec2:*",
				"elasticloadbalancing:*",
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:GetDownloadUrlForLayer",
				"ecr:GetRepositoryPolicy",
				"ecr:DescribeRepositories",
				"ecr:ListImages",
				"ecr:BatchGetImage",
				"autoscaling:DescribeAutoScalingGroups",
				"autoscaling:UpdateAutoScalingGroup"
			],
			"Resource": "*"
		}
	]
}
EOF
}
*/

# resource "aws_iam_instance_profile" "kubernetes_master" {
#   name = "kubernetes_master"
#   role = "kubernetes_master"
# }

/*
resource "aws_iam_role" "kubernetes_worker" {
  name = "kubernetes_worker"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [ { "Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com.cn" }, "Action": "sts:AssumeRole" } ]
}
EOF
}

resource "aws_iam_role_policy" "kubernetes_worker" {
  name = "kubernetes"
  role = "${aws_iam_role.kubernetes_worker.id}"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"ec2:Describe*",
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:GetDownloadUrlForLayer",
				"ecr:GetRepositoryPolicy",
				"ecr:DescribeRepositories",
				"ecr:ListImages",
				"ecr:BatchGetImage"
			],
			"Resource": "*"
		}
	]
}
EOF
}
*/

# resource "aws_iam_instance_profile" "kubernetes_worker" {
#   name = "kubernetes_worker"
#   role = "kubernetes_worker"
# }

resource "aws_instance" "master" {
  count         = 1
  ami           = "${var.ami}"
  instance_type = "t2.medium"

  subnet_id                   = "${aws_subnet.kubernetes.id}"
  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
  key_name               = "${var.key_name}"

  iam_instance_profile = "kubernetes_master"

  root_block_device {
    volume_size = 40
  }

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_size = 100
  }

  tags = {
    Name              = "kubernetes_master-${terraform.workspace}"
    KubernetesCluster = "aws"
    Owner             = "${var.instance_owner}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ln -s /usr/bin/python3 /usr/bin/python",
    ]

    connection {
      type        = "ssh"
      user        = "${var.remote_username}"
      private_key = "${file(var.private_key_path)}"
    }
  }
}

resource "aws_eip" "master_ip" {
  instance = "${aws_instance.master.id}"
  vpc      = true

  tags = {
    Name = "kubernetes_master_ip"
  }
}

resource "aws_instance" "worker" {
  count         = 2
  ami           = "${var.ami}"
  instance_type = "t2.medium"

  subnet_id                   = "${aws_subnet.kubernetes.id}"
  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
  key_name               = "${var.key_name}"

  iam_instance_profile = "kubernetes_worker"

  root_block_device {
    volume_size = 40
  }

  ebs_block_device {
    device_name = "/dev/xvdf"
    volume_size = 100
  }

  tags = {
    Name              = "kubernetes_worker-${terraform.workspace}"
    KubernetesCluster = "aws"
    Owner             = "${var.instance_owner}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ln -s /usr/bin/python3 /usr/bin/python",
    ]

    connection {
      type        = "ssh"
      user        = "${var.remote_username}"
      private_key = "${file(var.private_key_path)}"
    }
  }
}
