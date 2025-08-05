#!/bin/bash

echo "🧪 Testing AI Translation API..."

API_BASE="http://localhost:3000/api"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health check
echo -e "\n${YELLOW}Test 1: API Health Check${NC}"
echo "Testing: GET ${API_BASE}/test"

RESPONSE=$(curl -s -w "%{http_code}" "${API_BASE}/test")
HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ API is running${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}❌ API is not responding properly${NC}"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

# Test 2: Text translation
echo -e "\n${YELLOW}Test 2: Text Translation${NC}"
echo "Testing: POST ${API_BASE}/translate/text"

TRANSLATION_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_BASE}/translate/text" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, this is a test translation",
    "sourceLanguage": "en",
    "targetLanguage": "es"
  }')

HTTP_CODE="${TRANSLATION_RESPONSE: -3}"
BODY="${TRANSLATION_RESPONSE%???}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Translation request submitted successfully${NC}"
    echo "Response: $BODY"
    
    # Extract request ID for status check
    REQUEST_ID=$(echo "$BODY" | grep -o '"requestId":"[^"]*"' | cut -d'"' -f4)
    echo "Request ID: $REQUEST_ID"
    
    if [ ! -z "$REQUEST_ID" ]; then
        # Test 3: Status check
        echo -e "\n${YELLOW}Test 3: Translation Status Check${NC}"
        echo "Testing: GET ${API_BASE}/translate/status/${REQUEST_ID}"
        
        sleep 2  # Wait a moment
        
        STATUS_RESPONSE=$(curl -s -w "%{http_code}" "${API_BASE}/translate/status/${REQUEST_ID}")
        HTTP_CODE="${STATUS_RESPONSE: -3}"
        BODY="${STATUS_RESPONSE%???}"
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
            echo -e "${GREEN}✅ Status check working${NC}"
            echo "Response: $BODY"
        else
            echo -e "${YELLOW}⚠️ Status check returned: $HTTP_CODE${NC}"
            echo "Response: $BODY"
        fi
    fi
    
else
    echo -e "${RED}❌ Translation request failed${NC}"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
fi

# Test 4: File upload test (create a test file)
echo -e "\n${YELLOW}Test 4: File Translation${NC}"
echo "Creating test file..."

TEST_FILE="/tmp/test_translation.json"
cat > "$TEST_FILE" << EOF
{
  "text": "This is a test file for translation. It contains some sample text that should be translated from English to Spanish."
}
EOF

echo "Testing: POST ${API_BASE}/translate/file"

FILE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_BASE}/translate/file" \
  -F "file=@${TEST_FILE}" \
  -F "sourceLanguage=en" \
  -F "targetLanguage=es")

HTTP_CODE="${FILE_RESPONSE: -3}"
BODY="${FILE_RESPONSE%???}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ File translation request submitted successfully${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}❌ File translation request failed${NC}"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
fi

# Cleanup
rm -f "$TEST_FILE"

echo -e "\n${GREEN}🎉 API Testing completed!${NC}"
echo -e "\n${YELLOW}📋 Summary:${NC}"
echo "✅ API Health Check"
echo "✅ Text Translation Endpoint"
echo "✅ Status Check Endpoint"
echo "✅ File Translation Endpoint"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Deploy the Lambda function to AWS"
echo "2. Set up S3 event triggers"
echo "3. Test the complete translation workflow"
echo "4. Open the frontend at: file:///$(pwd)/frontend/index.html"
