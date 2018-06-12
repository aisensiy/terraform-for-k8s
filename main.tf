provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "kubernetes" {
  cidr_block           = "10.43.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "kubernetes"
  }
}

resource "aws_subnet" "kubernetes" {
  vpc_id            = "${aws_vpc.kubernetes.id}"
  cidr_block        = "10.43.0.0/16"
  availability_zone = "cn-north-1a"

  tags {
    Name = "kubernetes"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.kubernetes.id}"

  tags {
    Name = "kubernetes"
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

resource "aws_key_pair" "default_keypair" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

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
    Name = "kubernetes"
  }
}

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

resource "aws_iam_instance_profile" "kubernetes_master" {
  name = "kubernetes_master"
  role = "${aws_iam_role.kubernetes_master.name}"
}

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

resource "aws_iam_instance_profile" "kubernetes_worker" {
  name = "kubernetes_worker"
  role = "${aws_iam_role.kubernetes_worker.name}"
}

resource "aws_instance" "master" {
  count         = 1
  ami           = "${var.ami}"
  instance_type = "t2.medium"

  subnet_id                   = "${aws_subnet.kubernetes.id}"
  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
  key_name               = "${var.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.kubernetes_master.id}"

  tags = {
    Name              = "kubernetes_master"
    KubernetesCluster = "aws"
  }
}