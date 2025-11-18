# IAM Role pour Lambda
resource "aws_iam_role" "lambda" {
  name = "kambriq-lambda-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "kambriq-lambda-role-${var.env}"
    Env  = var.env
  }
}

# Policy pour accès VPC (nécessaire pour Lambda dans VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy pour accès S3 media bucket
resource "aws_iam_role_policy" "lambda_s3" {
  name = "kambriq-lambda-s3-${var.env}"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_media_bucket_arn,
          "${var.s3_media_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy pour envoi d'emails via SES
resource "aws_iam_role_policy" "lambda_ses" {
  name = "kambriq-lambda-ses-${var.env}"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = var.ses_identity_arn
      }
    ]
  })
}

# Policy pour CloudWatch Logs (basique, déjà inclus dans AWSLambdaBasicExecutionRole)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

