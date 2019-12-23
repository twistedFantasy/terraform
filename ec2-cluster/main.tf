provider "aws" {
  region = "us-east-2"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
}

variable "elb_port" {
  description = "The port the elb will use for HTTP requests"
  type = number
  default = 80
}

data "aws_availability_zones" "all" {}

resource "aws_security_group" "security_group_example" {
  name = "terraform_security_group_example"

  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "launch_configuraiton_example" {
  image_id = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.security_group_example.id]

  user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World" > index.html
            nohup busybox httpd -f -p "${var.server_port}" &
            EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaling_group_example" {
  launch_configuration = aws_launch_configuration.launch_configuraiton_example.id
  availability_zones = data.aws_availability_zones.all.names

  load_balancers = [aws_elb.elb_example.name]
  health_check_type = "ELB"

  min_size = 2
  max_size = 5

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "security_group_elb_example" {
  name = "terraform-security-group_elb-example"

  ingress {
    from_port = var.elb_port
    to_port = var.elb_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "elb_example" {
  name = "terraform-elb-example"
  security_groups = [aws_security_group.security_group_elb_example.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target = "HTTP:${var.server_port}/"
    interval = 30
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  listener {
    instance_port = var.server_port
    instance_protocol = "http"
    lb_port = var.elb_port
    lb_protocol = "http"
  }
}

output "clb_dns_name" {
  value = aws_elb.elb_example.dns_name
  description = "The domain name of the load balancer"
}
