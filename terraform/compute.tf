data "aws_ami" "amazon" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "selfhealing-"
  image_id      = data.aws_ami.amazon.id
  instance_type = "t3.micro"
  key_name = "selfhealing-key"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
amazon-linux-extras enable docker
yum install -y docker
systemctl start docker
systemctl enable docker

sleep 20

docker pull sannidhisriram/selfhealing-app:latest

docker run -d \
  -p 8080:8080 \
  --name selfhealing \
  --restart unless-stopped \
  sannidhisriram/selfhealing-app:latest
EOF
  )
}

resource "aws_autoscaling_group" "app" {
  desired_capacity = 2
  max_size         = 2
  min_size         = 2

  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300
}
