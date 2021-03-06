terraform {
  required_version  = ">=0.12.13"
  backend "s3" {}

}

provider "aws" {
    region                  = "eu-west-2"
    shared_credentials_file = "/home/soham/.aws/credentials"
    profile                 = "soham-pythian-sandbox"
}

data "aws_ami" "docker-swarm-worker-ami" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-????.??.?.????????-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Environment"
    values = ["development"]
  }
}

data "aws_subnet_ids" "private_subnet_groups" {
  vpc_id = data.aws_vpc.selected.id
 
  tags = {
    Tier  = "private"
  }
}

data "aws_security_groups" "private_security_groups" {
  tags      = {
    Role    = "docker-swarm"
  }
}

module "docker-swarm-worker-asg" {
  source                    = "terraform-aws-modules/autoscaling/aws"
  version                   = "~> 3.0"
  name                      = "${var.environment}-${var.role}"
  lc_name                   = "${var.environment}-${var.role}-launch-configuration"
  image_id                  = data.aws_ami.docker-swarm-worker-ami.image_id
  instance_type             = var.instance_type
  security_groups           = data.aws_security_groups.private_security_groups.ids
  vpc_zone_identifier       = data.aws_subnet_ids.private_subnet_groups.ids


  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = var.ebs_volume_size
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size           = var.root_volume_size
      volume_type           = "gp2"
    }
  ]

  asg_name                  = "${var.environment}-${var.role}"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  wait_for_capacity_timeout = 0                                # TBD
  health_check_type         = "EC2"

  tags = [
    {
      key                 = "Environment"
      value               = "var.environment"
      propagate_at_launch = true
    },
    {
      key                 = "Role"
      value               = "var.role"
      propagate_at_launch = true
    },
  ]

  tags_as_map = {
    docker-swarm-role = "worker"
    //extra_tag2 = "extra_value2"
  }
}

//module "nlb" {
//  source                    = "terraform-aws-modules/alb/aws"
//  version                   = "~5.0"

//  name                      = "${var.environment}-{var.role}-nlb"
//  load_balancer_type        = var.load_balancer_type
//  vpc_id                    = data.aws_vpc.default.id
//  subnets                   = data.vpc.private_subnet
//}
