provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = var.project_name
    }
  }
}

resource "aws_sqs_queue" "job_queue" {
  name = "${var.project_name}-queue"
}


resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_archive" {
  type = "zip"

  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_s3_object" "lambda_object" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "lambda.zip"
  source = data.archive_file.lambda_archive.output_path

  etag = filemd5(data.archive_file.lambda_archive.output_path)
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.job_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project_name}-handler"
  runtime       = "python3.14"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_role.arn

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_object.key
  source_code_hash = data.archive_file.lambda_archive.output_base64sha256
  
  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.job_queue.url
    } 
  }
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.api_handler]
    }
  }
}

action "aws_lambda_invoke" "api_handler" {
  config {
    function_name = aws_lambda_function.api_handler.function_name
    payload = jsonencode({
      message = "Invoke lambda from action",
      type    = "test"
    })
  }
}

resource "aws_lambda_permission" "allow_http_api" {
  statement_id  = "AllowHTTPAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.http_api.api_execution_arn}/*/*"
}


module "http_api" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 6.0.0"

  name               = "${var.project_name}-http-api"
  description        = "HTTP API for lambda function"
  protocol_type      = "HTTP"
  create_domain_name = false

  cors_configuration = {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }

  routes = {
    "POST /job" = {
      integration = {
        uri                    = aws_lambda_function.api_handler.arn
        type                   = "AWS_PROXY"
        payload_format_version = "2.0"
        timeout_milliseconds   = 10000
      }
    }
  }
}


