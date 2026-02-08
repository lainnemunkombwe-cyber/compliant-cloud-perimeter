# =============================================================================
# FILE: iam_role.tf
# PURPOSE: Least Privilege IAM Role and Instance Profile for EC2
# STANDARD ALIGNMENT:
#   - NIST CSF PR.AC-4  : Managing Access Permissions (Least Privilege)
#   - NIST CSF PR.AC-1  : Access Control
#   - ISO 27001 A.9.2   : User Access Management
#   - ACSC Essential 8  : Restrict administrative privileges
# =============================================================================

# -----------------------------------------------------------------------------
# ASSUME ROLE POLICY
# -----------------------------------------------------------------------------
# WHY: This policy defines WHO can assume this role. In this case, only the
# EC2 service itself. This means no IAM user or external entity can assume
# this role - only an EC2 instance that has it attached via an Instance Profile.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM ROLE - The identity that EC2 will assume
# -----------------------------------------------------------------------------
# WHY: Instead of hardcoding access keys into an EC2 instance (a major
# security risk), we create a Role. The instance assumes this role at launch
# and receives temporary, auto-rotating credentials. This eliminates the need
# for long-lived static keys on the instance.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ec2_compliant_role" {
  name               = "Compliant-EC2-Role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "Compliant-EC2-Role"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-PR.AC-4"
  }
}

# -----------------------------------------------------------------------------
# INLINE POLICY - Scoped permissions for this role
# -----------------------------------------------------------------------------
# WHY: We attach an inline policy rather than a broad managed policy (like
# AmazonEC2FullAccess). This policy grants only the specific permissions the
# instance actually needs - in this case, read-only access to CloudWatch Logs
# so the instance can publish logs for our monitoring setup in the next phase.
# This is Least Privilege in practice.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ec2_logging_policy" {
  name = "Compliant-EC2-Logging-Policy"
  role = aws_iam_role.ec2_compliant_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# INSTANCE PROFILE - The bridge between EC2 and the IAM Role
# -----------------------------------------------------------------------------
# WHY: EC2 instances cannot directly assume an IAM Role. An Instance Profile
# is the wrapper that allows us to attach the Role to an instance at launch.
# This is a required step - without it the Role exists but is not usable.
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_compliant_profile" {
  name = "Compliant-EC2-Instance-Profile"
  role = aws_iam_role.ec2_compliant_role.name

  tags = {
    Name        = "Compliant-EC2-Instance-Profile"
    Environment = "DevSecOps-Project"
  }
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "instance_profile_name" {
  description = "The name of the Instance Profile to attach to EC2."
  value       = aws_iam_instance_profile.ec2_compliant_profile.name
}

output "ec2_role_arn" {
  description = "The ARN of the EC2 IAM Role."
  value       = aws_iam_role.ec2_compliant_role.arn
}
