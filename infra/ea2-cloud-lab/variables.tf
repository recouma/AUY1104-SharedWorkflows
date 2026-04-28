variable "aws_region" {
  type        = string
  description = "Región AWS (ej. us-east-1)"
}

variable "availability_zones" {
  type        = list(string)
  description = "Dos zonas de disponibilidad de tu laboratorio (sin usar ec2:DescribeAvailabilityZones). Deben corresponder a aws_region."
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Indica exactamente 2 zonas (ej. us-east-1a y us-east-1b)."
  }
}

variable "ec2_ami_id" {
  type        = string
  description = "AMI Ubuntu 22.04 LTS amd64 para esta region. En AWS Academy: EC2 > Launch instance > copiar AMI ID (sin ec2:DescribeImages en Terraform)."

  validation {
    condition     = can(regex("^ami-[a-z0-9]+$", var.ec2_ami_id))
    error_message = "ec2_ami_id debe ser un AMI ID valido (ami-...)."
  }
}

variable "public_key" {
  type        = string
  description = "Clave pública SSH (una línea) para las instancias k3s"
}

variable "vpc_octet" {
  type        = number
  description = "Segundo octeto de la VPC 10.X.0.0/16 (1–254). Cambiar si colisiona con otro alumno/cuenta."
  default     = 42
  validation {
    condition     = var.vpc_octet >= 1 && var.vpc_octet <= 254
    error_message = "vpc_octet debe estar entre 1 y 254."
  }
}

variable "instance_type" {
  type        = string
  description = "Tipo EC2 para nodos k3s"
  default     = "t3.medium"
}

variable "ssh_cidr_ipv4" {
  type        = string
  description = "CIDR permitido para SSH a los nodos"
  default     = "0.0.0.0/0"
}

variable "k8s_api_cidr_ipv4" {
  type        = string
  description = "CIDR permitido para API k3s (6443/tcp)"
  default     = "0.0.0.0/0"
}

variable "alb_nodeport_start" {
  type        = number
  description = "Primer puerto TCP del NLB hacia NodePorts en los nodos (ej. 30080)"
  default     = 30080
}

variable "alb_nodeport_end" {
  type        = number
  description = "Último puerto inclusivo del rango (ej. 30100 → 21 listeners)"
  default     = 30100
}

variable "grafana_nodeport" {
  type        = number
  description = "NodePort público para Grafana vía NLB"
  default     = 30200
}

variable "db_instance_class" {
  type        = string
  description = "Clase RDS MySQL primario"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "Almacenamiento RDS (GiB)"
  default     = 20
}

variable "route53_zone_id" {
  type        = string
  description = "ID de hosted zone Route53 (opcional). Vacío = no se crea registro DNS."
  default     = ""
}

variable "dns_record_name" {
  type        = string
  description = "Nombre FQDN del registro (ej. lab.alumno.ejemplo.cl). Solo si route53_zone_id está definido."
  default     = ""
}

variable "root_volume_size" {
  type        = number
  default     = 30
}

variable "root_volume_type" {
  type        = string
  default     = "gp2"
}
