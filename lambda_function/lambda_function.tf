data "aws_arn" "kms_key" {
  arn = var.kms_key_arn
}


data "aws_arn" "dead_letter_config" {
  arn = var.dead_letter_config
}


resource "aws_lambda_function" "lambda" {
  function_name                  = var.function_name
  description                    = var.description
  role                           = aws_iam_role.lambda.arn
  handler                        = var.handler
  runtime                        = var.runtime
  filename                       = var.create_empty_function ? "${path.module}/placeholder.zip" : var.filename
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish


  dynamic "dead_letter_config" {
    for_each = data.aws_arn.dead_letter_config.arn == null ? [] : [true]
    content {
      target_arn = data.aws_arn.dead_letter_config.arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = ["${var.vpc_config["subnet_ids"]}"]
    security_group_ids = ["${var.vpc_config["security_group_ids"]}"]
  }

  kms_key_arn = data.aws_arn.kms_key.arn
  environment {
    variables = var.environment_variables
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      filename,
    ]
  }
}

