# Terraform AWS Preview URL SPA

Infrastructure to generate preview URLs for Single-Page Applications (SPAs).

## Relevant Repositories

- [`nsbno/terraform-aws-multi-domain-static-site`](https://github.com/nsbno/terraform-aws-multi-domain-static-site) - Production static site hosting module
- [`nsbno/infrademo-spa`](https://github.com/nsbno/infrademo-spa) - Full working example implementation

## Usage

Remember to check out the [**variables**](variables.tf) and [**outputs**](outputs.tf) to see all options.

```hcl
module "preview_url_spa" {
  source = "github.com/nsbno/terraform-aws-preview-url-spa?ref=x.y.z"
  count  = var.environment == "test" ? 1 : 0  # Optional: only create the preview URL resources in test environment

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  service_name = "infrademo-spa"
  domain_name  = "infrademo-spa.test.example.com"
  zone_name    = "test.example.com"
}
```

This creates:
- S3 bucket for preview deployments (`{account-id}-{service}-preview`)
- CloudFront distribution with wildcard domain support (`*.infrademo-spa.test.example.com`)
- CloudFront Function for subdomain-to-path routing (e.g., `pr-123.infrademo-spa.test.example.com` → `/pr-123/` in S3)
- ACM certificate for wildcard domain
- Route53 wildcard DNS record

## Architecture

![Architecture Diagram](architecture.png)