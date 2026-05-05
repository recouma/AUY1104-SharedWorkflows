terraform {
  required_version = ">= 1.5.0"

  # Configuración del bucket/key vía CI: terraform init -backend-config=...
  # Sin esto en local: usar el mismo init o ver README.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
