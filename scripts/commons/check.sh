#!/bin/bash
# Description: Common check functions for AWS deployments
# Author: CMA Consulting
# Version: 2.0

# Load required dependencies
CHECK_SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
source "${CHECK_SCRIPT_DIR}/log.sh"
unset CHECK_SCRIPT_DIR

# Function: check_aws_cli
# Description: Check if AWS CLI is installed and available
# Parameters: None
# Returns: 0 if AWS CLI is available, 1 otherwise
function check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLI not installed or not in PATH. Install it from: https://aws.amazon.com/cli/"
    fi
    log "DEBUG" "AWS CLI found: $(aws --version)"
}

# Function: check_aws_credentials
# Description: Check if AWS credentials are properly configured
# Parameters: None
# Returns: 0 if credentials are available, 1 otherwise
function check_aws_credentials() {
    local profile="${1:-default}"
    
    log "DEBUG" "Checking AWS credentials for profile: $profile"
    
    # Check if profile exists
    if ! aws configure list --profile "$profile" &> /dev/null; then
        if [ "$profile" = "default" ]; then
            handle_error "AWS credentials not configured. Run 'aws configure' or set AWS_PROFILE environment variable"
        else
            handle_error "AWS profile '$profile' not found. Check AWS_PROFILE or run 'aws configure --profile $profile'"
        fi
    fi
    
    # Verify credentials work
    local caller_identity
    caller_identity=$(aws sts get-caller-identity --profile "$profile" 2>&1)
    
    if [ $? -ne 0 ]; then
        handle_error "Invalid AWS credentials for profile '$profile': $caller_identity"
    fi
    
    log "INFO" "AWS credentials validated for profile: $profile"
    log "DEBUG" "Caller identity: $caller_identity"
}

# Function: check_aws_region
# Description: Check if AWS region is configured
# Parameters: REGION (string)
# Returns: 0 if region is valid, 1 otherwise
function check_aws_region() {
    local region="$1"
    
    if [ -z "$region" ]; then
        handle_error "AWS region is required"
    fi
    
    # Validate region format (basic check)
    if ! echo "$region" | grep -qE '^[a-z]{2}-[a-z]+-[0-9]+$'; then
        handle_error "Invalid AWS region format: $region. Expected format: us-east-1, us-west-2, etc."
    fi
    
    log "DEBUG" "AWS region validated: $region"
}

# Function: check_bucket_exists
# Description: Check if S3 bucket exists
# Parameters: BUCKET_NAME (string), PROFILE (string, optional)
# Returns: 0 if bucket exists, 1 otherwise
function check_bucket_exists() {
    local bucket_name="$1"
    local profile="${2:-default}"
    
    log "DEBUG" "Checking if bucket exists: $bucket_name"
    
    if aws s3api head-bucket --bucket "$bucket_name" --profile "$profile" &> /dev/null; then
        log "DEBUG" "Bucket $bucket_name exists"
        return 0
    else
        log "DEBUG" "Bucket $bucket_name does not exist or no access"
        return 1
    fi
}

# Function: check_certificate_exists
# Description: Check if ACM certificate exists and is issued
# Parameters: DOMAIN_NAME (string), PROFILE (string, optional)
# Returns: 0 if certificate exists and is issued, 1 otherwise
function check_certificate_exists() {
    local domain_name="$1"
    local profile="${2:-default}"
    
    log "DEBUG" "Checking certificate for domain: $domain_name"
    
    local cert_arn
    cert_arn=$(aws acm list-certificates --region us-east-1 --profile "$profile" \
        --query "CertificateSummaryList[?DomainName=='$domain_name'].CertificateArn" \
        --output text 2>/dev/null)
    
    if [ -z "$cert_arn" ] || [ "$cert_arn" = "None" ]; then
        log "DEBUG" "No certificate found for domain: $domain_name"
        return 1
    fi
    
    # Check certificate status
    local cert_status
    cert_status=$(aws acm describe-certificate --region us-east-1 --profile "$profile" \
        --certificate-arn "$cert_arn" \
        --query "Certificate.Status" --output text 2>/dev/null)
    
    if [ "$cert_status" = "ISSUED" ]; then
        log "INFO" "Valid certificate found: $cert_arn"
        return 0
    else
        log "WARN" "Certificate found but not issued (status: $cert_status): $cert_arn"
        return 1
    fi
}