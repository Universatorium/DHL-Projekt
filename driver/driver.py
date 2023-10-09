import boto3
import uuid

dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    table_name = "Drivers"  
    num_drivers = 10  

    for i in range(1, num_drivers + 1):
        driver_id = str(uuid.uuid4())  
        driver_name = f"Driver-{i}" 
        availability = "verfügbar" 

        item = {
            "driverID": {"S": driver_id},
            "Name": {"S": driver_name},
            "Verfügbarkeit": {"S": availability}
        }

        try:
            dynamodb.put_item(
                TableName=table_name,
                Item=item
            )
            print(f"Driver {driver_name} erfolgreich in die Tabelle {table_name} eingefügt")
        except Exception as e:
            print(f"Fehler beim Einfügen des Drivers {driver_name} in die Tabelle {table_name}: {str(e)}")

    return {
        "statusCode": 200,
        "body": f"{num_drivers} Dummy-Driverdatensätze erfolgreich eingefügt"
    }