# Variables for AWS credentials (optional - can use AWS CLI or IAM roles)
variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

# Configure AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ai-automation"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "ai-and-automation"
}

# Data source for existing S3 bucket
data "aws_s3_bucket" "existing_bucket" {
  bucket = var.bucket_name
}

# ===== API GATEWAY CONFIGURATION =====

# API Gateway REST API
resource "aws_api_gateway_rest_api" "translation_api" {
  name        = "${var.project_name}-api"
  description = "AI Translation Automation API"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource - /translate
resource "aws_api_gateway_resource" "translate_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_rest_api.translation_api.root_resource_id
  path_part   = "translate"
}

# API Gateway Resource - /translate/text
resource "aws_api_gateway_resource" "translate_text_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_resource.translate_resource.id
  path_part   = "text"
}

# API Gateway Resource - /translate/file
resource "aws_api_gateway_resource" "translate_file_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_resource.translate_resource.id
  path_part   = "file"
}

# API Gateway Resource - /translate/status
resource "aws_api_gateway_resource" "translate_status_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_resource.translate_resource.id
  path_part   = "status"
}

# API Gateway Resource - /translate/status/{requestId}
resource "aws_api_gateway_resource" "translate_status_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  parent_id   = aws_api_gateway_resource.translate_status_resource.id
  path_part   = "{requestId}"
}

# ===== API GATEWAY METHODS =====

# POST /translate/text
resource "aws_api_gateway_method" "translate_text_post" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_text_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# POST /translate/file
resource "aws_api_gateway_method" "translate_file_post" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_file_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# GET /translate/status/{requestId}
resource "aws_api_gateway_method" "translate_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.translation_api.id
  resource_id   = aws_api_gateway_resource.translate_status_id_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# ===== LAMBDA FUNCTIONS =====

# IAM role for API Lambda function
resource "aws_iam_role" "api_lambda_role" {
  name = "${var.project_name}-nodejs-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Logs group for API Lambda
resource "aws_cloudwatch_log_group" "api_lambda" {
  name              = "/aws/lambda/${var.project_name}-nodejs-api-handler"
  retention_in_days = 14
}

# IAM policy attachment for basic Lambda execution (API Lambda)
resource "aws_iam_role_policy_attachment" "api_lambda_logs" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for API Lambda function
resource "aws_iam_role_policy" "api_lambda_policy" {
  name = "${var.project_name}-nodejs-api-lambda-policy"
  role = aws_iam_role.api_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.aws_s3_bucket.existing_bucket.arn,
          "${data.aws_s3_bucket.existing_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Create deployment package for API Lambda
data "archive_file" "api_lambda_zip" {
  type        = "zip"
  source_file = "../lambda/api_handler.py"
  output_path = "api_handler.zip"
}

# API Lambda Function
# Lambda function for API handling (your Node.js API)
resource "aws_lambda_function" "api_handler" {
  filename         = "nodejs-api-lambda.zip"
  function_name    = "ai-automation-nodejs-api-handler"
  role            = aws_iam_role.api_lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 512

  source_code_hash = filebase64sha256("nodejs-api-lambda.zip")

  environment {
    variables = {
      AWS_S3_BUCKET_NAME = data.aws_s3_bucket.existing_bucket.id
      NODE_ENV          = "production"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.api_lambda_logs,
    aws_cloudwatch_log_group.api_lambda,
  ]
}

# ===== TRANSLATION LAMBDA (EXISTING) =====

# IAM Role for Translation Lambda
resource "aws_iam_role" "translation_lambda_role" {
  name = "${var.project_name}-translation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Translation Lambda
resource "aws_iam_role_policy" "translation_lambda_policy" {
  name = "${var.project_name}-translation-lambda-policy"
  role = aws_iam_role.translation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${data.aws_s3_bucket.existing_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "translate:TranslateText"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create deployment package for Translation Lambda
data "archive_file" "translation_lambda_zip" {
  type        = "zip"
  source_file = "../lambda/translation_handler.py"
  output_path = "translation_handler.zip"
}

# Translation Lambda Function
resource "aws_lambda_function" "translation_handler" {
  filename         = data.archive_file.translation_lambda_zip.output_path
  function_name    = "${var.project_name}-translation-handler"
  role            = aws_iam_role.translation_lambda_role.arn
  handler         = "translation_handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.translation_lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_BUCKET = data.aws_s3_bucket.existing_bucket.bucket
    }
  }
}

# ===== API GATEWAY INTEGRATIONS =====

# Lambda Integration for /translate/text
resource "aws_api_gateway_integration" "translate_text_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.translate_text_resource.id
  http_method = aws_api_gateway_method.translate_text_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.api_handler.invoke_arn
}

# Lambda Integration for /translate/file
resource "aws_api_gateway_integration" "translate_file_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.translate_file_resource.id
  http_method = aws_api_gateway_method.translate_file_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.api_handler.invoke_arn
}

# Lambda Integration for /translate/status/{requestId}
resource "aws_api_gateway_integration" "translate_status_integration" {
  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  resource_id = aws_api_gateway_resource.translate_status_id_resource.id
  http_method = aws_api_gateway_method.translate_status_get.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.api_handler.invoke_arn
}

# ===== LAMBDA PERMISSIONS =====

# Permission for API Gateway to invoke API Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.translation_api.execution_arn}/*/*"
}

# Permission for S3 to invoke Translation Lambda
resource "aws_lambda_permission" "s3_invoke_translation" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translation_handler.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.existing_bucket.arn
}

# ===== S3 EVENT TRIGGER =====

# S3 Bucket Notification for Translation Processing
resource "aws_s3_bucket_notification" "translation_trigger" {
  bucket = data.aws_s3_bucket.existing_bucket.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.translation_handler.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "requests/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.s3_invoke_translation]
}

# ===== API GATEWAY DEPLOYMENT =====

# API Gateway Deployment
resource "aws_api_gateway_deployment" "translation_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.translate_text_integration,
    aws_api_gateway_integration.translate_file_integration,
    aws_api_gateway_integration.translate_status_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.translation_api.id
  stage_name  = "prod"
}

# ===== OUTPUTS =====

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.translation_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "nodejs_api_lambda_function_name" {
  description = "Name of the Node.js API Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "translation_lambda_function_name" {
  description = "Name of the translation Lambda function"
  value       = aws_lambda_function.translation_handler.function_name
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = data.aws_s3_bucket.existing_bucket.id
}
