resource "aws_security_group" "nlb_ec2" {
  name        = "ea2-k3s-${random_id.suffix.hex}"
  description = "EA2 cloud lab: SSH, k3s API, NodePorts, trafico interno cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_ipv4]
  }

  ingress {
    description = "k3s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.k8s_api_cidr_ipv4]
  }

  ingress {
    description = "NodePort rango laboratorio + Grafana"
    from_port   = min(var.alb_nodeport_start, var.grafana_nodeport)
    to_port     = max(var.alb_nodeport_end, var.grafana_nodeport)
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k3s y canal entre nodos (self)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "trafico interno VPC entre nodos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name        = "ea2-rds-${random_id.suffix.hex}"
  description = "MySQL desde nodos k3s"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL desde k3s"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
