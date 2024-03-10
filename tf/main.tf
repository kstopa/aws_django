
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}


provider "aws" {
  region = var.aws_region
}


## AWS ASG Launch Config
# Ubuntu 22.04 LTS ARM64
resource "aws_launch_configuration" "as_conf" {
  image_id               = "ami-0748d13ffbc370c2b"
  instance_type          = "t4g.micro"
  key_name               = var.ami_key_pair_name
  security_groups        = [aws_security_group.instance.id]
  user_data              = <<-EOF
      #!/bin/bash
      sudo apt-get update
      sudo apt-get -y -qq upgrade
      sudo apt-get -y -qq install fail2ban git rdiff-backup libpq-dev uwsgi nginx unzip postgresql-client-14
      sudo apt-get -y -qq install python-is-python3 python3-pip python3-venv python3-psycopg2 uwsgi-plugin-python3 virtualenv gdal-bin
      echo "RDS_DB_NAME=${var.db_name}" >> /etc/environment
      echo "RDS_USERNAME=${var.db_username}" >> /etc/environment
      echo "RDS_PASSWORD=${var.db_password}" >> /etc/environment
      echo "RDS_HOSTNAME=${aws_db_instance.django_db.address}" >> /etc/environment
      echo "RDS_PORT=5432" >> /etc/environment
      echo "SECRET_KEY=\"${var.django_secret_key}\"" >> /etc/environment
      echo "DJANGO_SETTINGS_MODULE=${var.django_settings_module}" >> /etc/environment
      # Install ollama for content generation
      curl -fsSL https://ollama.com/install.sh | sh
      EOF

  root_block_device {
      volume_size = "8"
      volume_type = "gp2"
      delete_on_termination = true
    }

  lifecycle {
    create_before_destroy = true
  }
}


data "aws_availability_zones" "all" {}


## AWS ASG
resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.as_conf.id
  availability_zones   = data.aws_availability_zones.all.names
  
  min_size = 1
  max_size = 2

  load_balancers    = [aws_elb.elb.name]
  # health_check_type = "ELB"
  health_check_type = "EC2"
  health_check_grace_period = 300

  # Make sure db exists before Django calls it.
  depends_on            = [aws_db_instance.django_db]

  tag {
    key                 = "Name"
    value               = "tf-django"
    propagate_at_launch = true
  }
}


## AWS ELB
resource "aws_elb" "elb" {
  name               = "terraform-elb"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 300
    timeout             = 5
    healthy_threshold   = 2 
    unhealthy_threshold = 10
  }


  # This adds a listenter for incoming HTTP requests.
  listener {
    lb_port           = var.elb_port 
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

resource "aws_lb_cookie_stickiness_policy" "elb-stickiness" {
  name                     = "elb-stickiness-policy"
  load_balancer            = aws_elb.elb.id
  lb_port                  = 80
  cookie_expiration_period = 30
}



## Our Database
resource "aws_db_instance" "django_db" {
  identifier              = "django-postgis-db"
  instance_class          = "db.t3.micro"  # Change instance class as per your requirement (eg. db.t3.medium)
  engine                  = "postgres"
  allocated_storage       = 20
  storage_type            = "gp2"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true

  # Security Group for the RDS instance
  vpc_security_group_ids  = [aws_security_group.allow_rds.id]

  # Apply tags
  tags = {
    Name = "PostGIS"
  }
}

# Provisioner to enable PostGIS extension and set DB and Django app environment variables
resource "null_resource" "enable_postgis" {
  depends_on = [aws_db_instance.django_db]

  provisioner "local-exec" {
    command = <<EOT
      aws rds wait db-instance-available --db-instance-identifier ${aws_db_instance.django_db.identifier}
      echo ${var.db_password} psql -u ${var.db_username} -d ${var.db_name} -h ${aws_db_instance.django_db.address} -c "CREATE EXTENSION postgis;"
    EOT
  }
}

## SECURITY GROUPS

resource "aws_security_group" "instance" {
  name = "terraform-instance"
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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all inbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

}


resource "aws_security_group" "elb" {
  name = "terraform-elb"
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  # Inbound HTTP from everywhere
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from everywhere
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



## Only allow SQL from ASG group.
resource "aws_security_group" "allow_rds" {
  name          = "allow_rds"
  description   = "Allow SQL access."
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  # Inbound allow sql
  ingress {
    from_port         = 5432
    to_port           = 5432
    protocol          = "tcp"
    security_groups   = [aws_security_group.instance.id]
  }
}


