FROM docker:dind

# Install basic development tools
RUN apk update && apk add --no-cache \
    curl \
    xz \
    tar \
    git \
    emacs-x11 \
    bash \
    python3 \
    py3-pip \
    htop \
    tmux && \
    rm -rf /var/cache/apk/*

# Install Nix (single-user installation)
RUN mkdir -m 0755 /nix && \
    chown root /nix && \
    mkdir -p /etc/nix && \
    echo 'sandbox = false' > /etc/nix/nix.conf

# Add environment setup script
COPY scripts/setup-enclave.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-enclave.sh

# Default command starts Docker daemon and shell
CMD ["sh", "-c", "dockerd > /var/log/dockerd.log 2>&1 & sleep 3 && /bin/bash"]
