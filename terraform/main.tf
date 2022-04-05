resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "this" {
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Default subnet for eu-west-1a"
  }
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

resource "aws_security_group" "ec2-sg" {
  name        = "ec2-sg"
  description = "SSH and HTTPS access"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description      = "HTTPS from everywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["107.22.40.20/32", "18.215.226.36/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_network_interface" "this" {
  subnet_id   = aws_default_subnet.this.id
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2-sg.id]
  
  network_interface {
    network_interface_id = aws_network_interface.this.id
    device_index         = 0
  }
}

resource "aws_security_group" "rds-sg" {
  name        = "rds-sg"
  description = "SSH and HTTPS access"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description      = "DB connection"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [aws_default_vpc.default.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

}

resource "aws_db_subnet_group" "this" {
  name       = "db-sg"
  subnet_ids = data.aws_subnets.this.ids
}

resource "aws_db_parameter_group" "this" {
  name   = "pgsql"
  family = "postgres13"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  identifier             = "postgresdb"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "13.1"
  username               = "testuser"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  skip_final_snapshot    = true
}
