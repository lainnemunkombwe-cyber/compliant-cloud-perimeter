# =============================================================================
# FILE: ec2.tf
# PURPOSE: EC2 Instance Deployment - Compliant Web Server
# STANDARD ALIGNMENT:
#   - NIST CSF PR.AC-4  : Access Management (Least Privilege via Instance Profile)
#   - NIST CSF PR.IP-1  : Baseline Configuration
#   - ISO 27001 A.12.6  : Technical Vulnerability Management
# =============================================================================

resource "aws_instance" "compliant_web_server" {
  ami                    = "ami-026992d753d5622bc"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_compliant_profile.name

  associate_public_ip_address = false

  tags = {
    Name        = "Compliant-Web-Server"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-PR.AC-4"
  }
}

output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.compliant_web_server.id
}

output "instance_private_ip" {
  description = "The private IP of the EC2 instance."
  value       = aws_instance.compliant_web_server.private_ip
}
