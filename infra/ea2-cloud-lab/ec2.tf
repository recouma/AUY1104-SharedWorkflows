resource "aws_key_pair" "lab" {
  key_name   = "ea2-cloud-lab-${random_id.suffix.hex}"
  public_key = var.public_key
}

resource "aws_instance" "k3s" {
  count                       = 2
  ami                         = var.ec2_ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.k3s.name
  key_name                    = aws_key_pair.lab.key_name
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.nlb_ec2.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = {
    Name    = "ea2-k3s-${count.index + 1}"
    Purpose = "AUY1104-EA2-cloud-lab"
    Role    = count.index == 0 ? "k3s-server" : "k3s-agent"
  }
}
