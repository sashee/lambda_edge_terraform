output "OAI_path" {
  value = aws_cloudfront_origin_access_identity.OAI.cloudfront_access_identity_path
}

output "bucket_domain" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}
