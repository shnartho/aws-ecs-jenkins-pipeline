locals {
  # Flattened form of var.tags for provider default_tags and per-resource Name tag merges.
  common_tags = {
    environment = var.tags.environment
    product     = var.tags.product
    service     = var.tags.service
  }
}
