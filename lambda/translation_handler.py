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

def translate_json_recursively(data, source_lang, target_lang):
    """
    Recursively translate text values in a JSON structure
    """
    if isinstance(data, dict):
        translated_dict = {}
        for key, value in data.items():
            if isinstance(value, str) and value.strip():
                # Translate string values
                try:
                    result = translate_client.translate_text(
                        Text=value,
                        SourceLanguageCode=source_lang,
                        TargetLanguageCode=target_lang
                    )
                    translated_dict[key] = result['TranslatedText']
                except Exception as e:
                    logger.error(f"Error translating '{value}': {str(e)}")
                    translated_dict[key] = value  # Keep original if translation fails
            else:
                # Recursively handle nested structures
                translated_dict[key] = translate_json_recursively(value, source_lang, target_lang)
        return translated_dict
    elif isinstance(data, list):
        return [translate_json_recursively(item, source_lang, target_lang) for item in data]
    else:
        return data

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
            translation_type = content.get('type', 'text')
            source_language = content.get('sourceLanguage', 'en')
            target_language = content.get('targetLanguage', 'es')
            request_id = content.get('requestId', str(uuid.uuid4()))
            
            # Handle auto language detection
            if source_language == 'auto':
                source_language = 'en'  # Default to English for auto detection
            
            if translation_type == 'file':
                # Handle file translation
                file_content = content.get('fileContent', '')
                file_name = content.get('fileName', 'unknown.json')
                
                if not file_content:
                    raise ValueError("File content is empty")
                
                # Parse JSON content and translate text values
                try:
                    json_data = json.loads(file_content)
                    translated_data = translate_json_recursively(json_data, source_language, target_language)
                    
                    response_data = {
                        'requestId': request_id,
                        'type': 'file',
                        'fileName': file_name,
                        'originalContent': file_content,
                        'translatedContent': json.dumps(translated_data, ensure_ascii=False, indent=2),
                        'sourceLanguage': source_language,
                        'targetLanguage': target_language,
                        'timestamp': datetime.utcnow().isoformat(),
                        'status': 'completed'
                    }
                except json.JSONDecodeError as e:
                    raise ValueError(f"Invalid JSON content: {str(e)}")
                    
            else:
                # Handle text translation
                text_to_translate = content.get('text', '')
                
                if not text_to_translate:
                    raise ValueError("Text to translate is empty")
                
                # Perform translation using AWS Translate
                translation_result = translate_client.translate_text(
                    Text=text_to_translate,
                    SourceLanguageCode=source_language,
                    TargetLanguageCode=target_language
                )
                
                response_data = {
                    'requestId': request_id,
                    'type': 'text',
                    'originalText': text_to_translate,
                    'translatedText': translation_result['TranslatedText'],
                    'sourceLanguage': translation_result['SourceLanguageCode'],
                    'targetLanguage': translation_result['TargetLanguageCode'],
                    'timestamp': datetime.utcnow().isoformat(),
                    'status': 'completed'
                }
            
            logger.info(f"Processing translation request: {request_id}")
            logger.info(f"Source: {source_language}, Target: {target_language}")
            
            # Log the request and response
            log_data = {
                'request': content,
                'response': response_data,
                'processing_time': datetime.utcnow().isoformat()
            }
            
            # Upload response to S3 responses folder (simple naming for API handler)
            response_key = f"responses/{request_id}.json"
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
        
        # Try to extract request_id from content if available
        try:
            request_id = content.get('requestId', str(uuid.uuid4()))
        except:
            request_id = str(uuid.uuid4())
        
        # Create error response
        error_response = {
            'requestId': request_id,
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Upload error response to responses folder
        try:
            error_response_key = f"responses/{request_id}.json"
            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=error_response_key,
                Body=json.dumps(error_response, indent=2),
                ContentType='application/json'
            )
        except Exception as upload_error:
            logger.error(f"Error uploading error response: {str(upload_error)}")
        
        # Upload detailed error log
        error_data = {
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat(),
            'event': event,
            'request_id': request_id
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
