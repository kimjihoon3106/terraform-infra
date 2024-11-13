provider "aws" {
  region = "ap-northeast-2"
}

data "template_file" "test" {
  template = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl enable httpd
              echo "Hello, world!" | sudo tee /var/www/html/index.html
              sudo systemctl restart httpd
            EOF
}

resource "aws_instance" "Web Server" {
  ami           = ami-00a08b445dc0ab8c1
  instance_type = "t3.micro"
  subnet_id     = subnet-0824c31537806aea3
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "Web Server"
  }
}

resource "aws_instance" "Web Server" {
  ami           = "ami-00a08b445dc0ab8c1"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0824c31537806aea3"

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "Bastion Host"
  }

}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg"
  description = "Allow SSH access for Bastion Host"
  vpc_id      = "vpc-04937fa64d00578ad"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion Security Group"
  }
}


resource "aws_launch_template" "example" { 
  name_prefix = "example-launch-template-"
  description = "Launch template for EC2 instance"

  image_id = "ami-00a08b445dc0ab8c1"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false 
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(data.template_file.test.rendered)
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "example-launch-template"
    }
  }

  tags = {
    Name = "WebServer"
  }
}

resource "aws_lb"  "example_alb" {
  name = "example-alb"
  internal = false 
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets            = ["subnet-0824c31537806aea3", 
                        "subnet-0c7842c6b59de714c"]  

  enable_deletion_protection = false
  idle_timeout = 60

  tags = {
    Name = "example-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example_alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.example_target_group.arn
  }
}

resource "aws_lb_target_group" "example_target_group" {
  name = "example-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = "vpc-04937fa64d00578ad" 

  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "example-target-group"
  }
}

resource "aws_autoscaling_group" "example_asg" {
  desired_capacity = 2
  max_size = 3
  min_size = 1
  vpc_zone_identifier = [
    "subnet-0bb511c0d6f762006",  
    "subnet-0fc1ba3d67612d836" 
  ]

  launch_template {
    id = aws_launch_template.example.id
    version = "$Latest"
  }

  health_check_type = "ELB"
  health_check_grace_period = 300
  force_delete = true
  
  target_group_arns = [aws_lb_target_group.example_target_group.arn]

  tag {
    key = "Name"
    value = "Auto Scaling EC2"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = "vpc-04937fa64d00578ad"  # VPC ID

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow HTTP traffic to EC2 instances from ALB only"
  vpc_id      = "vpc-04937fa64d00578ad"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
