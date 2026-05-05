output "vpc_cidr" {
  value       = local.vpc_cidr
  description = "CIDR de la VPC desplegada"
}

output "nlb_dns_name" {
  value       = aws_lb.nlb.dns_name
  description = "DNS del NLB (TCP NodePorts). Alias interno AWS."
}

output "public_endpoint_hint" {
  value       = "Usa http(s)://${aws_lb.nlb.dns_name}:<nodeport> segun servicio (Grafana ${var.grafana_nodeport}, API segun manifest)."
  description = "Referencia rapida"
}

output "vm_a_public_ip" {
  value       = aws_instance.k3s[0].public_ip
  description = "IP publica MV A (misma EC2 index 0; k3s autocontenido)"
}

output "vm_a_private_ip" {
  value       = aws_instance.k3s[0].private_ip
  description = "IP privada MV A"
}

output "vm_b_public_ip" {
  value       = aws_instance.k3s[1].public_ip
  description = "IP publica MV B (misma EC2 index 1; k3s autocontenido)"
}

output "vm_b_private_ip" {
  value       = aws_instance.k3s[1].private_ip
  description = "IP privada MV B"
}

output "ssh_user" {
  value = "ubuntu"
}

output "rds_primary_endpoint" {
  value       = aws_db_instance.primary.address
  description = "Endpoint MySQL primario (escritura)"
}

output "rds_replica_endpoint" {
  value       = aws_db_instance.replica.address
  description = "Endpoint MySQL replica (solo lectura)"
}

output "rds_master_username" {
  value       = aws_db_instance.primary.username
  description = "Usuario maestro RDS"
}

output "rds_master_password" {
  value       = random_password.db_master.result
  sensitive   = true
  description = "Password maestro (se crea secret en K8s en CI)"
}

output "route53_fqdn" {
  value       = length(aws_route53_record.nlb_alias) > 0 ? aws_route53_record.nlb_alias[0].fqdn : ""
  description = "FQDN si se configuro Route53"
}
