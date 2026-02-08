# =============================================================================
# FILE: vpc.tf
# PURPOSE: Network Isolation — Custom VPC, Subnets, Internet Gateway, Routes
# STANDARD ALIGNMENT:
#   - NIST CSF PR.AC-4  : Access Management (network-level segmentation)
#   - NIST CSF PR.IP-1  : Baseline Configuration
#   - ISO 27001 A.13.1  : Network Security Management
#   - ACSC Essential 8  : Restrict administrative privileges (reduce attack surface)
# =============================================================================

# -----------------------------------------------------------------------------
# VARIABLE DEFINITIONS
# Centralising values here keeps the rest of the file clean and makes future
# changes (e.g. swapping regions or CIDR ranges) a single-point edit.
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "The primary CIDR block for the VPC. /16 gives us 65,536 addresses to segment."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_1" {
  description = "First Availability Zone for multi-AZ resilience."
  type        = string
  default     = "us-east-1a"
}

variable "az_2" {
  description = "Second Availability Zone for multi-AZ resilience."
  type        = string
  default     = "us-east-1b"
}

# -----------------------------------------------------------------------------
# VPC — The Core Network Boundary
# -----------------------------------------------------------------------------
# WHY: The AWS default VPC comes with permissive defaults (auto-assign public
# IPs, a default subnet in every AZ, etc.). A custom VPC gives us full control
# over the network topology, which is a baseline requirement for any GRC-aligned
# environment.
# -----------------------------------------------------------------------------

resource "aws_vpc" "compliant_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required for Route 53 and some AWS services.
  enable_dns_hostnames = true # Assigns DNS names to EC2 instances — aids auditability.

  tags = {
    Name        = "Compliant-VPC"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-PR.IP-1"
  }
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY — Controlled Egress/Ingress Point
# -----------------------------------------------------------------------------
# WHY: This is the single, auditable point through which traffic moves between
# the VPC and the public internet. Only public subnets will route through it.
# Private subnets will have NO route to this gateway, enforcing isolation.
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.compliant_vpc.id

  tags = {
    Name        = "Compliant-IGW"
    Environment = "DevSecOps-Project"
  }
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNETS — For resources that need internet-facing access
# -----------------------------------------------------------------------------
# WHY: Spread across two AZs for high availability. Public IPs are NOT
# auto-assigned here; we control that explicitly at the instance level.
# This prevents any resource from accidentally becoming internet-facing.
# -----------------------------------------------------------------------------

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.compliant_vpc.id
  cidr_block              = "10.0.1.0/24" # 256 addresses
  availability_zone       = var.az_1
  map_public_ip_on_launch = false # SECURITY: No auto-assign. Explicit is better.

  tags = {
    Name        = "Public-Subnet-AZ1"
    Environment = "DevSecOps-Project"
    Tier        = "Public"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.compliant_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az_2
  map_public_ip_on_launch = false

  tags = {
    Name        = "Public-Subnet-AZ2"
    Environment = "DevSecOps-Project"
    Tier        = "Public"
  }
}

# -----------------------------------------------------------------------------
# PRIVATE SUBNETS — For sensitive workloads with no direct internet access
# -----------------------------------------------------------------------------
# WHY: Databases, application backends, and any sensitive workload live here.
# These subnets have NO route to the Internet Gateway, so they are physically
# isolated from the public internet at the network layer.
# -----------------------------------------------------------------------------

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.compliant_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az_1

  tags = {
    Name        = "Private-Subnet-AZ1"
    Environment = "DevSecOps-Project"
    Tier        = "Private"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.compliant_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az_2

  tags = {
    Name        = "Private-Subnet-AZ2"
    Environment = "DevSecOps-Project"
    Tier        = "Private"
  }
}

# -----------------------------------------------------------------------------
# ROUTE TABLES — Explicit Traffic Flow Control
# -----------------------------------------------------------------------------
# WHY: Route tables define WHERE traffic can go. By creating explicit, separate
# route tables for public and private subnets, we enforce the principle that
# private workloads cannot reach the internet unless we explicitly allow it.
# -----------------------------------------------------------------------------

# --- Public Route Table ---
# Routes traffic destined for the internet (0.0.0.0/0) through the IGW.

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.compliant_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "Public-Route-Table"
    Environment = "DevSecOps-Project"
  }
}

# Associate public route table with both public subnets.
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Private Route Table ---
# NO route to 0.0.0.0/0. Traffic stays inside the VPC.

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.compliant_vpc.id

  # No routes defined here beyond the default local route that AWS adds
  # automatically (10.0.0.0/16 -> local). This is the enforcement.

  tags = {
    Name        = "Private-Route-Table"
    Environment = "DevSecOps-Project"
  }
}

# Associate private route table with both private subnets.
resource "aws_route_table_association" "private_rt_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# -----------------------------------------------------------------------------
# OUTPUTS — Expose resource IDs for use by other Terraform files
# -----------------------------------------------------------------------------
# WHY: Other modules (security_groups.tf, ec2.tf) need to reference these
# resources. Outputs make IDs available without hardcoding.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the Compliant VPC."
  value       = aws_vpc.compliant_vpc.id
}

output "public_subnet_1_id" {
  description = "ID of Public Subnet in AZ1."
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "ID of Public Subnet in AZ2."
  value       = aws_subnet.public_2.id
}

output "private_subnet_1_id" {
  description = "ID of Private Subnet in AZ1."
  value       = aws_subnet.private_1.id
}

output "private_subnet_2_id" {
  description = "ID of Private Subnet in AZ2."
  value       = aws_subnet.private_2.id
}
