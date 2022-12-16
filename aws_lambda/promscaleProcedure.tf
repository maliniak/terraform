data "archive_file" "python_lambda_package" {
  type = "zip"
  source_file = "${path.module}/scripts/lambda_function.py"
  output_path = "lambda_function.zip"
}

data "aws_ssm_parameter" "grafana_db_data" {
  name = "/vault/grafana_creds"
}


resource "aws_lambda_function" "promscale" {
  function_name = "lambdaPromScale"
  filename      = "lambda_function.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.6"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10

  environment {
    variables = {
      host = module.db.db_instance_endpoint
      dbname = module.db.db_instance_name
      username = jsondecode(data.aws_ssm_parameter.grafana_db_data.value)["db_user"]
      password = jsondecode(data.aws_ssm_parameter.grafana_db_data.value)["db_pass"]
    }
  }

}

data "aws_iam_policy_document" "lambda_assume_role_policy"{
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-promscale"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_cloudwatch_event_rule" "run-promscale-lambda" {
  name                  = "run-promscale-lambda-function"
  description           = "Schedule lambda function"
  schedule_expression   = "cron(0 0 * * 7 *)"
}

resource "aws_cloudwatch_event_target" "promscale-target" {
  target_id = "lambda-function-target"
  rule      = aws_cloudwatch_event_rule.run-promscale-lambda.name
  arn       = aws_lambda_function.promscale.arn
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.promscale.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.run-promscale-lambda.arn
}