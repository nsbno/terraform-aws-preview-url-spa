data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  preview_bucket_name = "${local.account_id}-${var.service_name}-preview"
}

resource "aws_s3_bucket" "preview" {
  provider = aws.us_east_1

  bucket = local.preview_bucket_name
}

resource "aws_s3_bucket_public_access_block" "preview" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.preview.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "preview" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.preview.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_origin_access_identity" "preview" {
  provider = aws.us_east_1

  comment = "OAI for ${var.service_name} preview deployments"
}

data "aws_iam_policy_document" "preview_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontOAI"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.preview.iam_arn]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.preview.arn,
      "${aws_s3_bucket.preview.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "preview" {
  provider = aws.us_east_1

  bucket = aws_s3_bucket.preview.id
  policy = data.aws_iam_policy_document.preview_bucket_policy.json
}

resource "aws_cloudfront_function" "subdomain_router" {
  provider = aws.us_east_1

  name    = "${var.service_name}-preview-router"
  runtime = "cloudfront-js-2.0"
  comment = "Routes PR subdomains to S3 prefix paths for ${var.service_name}"
  publish = true
  code    = file("${path.module}/cloudfront-function/subdomain-router.js")
}

resource "aws_ssm_parameter" "preview_bucket_name" {
  provider = aws.us_east_1

  name      = "/__deployment__/applications/${var.service_name}/preview-bucket-name"
  type      = "String"
  overwrite = true
  value     = aws_s3_bucket.preview.id
}

resource "aws_ssm_parameter" "cloudfront_function_arn" {
  provider = aws.us_east_1

  name      = "/__deployment__/applications/${var.service_name}/cloudfront-function-arn"
  type      = "String"
  overwrite = true
  value     = aws_cloudfront_function.subdomain_router.arn
}

resource "aws_ssm_parameter" "cloudfront_oai_path" {
  provider = aws.us_east_1

  name      = "/__deployment__/applications/${var.service_name}/cloudfront-oai-path"
  type      = "String"
  overwrite = true
  value     = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.preview.id}"
}
