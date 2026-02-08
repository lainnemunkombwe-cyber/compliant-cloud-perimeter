# =============================================================================
# FILE: security_groups.tf
# PURPOSE: Micro-Segmentation - Zero Trust security group rules for EC2
# STANDARD ALIGNMENT:
#   - NIST CSF PR.AC-4  : Access Management (least privilege at network layer)
#   - NIST CSF PR.IP-1  : Baseline Configuration
#   - ISO 27001 A.13.1  : Network Security Management
#   - ACSC Essential 8  : Restrict administrative privileges
# =============================================================================

# -----------------------------------------------------------------------------
# SECURITY GROUP - Web Server (Public Subnet)
# -----------------------------------------------------------------------------
# WHY: This SG governs what traffic can reach an EC2 instance sitting in a
# public subnet. We operate on a Zero Trust principle - deny everything by
# default, then allow only what is explicitly required.
#
# INGRESS:
#   - Port 443 (HTTPS) from 0.0.0.0/0 - the ONLY public-facing port. We do not
#     expose port 80 (HTTP). All web traffic must be encrypted.
#   - Port 22 (SSH) is NOT open to 0.0.0.0/0. It is restricted to a single
#     trusted IP (your management IP). This prevents brute-force attacks from
#     the public internet.
#
# EGRESS:
#   - Port 443 outbound to 0.0.0.0/0 - allows the instance to reach external
#     HTTPS endpoints (e.g. package repositories, AWS APIs).
#   - All other outbound traffic is denied by default.
# -----------------------------------------------------------------------------

variable "admin_ip" {
  description = <<EOF
Your trusted management IP address for SSH access.
IMPORTANT: Replace this default with your actual public IP before running
terraform apply. You can find it by running: curl -s https://checkip.amazonaws.com
This ensures SSH is never open to the entire internet.
EOF
  type        = string
  default     = "0.0.0.0/0" # PLACEHOLDER - replace before apply. See note above.
}

resource "aws_security_group" "web_server_sg" {
  name        = "Compliant-WebServer-SG"
  description = "Zero Trust SG for web server in public subnet. HTTPS only inbound, SSH from admin IP only."
  vpc_id      = aws_vpc.compliant_vpc.id

  # --- INGRESS: HTTPS (443) from anywhere ---
  # This is the only port that faces the public internet.
  ingress {
    description = "HTTPS from internet - encrypted web traffic only."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- INGRESS: SSH (22) from trusted admin IP only ---
  # Locked down to a single IP. Never 0.0.0.0/0 in production.
  ingress {
    description = "SSH from trusted admin IP only - not open to the world."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # --- EGRESS: HTTPS (443) outbound ---
  # Allows the instance to reach AWS APIs and external HTTPS services.
  egress {
    description = "HTTPS outbound to internet - required for AWS APIs and updates."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Compliant-WebServer-SG"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-PR.AC-4"
  }
}

# -----------------------------------------------------------------------------
# SECURITY GROUP - Private Workload (Private Subnet)
# -----------------------------------------------------------------------------
# WHY: This SG governs a resource in a private subnet (e.g. a database or
# backend service). It has NO ingress from the public internet at all.
# The only allowed inbound traffic is from the web server's security group -
# this is micro-segmentation. Workloads can only talk to each other if we
# explicitly permit it.
#
# INGRESS:
#   - Port 3306 (MySQL) from the web_server_sg only. No other source.
#
# EGRESS:
#   - Port 443 to 0.0.0.0/0 - allows outbound HTTPS (e.g. to reach AWS APIs).
#     Even though this subnet has no IGW route, this rule exists for correctness
#     if a NAT Gateway is added later.
# -----------------------------------------------------------------------------

resource "aws_security_group" "private_workload_sg" {
  name        = "Compliant-PrivateWorkload-SG"
  description = "Zero Trust SG for private workload. Inbound only from web server SG on port 3306."
  vpc_id      = aws_vpc.compliant_vpc.id

  # --- INGRESS: MySQL (3306) from web server SG only ---
  # This is micro-segmentation in action. Only the web server can talk to this
  # resource, and only on the specific port it needs.
  ingress {
    description     = "MySQL from web server security group only - micro-segmented."
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_sg.id]
  }

  # --- EGRESS: HTTPS (443) outbound ---
  egress {
    description = "HTTPS outbound - for AWS API calls if NAT Gateway is added."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Compliant-PrivateWorkload-SG"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-PR.AC-4"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "web_server_sg_id" {
  description = "The ID of the Web Server Security Group."
  value       = aws_security_group.web_server_sg.id
}

output "private_workload_sg_id" {
  description = "The ID of the Private Workload Security Group."
  value       = aws_security_group.private_workload_sg.id
}
