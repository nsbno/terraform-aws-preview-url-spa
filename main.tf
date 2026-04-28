data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  preview_bucket_name = "${local.account_id}-${var.service_name}-preview-v2"
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

resource "aws_acm_certificate" "preview" {
  provider = aws.us_east_1

  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "preview_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.preview.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.preview.zone_id
}

resource "aws_acm_certificate_validation" "preview" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.preview.arn
  validation_record_fqdns = [for record in aws_route53_record.preview_cert_validation : record.fqdn]
}

resource "aws_cloudfront_cache_policy" "preview" {
  provider = aws.us_east_1

  name        = "${var.service_name}-preview-cache-policy"
  comment     = "Cache policy for ${var.service_name} preview deployments"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
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
    domain_name = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.preview.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.preview.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.preview.id}"
    cache_policy_id        = aws_cloudfront_cache_policy.preview.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

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
    acm_certificate_arn      = aws_acm_certificate_validation.preview.certificate_arn
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
