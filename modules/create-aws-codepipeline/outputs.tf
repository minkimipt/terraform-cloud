output "site_url" {
  description = "Static site URL"
  value       = aws_s3_bucket.hosting_bucket.website_endpoint
}

