#!/bin/bash

# Function to check if a port is available
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :"$port" >/dev/null 2>&1
        return $?
    else
        # Fallback to nc if lsof is not available
        nc -z localhost "$port" >/dev/null 2>&1
        return $?
    fi
}

# Function to find an available port
find_available_port() {
    local base_port=$1
    local port=$base_port
    local max_attempts=9

    for i in $(seq 0 $max_attempts); do
        if ! check_port "$port"; then
            echo "$port"
            return 0
        fi
        port=$((base_port + i + 1))
    done
    
    echo "No available ports found between $base_port and $((base_port + max_attempts))" >&2
    exit 1
}

# Check if likely another container is running
if check_port 8501 || check_port 6080; then
    echo "⚠️  Warning: Ports 8501 or 6080 are in use. You might have another container running."
    echo "   You may want to run 'docker ps' to check and 'docker stop <container-id>' if needed."
    echo "   Continuing in 3 seconds..."
    sleep 3
fi

# Find available ports for commonly conflicting services
VNC_PORT=$(find_available_port 5900)
HTTP_PORT=$(find_available_port 8080)
STREAMLIT_PORT=8501
NOVNC_PORT=6080

echo "Using ports: VNC=$VNC_PORT, HTTP=$HTTP_PORT, STREAMLIT=$STREAMLIT_PORT, NOVNC=$NOVNC_PORT"

docker run \
    -e GITHUB_TOKEN=$GITHUB_TOKEN \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -e AWS_REGION=$AWS_REGION \
    -e PROVIDER=bedrock \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -p $VNC_PORT:5900 \
    -p $STREAMLIT_PORT:8501 \
    -p $NOVNC_PORT:6080 \
    -p $HTTP_PORT:8080 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest
