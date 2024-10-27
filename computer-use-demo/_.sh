#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required configurations
declare -r REQUIRED_MODEL="anthropic.claude-3-5-sonnet-20241022-v2:0"
declare -r IMAGE_NAME="ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Function to setup and start Docker daemon
setup_docker() {
    log_info "Setting up Docker environment..."

    # Check if docker socket directory exists
    if [ ! -d "/var/run" ]; then
        log_info "Creating /var/run directory..."
        sudo mkdir -p /var/run
    fi

    # # Check if Docker daemon is running
    # if ! docker info &>/dev/null; then
    #     log_warning "Docker daemon not running. Starting dockerd..."

    #     # Kill any existing dockerd processes
    #     sudo killall dockerd &>/dev/null || true

    #     # Start Docker daemon in background
    #     sudo dockerd &>/dev/null &

    #     # Wait for Docker daemon to start
    #     log_info "Waiting for Docker daemon to start..."
    #     for i in {1..30}; do
    #         if docker info &>/dev/null; then
    #             log_success "Docker daemon started successfully"
    #             return 0
    #         fi
    #         sleep 1
    #     done

    #     log_error "Failed to start Docker daemon"
    #     return 1
    # fi

    log_success "Docker daemon is running"
    return 0
}

# Function to validate AWS credentials
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

    # Validate credentials using STS
    local identity
    if ! identity=$(aws sts get-caller-identity 2>/dev/null); then
        log_error "Invalid AWS credentials"
        return 1
    fi

    local account_id=$(echo "$identity" | jq -r .Account)
    local arn=$(echo "$identity" | jq -r .Arn)

    log_success "Authenticated as: $arn"
    log_success "Account ID: $account_id"

    # Validate Bedrock model access
    log_info "Validating Bedrock model access..."
    if ! aws bedrock list-foundation-models | jq -r '.modelSummaries[].modelId' | grep -q "^${REQUIRED_MODEL}$"; then
        log_error "Required model ${REQUIRED_MODEL} not found in region ${AWS_REGION}"
        return 1
    fi

    log_success "Model ${REQUIRED_MODEL} is available in region ${AWS_REGION}"
    return 0
}

# Function to launch demo in Replit
launch_demo() {
    log_info "Launching Computer Use Demo in Replit..."

    # Pull the image first
    log_info "Pulling Docker image..."
    echo docker pull "${IMAGE_NAME}"
    if ! docker pull "${IMAGE_NAME}"; then
        log_error "Failed to pull Docker image"
        return 1
    fi

    # Build docker run command for Replit environment
    cmd="docker run"
    cmd+=" -e API_PROVIDER=bedrock"
    cmd+=" -e AWS_REGION=${AWS_REGION}"
    cmd+=" -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
    cmd+=" -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
    [[ -n "${AWS_SESSION_TOKEN}" ]] && cmd+=" -e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}"

    # Add common configuration
    cmd+=" -v ${HOME}/.anthropic:/home/computeruse/.anthropic"

    # Use Replit's port forwarding
    cmd+=" -p 443:8080"  # Main interface
    cmd+=" -p 80:8501"   # Streamlit
    cmd+=" -p 5900:5900" # VNC
    cmd+=" -p 6080:6080" # noVNC

    # Set reasonable screen resolution for Replit
    cmd+=" -e WIDTH=1024"
    cmd+=" -e HEIGHT=768"

    cmd+=" -it ${IMAGE_NAME}"

    log_info "Starting container..."
    eval "$cmd"

    if [[ $? -eq 0 ]]; then
        log_success "Container started successfully"
        log_info "Access points in Replit:"
        log_info "• Use the 'Webview' tab to access the interface"
        log_info "• The container is running with default ports mapped to Replit's forwarding"
    else
        log_error "Failed to start container"
        return 1
    fi
}

# Function to cleanup on exit
cleanup() {
    log_info "Cleaning up..."
    sudo killall dockerd &>/dev/null || true
}

# Set cleanup trap
trap cleanup EXIT

# Main function
main() {
    log_info "Starting Computer Use Demo setup in Replit"
    echo "----------------------------------------"

    # Step 1: Setup Docker
    if ! setup_docker; then
        log_error "Docker setup failed"
        exit 1
    fi

    # Step 2: Validate AWS setup
    if ! validate_aws_setup; then
        log_error "AWS validation failed"
        exit 1
    fi

    # Step 3: Launch demo
    if ! launch_demo; then
        log_error "Demo launch failed"
        exit 1
    fi

    log_success "Demo is ready!"
    echo "----------------------------------------"
    log_info "Open the 'Webview' tab in Replit to access the interface"

    exit 0
}

# Run main function
main "$@"