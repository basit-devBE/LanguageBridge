import json
import boto3
import uuid
import time
import os
from typing import Dict, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
translate_client = boto3.client('translate')

# Environment variables
BUCKET_NAME = os.environ.get('S3_BUCKET', 'ai-and-automation')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for API Gateway requests
    """
    try:
        # Log the incoming event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract HTTP method and path
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        # Route the request based on path and method
        if path == '/translate/text' and http_method == 'POST':
            return handle_text_translation(event)
        elif path == '/translate/file' and http_method == 'POST':
            return handle_file_translation(event)
        elif path.startswith('/translate/status/') and http_method == 'GET':
            request_id = path.split('/')[-1]
            return handle_status_check(request_id)
        else:
            return create_response(404, {'error': 'Not Found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal Server Error'})

def handle_text_translation(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle text translation requests
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        text = body.get('text', '')
        source_language = body.get('sourceLanguage', 'en')  # Default to 'en' instead of 'auto'
        target_language = body.get('targetLanguage', 'es')  # Default to 'es'
        
        if not text:
            return create_response(400, {'error': 'Text is required'})
        
        if not target_language:
            return create_response(400, {'error': 'Target language is required'})
        
        # Generate unique request ID
        request_id = str(uuid.uuid4())
        
        # Create translation request
        translation_request = {
            'requestId': request_id,
            'type': 'text',
            'text': text,
            'sourceLanguage': source_language,
            'targetLanguage': target_language,
            'timestamp': int(time.time())
        }
        
        # Upload request to S3
        request_key = f"requests/{request_id}.json"
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=request_key,
            Body=json.dumps(translation_request),
            ContentType='application/json'
        )
        
        # Wait for translation result (up to 30 seconds)
        max_wait_time = 30
        start_time = time.time()
        
        while time.time() - start_time < max_wait_time:
            try:
                response_key = f"responses/{request_id}.json"
                response = s3_client.get_object(Bucket=BUCKET_NAME, Key=response_key)
                result = json.loads(response['Body'].read().decode('utf-8'))
                
                if result.get('status') == 'completed':
                    return create_response(200, {
                        'requestId': request_id,
                        'translatedText': result.get('translatedText'),
                        'sourceLanguage': result.get('sourceLanguage'),
                        'targetLanguage': result.get('targetLanguage'),
                        'status': 'completed'
                    })
                elif result.get('status') == 'error':
                    return create_response(500, {
                        'requestId': request_id,
                        'error': result.get('error'),
                        'status': 'error'
                    })
                    
            except s3_client.exceptions.NoSuchKey:
                # Result not ready yet, continue waiting
                pass
            
            time.sleep(1)
        
        # If we reach here, translation is taking longer than expected
        return create_response(202, {
            'requestId': request_id,
            'status': 'processing',
            'message': 'Translation is being processed. Check status using the request ID.'
        })
        
    except Exception as e:
        logger.error(f"Error in handle_text_translation: {str(e)}")
        return create_response(500, {'error': 'Failed to process text translation'})

def handle_file_translation(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle file translation requests
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        file_content = body.get('fileContent', '')
        file_name = body.get('fileName', 'unknown.json')
        source_language = body.get('sourceLanguage', 'en')  # Default to 'en' instead of 'auto'
        target_language = body.get('targetLanguage', 'es')  # Default to 'es'
        
        if not file_content:
            return create_response(400, {'error': 'File content is required'})
        
        if not target_language:
            return create_response(400, {'error': 'Target language is required'})
        
        # Generate unique request ID
        request_id = str(uuid.uuid4())
        
        # Create translation request
        translation_request = {
            'requestId': request_id,
            'type': 'file',
            'fileContent': file_content,
            'fileName': file_name,
            'sourceLanguage': source_language,
            'targetLanguage': target_language,
            'timestamp': int(time.time())
        }
        
        # Upload request to S3
        request_key = f"requests/{request_id}.json"
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=request_key,
            Body=json.dumps(translation_request),
            ContentType='application/json'
        )
        
        # Wait for translation result (up to 45 seconds for files)
        max_wait_time = 45
        start_time = time.time()
        
        while time.time() - start_time < max_wait_time:
            try:
                response_key = f"responses/{request_id}.json"
                response = s3_client.get_object(Bucket=BUCKET_NAME, Key=response_key)
                result = json.loads(response['Body'].read().decode('utf-8'))
                
                if result.get('status') == 'completed':
                    return create_response(200, {
                        'requestId': request_id,
                        'translatedContent': result.get('translatedContent'),
                        'fileName': result.get('fileName'),
                        'sourceLanguage': result.get('sourceLanguage'),
                        'targetLanguage': result.get('targetLanguage'),
                        'status': 'completed'
                    })
                elif result.get('status') == 'error':
                    return create_response(500, {
                        'requestId': request_id,
                        'error': result.get('error'),
                        'status': 'error'
                    })
                    
            except s3_client.exceptions.NoSuchKey:
                # Result not ready yet, continue waiting
                pass
            
            time.sleep(2)
        
        # If we reach here, translation is taking longer than expected
        return create_response(202, {
            'requestId': request_id,
            'status': 'processing',
            'message': 'File translation is being processed. Check status using the request ID.'
        })
        
    except Exception as e:
        logger.error(f"Error in handle_file_translation: {str(e)}")
        return create_response(500, {'error': 'Failed to process file translation'})

def handle_status_check(request_id: str) -> Dict[str, Any]:
    """
    Handle status check requests
    """
    try:
        if not request_id:
            return create_response(400, {'error': 'Request ID is required'})
        
        # Check if response exists in S3
        response_key = f"responses/{request_id}.json"
        
        try:
            response = s3_client.get_object(Bucket=BUCKET_NAME, Key=response_key)
            result = json.loads(response['Body'].read().decode('utf-8'))
            
            if result.get('status') == 'completed':
                return create_response(200, {
                    'requestId': request_id,
                    'status': 'completed',
                    'result': result
                })
            elif result.get('status') == 'error':
                return create_response(200, {
                    'requestId': request_id,
                    'status': 'error',
                    'error': result.get('error')
                })
            else:
                return create_response(200, {
                    'requestId': request_id,
                    'status': 'processing'
                })
                
        except s3_client.exceptions.NoSuchKey:
            # Check if request exists
            request_key = f"requests/{request_id}.json"
            try:
                s3_client.get_object(Bucket=BUCKET_NAME, Key=request_key)
                return create_response(200, {
                    'requestId': request_id,
                    'status': 'processing'
                })
            except s3_client.exceptions.NoSuchKey:
                return create_response(404, {
                    'requestId': request_id,
                    'status': 'not_found',
                    'error': 'Request ID not found'
                })
        
    except Exception as e:
        logger.error(f"Error in handle_status_check: {str(e)}")
        return create_response(500, {'error': 'Failed to check status'})

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create a standardized API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
        },
        'body': json.dumps(body)
    }
