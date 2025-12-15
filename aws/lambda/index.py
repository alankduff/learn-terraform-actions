import os
import json
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]

def handler(event, context):
    # When called via API Gateway, the payload is in event["body"]. Otherwise,
    # the event itself is the payload.
    payload = json.loads(event.get("body", "{}")) or event

    message = payload.get("message", "default message")
    event_type = payload.get("type", "default")

    sqs.send_message(
      QueueUrl = QUEUE_URL,
      MessageAttributes = {
        "event_type": {
            "DataType":    "String",
            "StringValue": event_type        
        }
      },
      MessageBody = message
    )

    return {
        "statusCode": 200,
        "response": json.dumps({"status": "queued", "message": message})
    }
