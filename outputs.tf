output "preview_bucket_name" {
  description = "Name of the S3 bucket for preview deployments"
  value       = aws_s3_bucket.preview.id
}

output "preview_bucket_arn" {
  description = "ARN of the S3 bucket for preview deployments"
  value       = aws_s3_bucket.preview.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution for preview deployments"
  value       = aws_cloudfront_distribution.preview.id
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.preview.domain_name
}

output "preview_domain" {
  description = "Base domain for preview URLs"
  value       = var.domain_name
}
