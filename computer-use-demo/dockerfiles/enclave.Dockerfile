FROM docker:dind

# Install comprehensive development toolset
RUN apk update && apk add --no-cache \
    # Editors and Shell
    emacs-x11 \
    vim \
    tmux \
    bash \
    bash-completion \
    
    # Core Utils
    curl \
    wget \
    git \
    htop \
    tree \
    ripgrep \
    fd \
    fzf \
    bat \
    exa \
    
    # Development Tools
    python3 \
    py3-pip \
    nodejs \
    npm \
    make \
    gcc \
    musl-dev \
    
    # Data Processing
    jq \
    yq \
    httpie \
    
    # Network Tools
    bind-tools \
    openssh-client \
    docker-compose \
    
    # Clean up
    && rm -rf /var/cache/apk/*

# Rest of Dockerfile remains the same...
