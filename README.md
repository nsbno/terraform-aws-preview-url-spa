# Terraform AWS Preview URL SPA

Infrastructure to generate preview URLs for Single-Page Applications (SPAs).
Designed to work with [`nsbno/terraform-aws-multi-domain-static-site`](https://github.com/nsbno/terraform-aws-multi-domain-static-site).

## Usage

Remember to check out the [**variables**](variables.tf) and [**outputs**](outputs.tf) to see all options.

```hcl
module "preview_url_spa" {
  source = "github.com/nsbno/terraform-aws-preview-url-spa?ref=x.y.z"

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

Preview URLs use a **separate CloudFront distribution** from production:

- **Production**: `infrademo-spa.test.example.com` → `{account-id}-infrademo-spa-static-files` bucket
- **Previews**: `pr-123.infrademo-spa.test.example.com` → `{account-id}-infrademo-spa-preview` bucket

The preview distribution includes a CloudFront Function that routes subdomain requests to PR-specific folders in S3:
- `pr-123.infrademo-spa.test.example.com/` → `/pr-123/index.html`
- `pr-456.infrademo-spa.test.example.com/app.js` → `/pr-456/app.js`

## Cleanup

Preview deployments are automatically cleaned up:
- **S3 Lifecycle**: Deletes objects older than 90 days
- **GitHub Actions Workflow**: Deletes entire PR folders after 7 days (smarter, PR-aware cleanup)
