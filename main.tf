data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  preview_bucket_name = "${local.account_id}-${var.service_name}-preview"
}

resource "aws_s3_bucket" "preview" {
  bucket = local.preview_bucket_name
}

resource "aws_s3_bucket_public_access_block" "preview" {
  bucket = aws_s3_bucket.preview.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "preview" {
  bucket = aws_s3_bucket.preview.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    id     = "delete-old-previews"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_cloudfront_origin_access_control" "preview" {
  provider = aws.us_east_1

  name                              = "${var.service_name}-preview-oac"
  description                       = "OAC for ${var.service_name} preview deployments"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "preview_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.preview.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.preview.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "preview" {
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
  name      = "/__deployment__/applications/${var.service_name}/preview-bucket-name"
  type      = "String"
  overwrite = true
  value     = aws_s3_bucket.preview.id
}

data "aws_route53_zone" "preview" {
  name = var.zone_name
}

module "preview_certificate" {
  source = "github.com/nsbno/terraform-aws-acm-certificate?ref=3.1.1"
  hosted_zone_name = var.zone_name
  domain_name      = var.domain_name
  create_wildcard  = true
}

resource "aws_cloudfront_distribution" "preview" {
  provider = aws.us_east_1

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.service_name} preview deployments"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = ["*.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.preview.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.preview.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.preview.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.subdomain_router.arn
    }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = module.preview_certificate.wildcard_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "preview_wildcard" {
  zone_id = data.aws_route53_zone.preview.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.preview.domain_name
    zone_id                = aws_cloudfront_distribution.preview.hosted_zone_id
    evaluate_target_health = false
  }
}
