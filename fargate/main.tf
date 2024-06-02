provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_security_group" "server_sg" {
  name        = "server_sg"
  description = "Allow SSH and HTTP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "http for backend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http for frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
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
    Name = "allow-ssh-http"
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "app-cluster-266608"
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task-266608"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = "arn:aws:iam::891377008031:role/LabRole"
  task_role_arn            = "arn:aws:iam::891377008031:role/LabRole"

  container_definitions = jsonencode(
    [
      {
        "name" : "backend",
        "image" : "891377008031.dkr.ecr.us-east-1.amazonaws.com/backend:latest",
        "essential" : true,
        "memory" : 256,
        "portMappings" : [
          {
            "hostPort" : 5000,
            "containerPort" : 5000
          }
        ]
      },
      {
        "name" : "frontend",
        "image" : "891377008031.dkr.ecr.us-east-1.amazonaws.com/frontend:latest",
        "essential" : true,
        "memory" : 256,
        "portMappings" : [
          {
            "hostPort" : 80,
            "containerPort" : 80
          }
        ]
      }
    ]
  )
}

resource "aws_ecs_service" "app_service" {
  name            = "app-service-266608"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
    security_groups  = [aws_security_group.server_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_ecs_task_definition.app_task]
}