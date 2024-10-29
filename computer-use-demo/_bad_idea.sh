#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fun mount points
FUN_HOME_NAMES=(
    "batcave"
    "secret_lair"
    "fortress_of_solitude"
    "quantum_realm"
    "magical_kingdom"
    "cyber_citadel"
    "neural_nexus"
    "binary_basement"
)

# Logging functions
log_info() { echo -e "${NC}[INFO] $1"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Function to find an available port
find_available_port() {
    local start_port=$1
    local end_port=${2:-65535}
    local port=$start_port
    while netstat -an | grep "[:.]$port " > /dev/null 2>&1 && [ "$port" -le "$end_port" ]; do
        port=$((port + 1))
    done
    if [ "$port" -gt "$end_port" ]; then
        echo ""
    else
        echo "$port"
    fi
}

# Function to get a random fun name
get_fun_home_name() {
    local index=$((RANDOM % ${#FUN_HOME_NAMES[@]}))
    echo "${FUN_HOME_NAMES[$index]}"
}

# Function to generate SSH key pair
generate_ssh_key() {
    local key_dir="$1"
    if [[ ! -d "$key_dir" ]]; then
        mkdir -p "$key_dir"
        ssh-keygen -t ed25519 -C "computeruse key" -f "$key_dir/id_ed25519" -q -N ""
        log_success "Generated SSH key pair for computeruse in $key_dir"
    else
        log_info "SSH key directory for computeruse already exists: $key_dir"
    fi
}

# Function to generate GPG key pair
generate_gpg_key() {
    local key_dir="$1"
    if [[ ! -d "$key_dir" ]]; then
        mkdir -p "$key_dir"
        gpg --batch --full-generate-key <<EOF
%echo Generating a basic OpenPGP key
Key-Type: ed25519
Key-Usage: sign,encrypt,auth
Name-Real: computeruse
Name-Email: computeruse@defrecord.com
Expire-Date: 0
Passphrase: 
%commit
EOF
        log_success "Generated GPG key pair for computeruse in $key_dir"
    else
        log_info "GPG key directory for computeruse already exists: $key_dir"
    fi
}

# Function to check and start XQuartz
ensure_xquartz_running() {
    if ! pgrep -x "Xquartz" > /dev/null; then
        log_info "Starting XQuartz..."
        open -a XQuartz
        
        # Start xeyes as a visual indicator
        log_info "Launching xeyes while waiting for XQuartz..."
        (xeyes &)
        XEYES_PID=$!
        
        # Wait for XQuartz to be ready
        local retries=0
        while ! xset -q > /dev/null 2>&1; do
            sleep 1
            ((retries++))
            if [ "$retries" -ge 30 ]; then
                log_error "XQuartz failed to start properly"
                kill $XEYES_PID 2>/dev/null
                return 1
            fi
        done
        
        # Kill xeyes once XQuartz is ready
        kill $XEYES_PID 2>/dev/null
        log_success "XQuartz is ready"
    else
        log_success "XQuartz is already running"
    fi
    return 0
}


# Function to setup Emacs server
setup_emacs_server() {
    local emacs_port=$(find_available_port 12345 12445)
    if [ -z "$emacs_port" ]; then
        log_error "Could not find available port for Emacs server"
        return 1
    fi
    
    local server_name="computeruse-${emacs_port}"
    log_info "Setting up Emacs server on port $emacs_port"
    
    if emacsclient -s computeruse -e '(server-running-p)' > /dev/null 2>&1; then
        log_warning "Existing Emacs server found, shutting down..."
        emacsclient -s computeruse -e '(kill-emacs)' >/dev/null 2>&1
    fi
    
    DISPLAY=:0 emacs --daemon \
        --server-file="$HOME/.emacs.d/server/$server_name" \
        --server-use-tcp \
        --server-host="localhost" \
        --server-port="$emacs_port" &
        
    local retries=0
    while ! emacsclient -s "$server_name" -e '(server-running-p)' > /dev/null 2>&1; do
        sleep 1
        ((retries++))
        if [ "$retries" -ge 10 ]; then
            log_error "Failed to start Emacs server"
            return 1
        fi
    done
    
    log_success "Emacs server started on port $emacs_port"
    echo "$server_name:$emacs_port"
}

# --- Main script ---
mkdir -p output

FUN_HOME=$(get_fun_home_name)
log_info "Today your home directory will be known as: 🏠 /${FUN_HOME}"

computeruse_ssh_dir="$HOME/.ssh/computeruse"
generate_ssh_key "$computeruse_ssh_dir"

computeruse_gpg_dir="$HOME/.gnupg/computeruse"
generate_gpg_key "$computeruse_gpg_dir"

# Replace your existing XQuartz check with:
ensure_xquartz_running || exit 1

xset -q > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    log_success "Display is available"
else
    log_error "Display is not available. Please check XQuartz."
    exit 1
fi

EMACS_SETUP=$(setup_emacs_server)
if [ $? -ne 0 ]; then
    log_error "Failed to setup Emacs server"
    exit 1
fi

EMACS_SERVER_NAME=$(echo "$EMACS_SETUP" | cut -d: -f1)
EMACS_PORT=$(echo "$EMACS_SETUP" | cut -d: -f2)

log_info "Verifying Emacs configuration:"
log_info "Server Name: ${EMACS_SERVER_NAME}"
log_info "Port: ${EMACS_PORT}"

echo "--------------------------------------------------------------------"
docker run \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
    -v "${HOME}:/home/computeruse/${FUN_HOME}" \
    -v "${HOME}/.anthropic:/home/computeruse/.anthropic" \
    -v "${HOME}/computer-use-sandbox:/home/computeruse/sandbox" \
    -v "${PWD}/output:/tmp/output" \
    -e AWS_PROFILE="${AWS_PROFILE}" \
    -e AWS_REGION="${AWS_REGION}" \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -v "${HOME}/.Xauthority:/home/computeruse/.Xauthority" \
    -v "${HOME}/.ssh/computeruse:/home/computeruse/.ssh" \
    -v "${HOME}/.gnupg/computeruse:/home/computeruse/.gnupg" \
    -v "${HOME}/.emacs.d/server:/home/computeruse/.emacs.d/server" \
    -v "${HOME}/.emacs.d/server/${EMACS_SERVER_NAME}:/home/computeruse/.emacs.d/server/${EMACS_SERVER_NAME}" \
    -p "${EMACS_PORT}:${EMACS_PORT}" \
    -p 5900:5900 \
    -p 8501:8501 \
    -p 6080:6080 \
    -p 8080:8080 \
    -e WIDTH=1920 \
    -e HEIGHT=1080 \
    -e HOME_MOUNT="/${FUN_HOME}" \
    -e EMACS_SERVER_NAME="${EMACS_SERVER_NAME}" \
    -e EMACS_PORT="${EMACS_PORT}" \
    -e DISPLAY=:0 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest

# Cleanup function
cleanup() {
    log_info "Cleaning up the ${FUN_HOME}..."
    if [ -n "$EMACS_SERVER_NAME" ]; then
        emacsclient -s "$EMACS_SERVER_NAME" -e '(kill-emacs)' >/dev/null 2>&1
    fi
}

trap cleanup EXIT
