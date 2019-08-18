provider "aws" {
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = module.s3_origin.bucket_domain
    origin_id   = "s3"

    s3_origin_config {
      origin_access_identity = module.s3_origin.OAI_path
    }
  }
  origin {
    domain_name = module.apigw_origin.domain_name
    origin_id   = "apigw"
    origin_path = module.apigw_origin.stage_path

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "apigw"

    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = "${aws_lambda_function.lambda_edge.qualified_arn}"
    }

    default_ttl = 0
    min_ttl     = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
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

output "domain" {
  value = "${aws_cloudfront_distribution.distribution.domain_name}"
}

module "s3_origin" {
  source = "./modules/s3_origin"
}

module "apigw_origin" {
  source = "./modules/apigw_origin"
}

# lambda@edge

resource "random_id" "id" {
  byte_length = 8
}

data "archive_file" "lambda_edge_zip" {
  type        = "zip"
  output_path = "/tmp/lambda_edge.zip"
  source {
    content  = <<EOF
module.exports.handler = (event, context, callback) => {
	const request = event.Records[0].cf.request;
	request.uri = request.uri.replace(/^\/api/, "");

	callback(null, request);
};
EOF
    filename = "main.js"
  }
}

resource "aws_lambda_function" "lambda_edge" {
  function_name = "${random_id.id.hex}-edge-function"

  filename         = "${data.archive_file.lambda_edge_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_edge_zip.output_base64sha256}"

  handler = "main.handler"
  runtime = "nodejs10.x"
  role    = "${aws_iam_role.lambda_edge_exec.arn}"

  provider = aws.us_east_1
  publish  = true
}

data "aws_iam_policy_document" "lambda_edge_exec_role_policy" {
  statement {
    sid = "1"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_edge_exec_role" {
  role   = "${aws_iam_role.lambda_edge_exec.id}"
  policy = "${data.aws_iam_policy_document.lambda_edge_exec_role_policy.json}"
}

resource "aws_iam_role" "lambda_edge_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

