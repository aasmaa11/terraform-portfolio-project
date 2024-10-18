provider "aws" {
  region = "ca-central-1"
}

# S3 
resource "aws_s3_bucket" "nextjs_bucket" {
  bucket = "assou-nextjs-bucket-hey" # name of the bucket, must be unique
}

# Ownership Control
# ensures bucket owner has complete control over all objects in bucket
# even if uploaded by other AWS accounts
resource "aws_s3_bucket_ownership_controls" "nextjs_ownership_controls" {
  bucket = aws_s3_bucket.nextjs_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "nextjs_bucket_public_access_block" {
  bucket = aws_s3_bucket.nextjs_bucket.id
  # disable public access block settings that prevent any public access
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  # we are disabling them to ensure bucket and its content can be publicly accessible

}

# Bucket ACL
resource "aws_s3_bucket_acl" "nextjs_bucket_acl" {

  # ensures ownership controls and public access block applied before acls setting
  depends_on = [
    aws_s3_bucket_ownership_controls.nextjs_ownership_controls,
    aws_s3_bucket_public_access_block.nextjs_bucket_public_access_block
  ]

  bucket = aws_s3_bucket.nextjs_bucket.id
  acl    = "public-read" # allows anyone to read objects inside bucket
}

# S3 bucket policy 
resource "aws_s3_bucket_policy" "nextjs_bucket_policy" {
  bucket = aws_s3_bucket.nextjs_bucket.id # name of the bucket to which to apply the policy

  # allows public access to objects inside bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"                                    # applied for all users
        Action    = "s3:GetObject"                         # allows get object action
        Resource  = "${aws_s3_bucket.nextjs_bucket.arn}/*" # specifies bucket and all objects inside of it
      }
    ]
  })
}

locals {
  s3_origin_id = "S3-nextjs-portfolio-bucket"
}

# Origin Access Identity
# ensures CLoudFront only can access directly bucket
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "OAI for Next.JS portfolio site"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "nextjs_distribution" {
  origin {
    # DNS domain name of the S3 bucket (where to fetch content from)
    domain_name = aws_s3_bucket.nextjs_bucket.bucket_regional_domain_name
    # Unique identifier for the origin
    origin_id = local.s3_origin_id


    s3_origin_config {
      # specifies OAI used by CloudFront to access S3 bucket
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }


  enabled             = true # enabled to accept end user requests
  is_ipv6_enabled     = true # enables ipv6 support
  comment             = "Next.js portfolio site"
  default_root_object = "index.html" # object returned when end user requests the root URL

  # how CloudFront handles caching
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"] # HTTP requests CloudFront processes and forwards to your Amazon S3 bucket
    cached_methods   = ["GET", "HEAD"]            # HTTP requests for which CloudFront caches the response
    target_origin_id = local.s3_origin_id         # CloudFront routes requests to that origin 

    forwarded_values {     # specifies how CloudFront handles query strings, cookies and headers
      query_string = false # we don't want CloudFront to forward query strings to the origin

      cookies {
        forward = "none" # no cookies forwarded to the origin
      }
    }

    viewer_protocol_policy = "redirect-to-https" # protocol that users can use to access the files in the origin
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400 # max amount of time an object is cached
  }

  # determines from which regions can users access content
  restrictions {
    geo_restriction {
      restriction_type = "none" # anyone can access so no restrictionss
    }
  }

  viewer_certificate {
    # use default ssl and tsl certificate
    cloudfront_default_certificate = true
    # to ensure secure HTTPS requests
  }
}
