import json
import boto3
import logging
from datetime import datetime
import uuid

# Initialize AWS clients
translate_client = boto3.client('translate', region_name='eu-north-1')
s3_client = boto3.client('s3', region_name='eu-north-1')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Your existing bucket name
BUCKET_NAME = 'ai-and-automation'

def lambda_handler(event, context):
    """
    Lambda function to handle translation requests triggered by S3 uploads
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse S3 event
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            logger.info(f"Processing object: {object_key} from bucket: {bucket_name}")
            
            # Only process files in the 'requests' folder
            if not object_key.startswith('requests/'):
                logger.info(f"Skipping {object_key} - not in requests folder")
                continue
                
            # Download and parse the JSON file
            response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
            content = json.loads(response['Body'].read().decode('utf-8'))
            
            # Extract translation parameters
            source_language = content.get('source_language', 'auto')
            target_language = content.get('target_language', 'en')
            text_to_translate = content.get('text', '')
            request_id = content.get('request_id', str(uuid.uuid4()))
            
            logger.info(f"Processing translation request: {request_id}")
            logger.info(f"Source: {source_language}, Target: {target_language}")
            
            # Perform translation using AWS Translate
            translation_result = translate_client.translate_text(
                Text=text_to_translate,
                SourceLanguageCode=source_language,
                TargetLanguageCode=target_language
            )
            
            # Prepare response data
            response_data = {
                'request_id': request_id,
                'original_text': text_to_translate,
                'translated_text': translation_result['TranslatedText'],
                'source_language': translation_result['SourceLanguageCode'],
                'target_language': translation_result['TargetLanguageCode'],
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'completed'
            }
            
            # Log the request and response
            log_data = {
                'request': content,
                'response': response_data,
                'processing_time': datetime.utcnow().isoformat()
            }
            
            # Upload response to S3 responses folder
            response_key = f"responses/{request_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
            s3_client.put_object(
                Bucket=bucket_name,
                Key=response_key,
                Body=json.dumps(response_data, indent=2),
                ContentType='application/json'
            )
            
            # Upload logs to S3
            log_key = f"logs/{request_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
            s3_client.put_object(
                Bucket=bucket_name,
                Key=log_key,
                Body=json.dumps(log_data, indent=2),
                ContentType='application/json'
            )
            
            logger.info(f"Translation completed for request: {request_id}")
            
        return {
            'statusCode': 200,
            'body': json.dumps('Translation processing completed successfully')
        }
        
    except Exception as e:
        logger.error(f"Error processing translation: {str(e)}")
        
        # Upload error log
        error_data = {
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat(),
            'event': event
        }
        
        error_key = f"errors/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_error.json"
        try:
            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=error_key,
                Body=json.dumps(error_data, indent=2),
                ContentType='application/json'
            )
        except:
            pass  # Don't fail if error logging fails
        
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
