resource "aws_kms_key" "this" {
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = true
  enable_key_rotation      = true
  deletion_window_in_days  = 30
}

resource "aws_sqs_queue" "dlq" {
  name              = "tf-example-lambda-sqs-trigger-dlq"
  kms_master_key_id = aws_kms_key.this.id

}

resource "aws_sqs_queue" "lambda_example" {
  name              = "tf-example-lambda-sqs-trigger"
  kms_master_key_id = aws_kms_key.this.id
}

locals {
  arn = aws_sqs_queue.lambda_example.arn
}

module "sqs_trigger" {
  source = "../../lambda_function"

  function_name         = "tf-example-lambda-sqs-trigger"
  description           = "example lambda triggered by sqs queue"
  runtime               = "java8"
  handler               = "example.Hello::handleRequest"
  create_empty_function = true
  kms_key_arn           = aws_kms_key.this.arn

  dead_letter_config = aws_sqs_queue.dlq.arn

  environment_variables = {
    var1 = "test"
  }

  timeout     = 30
  memory_size = 128

  policies = [
    {
      Effect = "Allow"

      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:SendMessage"
      ]

      Resource = [
        "arn:aws:sqs:eu-west-1:733041935482:*",
      ]
    },
    {
      Effect = "Allow"

      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries"
      ]

      Resource = [
        "arn:aws:xray:eu-west-1:733041935482:${aws_sqs_queue.lambda_example.name}",
      ]
    }

  ]

  source_mappings = [
    {
      enabled          = true
      event_source_arn = "arn:aws:sqs:eu-west-1:733041935482:${aws_sqs_queue.lambda_example.name}"
      batch_size       = 10
    },
  ]
}
