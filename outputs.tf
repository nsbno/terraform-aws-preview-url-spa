output "preview_bucket_name" {
  description = "Name of the S3 bucket for preview deployments"
  value       = aws_s3_bucket.preview.id
}

output "preview_bucket_arn" {
  description = "ARN of the S3 bucket for preview deployments"
  value       = aws_s3_bucket.preview.arn
}

output "cloudfront_function_arn" {
  description = "ARN of the CloudFront Function for subdomain routing"
  value       = aws_cloudfront_function.subdomain_router.arn
}

output "cloudfront_oai_path" {
  description = "CloudFront Origin Access Identity path for S3 origin configuration"
  value       = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.preview.id}"
}

output "cloudfront_oai_iam_arn" {
  description = "IAM ARN of the CloudFront Origin Access Identity"
  value       = aws_cloudfront_origin_access_identity.preview.iam_arn
}
