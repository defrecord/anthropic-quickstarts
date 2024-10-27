#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required configurations
declare -r REQUIRED_MODEL="anthropic.claude-3-5-sonnet-20241022-v2:0"
declare -r REQUIRED_REGION="us-west-2"
declare -r REQUIRED_PYTHON_VERSION="3.12"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to verify required tools
verify_tools() {
    log_info "Verifying required tools..."
    local required_tools=("aws" "jq" "cargo" "python3")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
            log_error "Missing required tool: $tool"
        else
            case "$tool" in
                "aws")
                    local version
                    version=$(aws --version 2>&1)
                    log_success "Found AWS CLI: $version"
                    ;;
                "python3")
                    local version
                    version=$(python3 --version 2>&1)
                    log_success "Found Python: $version"
                    ;;
                "cargo")
                    local version
                    version=$(cargo --version 2>&1)
                    log_success "Found Cargo: $version"
                    ;;
                "jq")
                    local version
                    version=$(jq --version 2>&1)
                    log_success "Found jq: $version"
                    ;;
            esac
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please ensure these are added to replit.nix"
        return 1
    fi
    return 0
}

# Function to validate AWS credentials and Bedrock access
validate_aws_setup() {
    log_info "Validating AWS credentials..."

    # Check required environment variables
    local required_vars=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please add these to your Replit Secrets"
        return 1
    fi

    # Validate AWS credentials
    local identity
    identity=$(aws sts get-caller-identity 2>/dev/null) || {
        log_error "Failed to validate AWS credentials"
        return 1
    }

    local account_id=$(echo "$identity" | jq -r .Account)
    local arn=$(echo "$identity" | jq -r .Arn)

    log_success "Authenticated as: $arn"
    log_success "Account ID: $account_id"

    # Validate Bedrock access
    log_info "Validating Bedrock model access..."

    if ! aws bedrock list-foundation-models &>/dev/null; then
        log_error "Cannot access AWS Bedrock service"
        return 1
    fi

    if ! aws bedrock list-foundation-models | jq -r '.modelSummaries[].modelId' | grep -q "^${REQUIRED_MODEL}$"; then
        log_error "Required model ${REQUIRED_MODEL} not found in region ${AWS_REGION}"
        log_info "Available Claude models:"
        aws bedrock list-foundation-models | \
            jq -r '.modelSummaries[] | select(.modelId | contains("claude")) | .modelId'
        return 1
    fi

    log_success "Model ${REQUIRED_MODEL} is available in region ${AWS_REGION}"
    return 0
}

# Function to setup Python environment
setup_python_env() {
    log_info "Setting up Python environment..."

    # Create .pythonlibs directory if it doesn't exist
    mkdir -p .pythonlibs

    # Install Python dependencies
    log_info "Installing Python dependencies..."
    pip install --user -r dev-requirements.txt || {
        log_error "Failed to install Python dependencies"
        return 1
    }

    # Install and setup pre-commit
    if ! command_exists pre-commit; then
        log_info "Installing pre-commit..."
        pip install --user pre-commit
    fi

    pre-commit install || {
        log_error "Failed to install pre-commit hooks"
        return 1
    }

    log_success "Python environment setup complete"
    return 0
}

# Main setup function
main() {
    log_info "Starting Computer Use Demo Setup"
    echo "----------------------------------------"

    # Step 1: Verify required tools
    log_info "Step 1/3: Verifying tools"
    if ! verify_tools; then
        log_error "Required tools verification failed"
        return 1
    fi

    # Step 2: Validate AWS and Bedrock setup
    log_info "Step 2/3: Validating AWS setup"
    if ! validate_aws_setup; then
        log_error "AWS validation failed"
        return 1
    fi

    # Step 3: Setup Python environment
    log_info "Step 3/3: Setting up Python environment"
    if ! setup_python_env; then
        log_error "Python setup failed"
        return 1
    fi

    echo "----------------------------------------"
    log_success "Setup completed successfully!"
    log_info "You can now run the computer use demo"
    return 0
}

# Run main function
main "$@"
exit $?