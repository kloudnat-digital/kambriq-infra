output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_url" {
  description = "Full CloudFront URL (https://...)"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "s3_bucket_id" {
  description = "S3 bucket ID for static assets"
  value       = aws_s3_bucket.static.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for static assets"
  value       = aws_s3_bucket.static.arn
}

output "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}

output "lambda_ssr_function_name" {
  description = "Lambda SSR function name"
  value       = aws_lambda_function.ssr.function_name
}

output "lambda_ssr_function_arn" {
  description = "Lambda SSR function ARN"
  value       = aws_lambda_function.ssr.arn
}
