import boto3
import random

# Initialisieren Sie den DynamoDB-Client
dynamodb = boto3.client('dynamodb')

# Definieren Sie den Namen der DynamoDB-Tabelle
dynamodb_table_name = 'Drivers'

def lambda_handler(event, context):
    try:
        # Scannen Sie die DynamoDB-Tabelle nach verfügbaren Fahrern
        response = dynamodb.scan(
            TableName=dynamodb_table_name,
            FilterExpression='#availability = :available',
            ExpressionAttributeNames={
                '#availability': 'Verfügbarkeit'
            },
            ExpressionAttributeValues={
                ':available': {'S': 'verfügbar'}
            }
        )

        # Extrahieren Sie die Liste der verfügbaren Fahrer aus der Antwort
        available_drivers = response.get('Items', [])

        if available_drivers:
            # Wählen Sie einen zufälligen verfügbaren Fahrer aus
            selected_driver = random.choice(available_drivers)

            # Extrahieren Sie die Fahrer-ID des ausgewählten Fahrers
            driver_id = selected_driver['driverID']['S']

            # Aktualisieren Sie die Verfügbarkeit des ausgewählten Fahrers auf 'nicht verfügbar'
            dynamodb.update_item(
                TableName=dynamodb_table_name,
                Key={
                    'driverID': {'S': driver_id}
                },
                UpdateExpression='SET #availability = :unavailable',
                ExpressionAttributeNames={
                    '#availability': 'Verfügbarkeit'
                },
                ExpressionAttributeValues={
                    ':unavailable': {'S': 'nicht verfügbar'}
                }
            )

            # Geben Sie den ausgewählten Fahrer zurück
            return {
                'statusCode': 200,
                'body': f'Ausgewählter Fahrer: {driver_id}'
            }
        else:
            return {
                'statusCode': 200,
                'body': 'Keine verfügbaren Fahrer vorhanden.'
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Fehler: {str(e)}'
        }
