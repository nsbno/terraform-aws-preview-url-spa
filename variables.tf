variable "service_name" {
  description = "The name of the service (e.g., infrademo-spa)."
  type        = string
}

variable "base_domain_name" {
  description = "Base domain for preview URLs (will be prefixed with pr-{number}). Example: my-spa.test.myteam.vydev.io results in pr-123.my-spa.test.myteam.vydev.io. The Route53 hosted zone will be automatically extracted from this domain."
  type        = string
}
