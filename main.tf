provider "aws" {
  region = "eu-central-1"  
}

#############################Lambda##################################
data "archive_file" "lambda_code0" {
  type        = "zip"
  source_file = "./python/request.py"  # Pfad zur Python-Datei
  output_path = "./python/request.zip" # Pfad, wohin das ZIP-Archiv gepackt werden soll
}

resource "aws_lambda_function" "request" {
  function_name = "request-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "request.lambda_handler"
  runtime       = "python3.9"

  filename = "./python/request.zip"

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.order_queue.id
    }
  }
}
###   Lambda-Funktion zum Senden von Bestellungen an die SQS-Queue

resource "aws_lambda_event_source_mapping" "dynamodb_event_source" {
  event_source_arn = aws_dynamodb_table.OrderDB.stream_arn
  function_name    = aws_lambda_function.request.arn
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

data "archive_file" "lambda_code2" {
  type        = "zip"
  source_file = "./python/orderlambda.py"  # Pfad zur Python-Datei
  output_path = "./python/orderlambda.zip" # Pfad, wohin das ZIP-Archiv gepackt werden soll
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
data "archive_file" "lambda_code3" {
  type        = "zip"
  source_file = "./driver/driver.py"  # Pfad zur Python-Datei
  output_path = "./driver/driver.zip" # Pfad, wohin das ZIP-Archiv gepackt werden soll
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

data "archive_file" "lambda_code4" {
  type        = "zip"
  source_file = "./python/sns.py"  # Pfad zur Python-Datei
  output_path = "./python/sns.zip" # Pfad, wohin das ZIP-Archiv gepackt werden soll
}
resource "aws_lambda_function" "sns" {
  function_name = "sns-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "sns.lambda_handler"
  runtime       = "python3.9"

  filename = "./python/sns.zip"

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.order_queue.id
      SNS_TOPIC_ARN = aws_sns_topic.driver.arn
    }
  }
}

#####################################################################
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
                "sqs:*",
                "sns:*"
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
            "Resource": "arn:aws:logs:*:*:*:*"
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
######################SQS######################################

resource "aws_sqs_queue" "order_queue" {
  name                      = "order-queue.fifo"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400
  visibility_timeout_seconds = 30
  fifo_queue                = true
}
# resource "aws_iam_policy" "sqs_policy" {
#   name = "sqs-policy"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = [
#           "sqs:SendMessage",
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes",
#           "sqs:GetQueueUrl",
#         ],
#         Effect   = "Allow",
#         Resource = aws_sqs_queue.order_queue.arn
#       },
#     ],
#   })
# }
# resource "aws_iam_policy_attachment" "sqs_exec_policy" {
#   name = "Lambda-SQS"
#   policy_arn = aws_iam_policy.sqs_policy.arn
#   roles      = [aws_iam_role.lambda_exec_role.name]
# }

output "sqs_queue_url" {
  value = aws_sqs_queue.order_queue.id
}
###########################SNS##################################

resource "aws_sns_topic" "driver" {
  name = "driver-topic"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.driver.arn
  protocol  = "email"
  endpoint  = "matthias.bandholtz@docc.techstarter.de" # Ihre E-Mail-Adresse hier
}

output "sns_topic_arn" {
  value = aws_sns_topic.driver.arn
}
################################################################