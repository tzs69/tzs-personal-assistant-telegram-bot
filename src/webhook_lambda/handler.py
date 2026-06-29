import json

# Temporary dummy for early stage infrastructure provision
def handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps('Hello World!')
    }