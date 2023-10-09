provider "aws" {
  region = "eu-central-1"  
}

#############################Lambda##################################


resource "aws_lambda_function" "request_lambda" {
  function_name = "request-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "request.lambda_handler"
  runtime       = "python3.9"

  filename = "./request_lambda.zip"

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.order_queue.id
    }
  }
}

resource "aws_lambda_function" "get_driver" {
  function_name = "getdriverlambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.lambda_handler" 
  runtime       = "python3.9"  
  
  filename = "./getdriver/index.zip"
}

resource "aws_lambda_event_source_mapping" "dynamodb_event_source" {
  event_source_arn = aws_dynamodb_table.OrderDB.stream_arn
  function_name    = aws_lambda_function.get_driver.arn
  starting_position = "LATEST"

  # Set batch_size to 1 to process each event individually
  batch_size = 1

  filter_criteria {
    filter {
      
      pattern = jsonencode({
        eventName :["INSERT"]
        # body = {
        # }
      })
    }
  }
}


resource "aws_lambda_function" "orderput" {
  function_name = "orderlambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "orderlambda.lambda_handler" 
  runtime       = "python3.9"  

  filename = "./python/orderlambda.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.OrderDB.name
    }
  }
}

resource "aws_lambda_function" "driverput" {
  function_name = "createdriver"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "driver.lambda_handler" 
  runtime       = "python3.9"

  filename = "./driver/driver.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.OrderDB.name
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_exec_policy" {
  name = "Lambda-exec"
  policy_arn = aws_iam_policy.lambda_policy.arn
  roles      = [aws_iam_role.lambda_exec_role.name]
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:*",
                "sqs:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:::*"
        }
    ]
})
}




############################DynamoDB############################

#1.Table
resource "aws_dynamodb_table" "OrderDB" {
  name           = "Orders"
  hash_key = "packageID"
  read_capacity = 20
  write_capacity = 20

  #stream aktivieren
  stream_view_type = "NEW_IMAGE"
  stream_enabled   = true

  attribute {
    name = "packageID"
    type = "S"
  }
}

#2.Table
resource "aws_dynamodb_table" "DriverDB" {
  name           = "Drivers"
  hash_key = "driverID"
  read_capacity = 20
  write_capacity = 20


  attribute {
    name = "driverID"
    type = "S"
  }
}

######################SQS#############################

resource "aws_sqs_queue" "order_queue" {
  name                      = "order-queue"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400
  visibility_timeout_seconds = 30
  fifo_queue                = false # Change to true for FIFO queue
}

output "sqs_queue_url" {
  value = aws_sqs_queue.order_queue.id
}
