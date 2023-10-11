import boto3
import json
import os

# Initialisieren Sie den SQS-Client
sqs = boto3.client('sqs', region_name='eu-central-1')

# Initialisieren Sie den DynamoDB-Client
dynamodb = boto3.client('dynamodb', region_name='eu-central-1')

# Definieren Sie den Namen der SQS-Warteschlange und der DynamoDB-Tabelle
sqs_queue_url = os.environ.get('SQS_QUEUE_URL')
dynamodb_table_name = 'Driver'


def lambda_handler(event, context):
    try:
        # Abfrage der SQS-Warteschlange auf Nachrichten
        response = sqs.receive_message(
            QueueUrl=sqs_queue_url,
            AttributeNames=['All'],
            MaxNumberOfMessages=1,
            MessageAttributeNames=['All'],
            VisibilityTimeout=0,
            WaitTimeSeconds=0
        )
        
        if 'Messages' in response:
            message = response['Messages'][0]
            body = json.loads(message['Body'])
            # Hier können Sie die Nachricht aus der SQS-Nachricht verarbeiten, um festzustellen, ob ein Fahrer benötigt wird.
            # Zum Beispiel, überprüfen Sie die Nachricht und den Inhalt und bestimmen Sie, ob ein Fahrer benötigt wird.
            
            # Fügen Sie hier Ihre Logik zur Überprüfung der Verfügbarkeit eines Fahrers in DynamoDB ein.
            driver_id = body.get('driver_id')
            if driver_id:
                # Überprüfen Sie, ob der Fahrer in der DynamoDB-Tabelle verfügbar ist
                response = dynamodb.get_item(
                    TableName=dynamodb_table_name,
                    Key={
                        'DriverID': {'S': driver_id}
                    }
                )
                if 'Item' in response:
                    driver = response['Item']
                    availability = driver.get('Availability', {}).get('S')
                    if availability == 'Available':
                        # Hier können Sie Ihre Logik ausführen, wenn der Fahrer verfügbar ist
                        # Zum Beispiel, senden Sie eine Bestätigungsnachricht an eine andere SQS-Warteschlange.
                        # Implementieren Sie die Logik, die Sie benötigen, um den Fahrer zuzuweisen oder eine Bestätigung zu senden.
                        # ...
                        print(f'Driver {driver_id} is available. Assigning the driver...')
                    else:
                        print(f'Driver {driver_id} is not available.')
                else:
                    print(f'Driver {driver_id} not found in DynamoDB.')
            
            # Löschen Sie die verarbeitete Nachricht aus der SQS-Warteschlange
            receipt_handle = message['ReceiptHandle']
            sqs.delete_message(QueueUrl=sqs_queue_url, ReceiptHandle=receipt_handle)
        
        return {
            'statusCode': 200,
            'body': 'Processing complete'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
