FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https

# Add Docker's official GPG key
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine, CLI, and containerd
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io

# Install emacs (optional)
RUN apt-get install -y emacs

# Fix potential ulimit issue in Docker service script (try both locations)
# RUN sed -i -e 's#ulimit -Hn 65536#ulimit -n 524288#' /lib/systemd/system/docker.service 
# RUN sed -i -e 's#ulimit -Hn 65536#ulimit -n 524288#' /etc/init.d/docker

# Start the Docker service manually and keep the terminal open
# RUN service docker start && /bin/bash
RUN /bin/bash

