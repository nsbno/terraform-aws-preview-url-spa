variable "service_name" {
  description = "The name of the service (e.g., infrademo-spa)."
  type        = string
}

variable "domain_name" {
  description = "Base domain for preview URLs (e.g., infrademo-spa.test.infrademo.vydev.io)"
  type        = string
}

variable "zone_name" {
  description = "Route53 zone name for DNS records (e.g., test.infrademo.vydev.io)"
  type        = string
}
