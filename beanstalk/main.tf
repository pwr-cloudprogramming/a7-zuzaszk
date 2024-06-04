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

resource "aws_security_group" "backend_sg" {
  name        = "backend_sg"
  description = "Allow traffic for Backend"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "http for backend"
    from_port   = 5000
    to_port     = 5000
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
    Name = "allow-ssh-http-backend"
  }
}

resource "aws_security_group" "frontend_sg" {
  name        = "frontend_sg"
  description = "Allow traffic for Frontend"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "http for frontend"
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
  tags = {
    Name = "allow-http-frontend"
  }
}

resource "aws_elastic_beanstalk_application" "backend_app" {
  name        = "backend-app-266608"
  description = "Backend Application"
}

resource "aws_elastic_beanstalk_application_version" "backend_version" {
  name        = "v1"
  application = aws_elastic_beanstalk_application.backend_app.name
  description = "Backend Application Version"
  bucket      = aws_s3_bucket.app_bucket.bucket
  key         = aws_s3_object.backend_s3o.key
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "app-bucket-266608"
}

resource "aws_s3_object" "backend_s3o" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key    = "backend_deploy.zip"
  source = "backend_deploy.zip"
}


resource "aws_elastic_beanstalk_environment" "backend_env" {
  name                = "my-backend-env-266608"
  application         = aws_elastic_beanstalk_application.backend_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.2 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.backend_version.name
  cname_prefix        = "backend-266608"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.my_vpc.id
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "LabInstanceProfile"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id])
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.backend_sg.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::891377008031:role/LabRole"
    # value     = "LabRole"
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "SupportedArchitectures"
    value     = "x86_64"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.small"
  }
}

output "backend_beanstalk_app_url" {
  value = "http://${aws_elastic_beanstalk_environment.backend_env.cname}"
}

resource "aws_elastic_beanstalk_application" "frontend_app" {
  name        = "frontend-app-266608"
  description = "Frontend Application"
}


resource "aws_elastic_beanstalk_application_version" "frontend_version" {
  name        = "v2"
  application = aws_elastic_beanstalk_application.frontend_app.name
  description = "Frontend Application Version"
  bucket      = aws_s3_bucket.app_bucket.bucket
  key         = aws_s3_object.frontend_s3o.key
}

resource "aws_s3_object" "frontend_s3o" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key    = "frontend_deploy.zip"
  source = "frontend_deploy.zip"
}

resource "aws_elastic_beanstalk_environment" "frontend_env" {
  name                = "my-frontend-env-266608"
  application         = aws_elastic_beanstalk_application.frontend_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.2 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.frontend_version.name
  cname_prefix        = "frontend-266608"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.my_vpc.id
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "LabInstanceProfile"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id])
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.frontend_sg.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::891377008031:role/LabRole"
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "SupportedArchitectures"
    value     = "x86_64"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.small"
  }
}

output "frontend_beanstalk_app_url" {
  value = "http://${aws_elastic_beanstalk_environment.frontend_env.cname}"
}
