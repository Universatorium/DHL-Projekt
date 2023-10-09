import boto3

# Initialisieren Sie den DynamoDB-Client
dynamodb = boto3.client('dynamodb')

# Definieren Sie den Namen der DynamoDB-Tabelle
dynamodb_table_name = 'Drivers'

def lambda_handler(event, context):
    try:
        # Scannen Sie die DynamoDB-Tabelle nach Fahrern mit 'Verfügbarkeit' gleich 'verfügbar'
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
        available_drivers = [item['driverID']['S'] for item in response.get('Items', [])]

        if available_drivers:
            return {
                'statusCode': 200,
                'body': f'Verfügbare Fahrer: {", ".join(available_drivers)}'
            }
        else:
            return {
                'statusCode': 200,
                'body': 'Keine Fahrer verfügbar.'
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Fehler: {str(e)}'
        }
