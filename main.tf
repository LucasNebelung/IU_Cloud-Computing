############################################################
###### Hosting a simple webpage on AWS using Terraform #######
#############################################################


##################################################
# Terraform Configuration & Provider Settings
##################################################

provider "aws" {
  region = "eu-central-1"
}


##################################################
# S3 Bucket for Static Website
##################################################

resource "aws_s3_bucket" "website_bucket" {
  bucket = "iu-test-bucket"

}
# define aws s3 bucket website config to host static website
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id
  index_document { 
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# upload the index.html file to the S3 bucket
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website_bucket.id
  key    = "index.html"       # name of the file in S3
  source = "index.html"       #local file
  content_type = "text/html"
}

##################################################
# Cloudfront Distribution
##################################################

