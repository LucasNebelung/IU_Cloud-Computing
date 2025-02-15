############################################################
###### Hosting a simple webpage on AWS using Terraform #######
#############################################################


##################################################
# 1) Terraform Configuration & Provider Settings
##################################################

provider "aws" {
  region = "eu-central-1"
}


##################################################
# 2) create a private S3 Bucket
##################################################

# create an S3 bucket with name 
resource "aws_s3_bucket" "private_bucket" {
  bucket = "iu-test-bucket"
}


# upload the index.html file to the S3 bucket
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.private_bucket.id
  key    = "index.html"       # name of the file in S3
  source = "index.html"       #local file
  content_type = "text/html"
}

##################################################
# 3) Origin Access Control (OAC) 
##################################################
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "my-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

##################################################
# 4) Cloudfront Distribution with S3 Bucket as Origin
##################################################

#create a cloudfront distribution first
resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  default_root_object = "index.html"
  is_ipv6_enabled = true
  wait_for_deployment = true

# Where does Cloudfront pull content from?
  origin {
    domain_name = aws_s3_bucket.private_bucket.bucket_regional_domain_name
    origin_id = "private-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }
#set cache behaviors
  default_cache_behavior {
    target_origin_id = "private-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = ["GET", "HEAD", ]
    cached_methods = ["GET", "HEAD",]
    compress = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
    

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
   viewer_certificate {
    cloudfront_default_certificate = true
  }
  
}
 
##################################################
# 5) Bucket Policy to Allow CloudFront Read
##################################################

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bucket_policy_doc" {
  statement {
    sid = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.private_bucket.arn}/*"
    ]
    
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }	
    
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.private_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_doc.json
}

##################################################
# 6) Outputs
##################################################

output "cloudfront_domain_name" {
  description = "Use this domain to access your website via CloudFront"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "bucket_name" {
  value = aws_s3_bucket.private_bucket.bucket
}