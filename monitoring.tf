# =============================================================================
# FILE: monitoring.tf
# PURPOSE: Continuous Monitoring - CloudWatch Logs + AWS Config
# STANDARD ALIGNMENT:
#   - NIST CSF DE.CM-1 : The network is monitored to detect potential events
#   - NIST CSF DE.CM-7 : Monitoring for unauthorized activity
#   - NIST CSF PR.PT-1 : Audit/log records are determined and documented
#   - ISO 27001 A.12.4 : Logging and monitoring
# =============================================================================

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ec2_logs" {
  name              = "/aws/ec2/compliant-web-server"
  retention_in_days = 7

  tags = {
    Name        = "Compliant-EC2-Logs"
    Environment = "DevSecOps-Project"
    Alignment   = "NIST-DE.CM-1"
  }
}

# -----------------------------------------------------------------------------
# S3 BUCKET FOR AWS CONFIG
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "config_bucket" {
  bucket = "compliant-config-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Compliant-Config-Bucket"
    Environment = "DevSecOps-Project"
  }
}

resource "aws_s3_bucket_public_access_block" "config_bucket_block" {
  bucket = aws_s3_bucket.config_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR AWS CONFIG
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "config_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_role" {
  name               = "Compliant-Config-Role"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json

  tags = {
    Name        = "Compliant-Config-Role"
    Environment = "DevSecOps-Project"
  }
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name = "Compliant-Config-S3-Policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "${aws_s3_bucket.config_bucket.arn}/*",
          aws_s3_bucket.config_bucket.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AWS CONFIG RECORDER
# -----------------------------------------------------------------------------

resource "aws_config_configuration_recorder" "compliant_recorder" {
  name     = "Compliant-Config-Recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_config_delivery_channel" "compliant_channel" {
  name           = "Compliant-Config-Channel"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket

  depends_on = [aws_config_configuration_recorder.compliant_recorder]
}

resource "aws_config_configuration_recorder_status" "compliant_recorder_status" {
  name       = aws_config_configuration_recorder.compliant_recorder.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.compliant_channel]
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.ec2_logs.name
}

output "config_bucket_name" {
  description = "The S3 bucket storing AWS Config logs."
  value       = aws_s3_bucket.config_bucket.bucket
}
