output "http_api_url" {
  description = "URL of API Gateway endpoint."
  value = "${module.http_api.api_endpoint}/job"
}

output "queue_url" {
  description = "URL of SNS Queue."
  value = aws_sqs_queue.job_queue.url
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.api_handler.function_name
}

output "aws_region" {
  description = "AWS region for all resources."
  value = var.aws_region
}
