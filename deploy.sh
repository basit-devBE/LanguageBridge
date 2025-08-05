#!/bin/bash

echo "🚀 Deploying AI Translation Automation System..."

# Set error handling
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    if ! command -v zip &> /dev/null; then
        print_error "zip is not installed. Please install zip first."
        exit 1
    fi
    
    print_status "All requirements met ✓"
}

# Create Lambda deployment package
create_lambda_package() {
    print_status "📦 Creating Lambda deployment package..."
    
    cd lambda
    
    # Create a clean deployment package
    if [ -f "translation_handler.zip" ]; then
        rm translation_handler.zip
    fi
    
    zip translation_handler.zip translation_handler.py
    
    # Move to infrastructure directory
    mv translation_handler.zip ../infrastructure/
    
    cd ..
    
    print_status "Lambda package created successfully ✓"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "🏗️ Deploying infrastructure with Terraform..."
    
    cd infrastructure
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying deployment..."
    terraform apply tfplan
    
    cd ..
    
    print_status "Infrastructure deployed successfully ✓"
}

# Test the deployment
test_deployment() {
    print_status "🧪 Testing deployment..."
    
    # Get the Lambda function name from Terraform output
    cd infrastructure
    LAMBDA_FUNCTION_NAME=$(terraform output -raw lambda_function_name)
    cd ..
    
    print_status "Lambda function created: $LAMBDA_FUNCTION_NAME"
    
    # Test if Lambda function exists (specify region)
    if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --region eu-north-1 &> /dev/null; then
        print_status "Lambda function is accessible ✓"
    else
        print_error "Lambda function is not accessible"
        print_error "Trying to debug the issue..."
        
        # Show more details for debugging
        print_status "Checking AWS CLI region configuration..."
        aws configure get region || echo "No default region set"
        
        print_status "Attempting to get function details..."
        aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --region eu-north-1 || true
        
        exit 1
    fi
}

# Main deployment flow
main() {
    print_status "Starting AI Translation Automation System deployment..."
    
    check_requirements
    create_lambda_package
    deploy_infrastructure
    test_deployment
    
    print_status "✅ Deployment completed successfully!"
    print_status ""
    print_status "📋 Next steps:"
    print_status "1. Your API now has new translation endpoints:"
    print_status "   - POST /api/translate/text"
    print_status "   - POST /api/translate/file"
    print_status "   - GET /api/translate/status/:requestId"
    print_status ""
    print_status "2. Test the system:"
    print_status "   - Start your API: npm run start:dev"
    print_status "   - Test translation endpoint"
    print_status ""
    print_status "3. Monitor logs:"
    print_status "   - CloudWatch logs for Lambda function"
    print_status "   - S3 bucket for request/response files"
}

# Run main function
main "$@"
