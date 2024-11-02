.PHONY: help build-enclave build-computer-use-demo build-all run-computer-use-demo run-enclave

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build-enclave: ## Build Enclave image
	docker build -t enclave -f dockerfiles/enclave.Dockerfile .

build-computer-use-demo: ## Build ComputerUse image locally
	docker build -t computer-use-demo:local -f Dockerfile .

build-all: build-enclave build-computer-use-demo ## Build all images

run-computer-use-demo: ## Run ComputerUse directly on host
	docker run \
		-e ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY) \
		-v $(HOME)/.anthropic:/home/computeruse/.anthropic \
		-p 5900:5900 \
		-p 8501:8501 \
		-p 6080:6080 \
		-p 8080:8080 \
		-it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest

run-enclave: ## Run Enclave as DinD container with Docker daemon
	docker run -it --privileged \
		-v $(HOME)/.anthropic:/root/.anthropic \
		-p 8080:8080 -p 8501:8501 -p 5900:5900 -p 6080:6080 \
		docker:dind sh -c 'dockerd > /var/log/dockerd.log 2>&1 & sleep 3 && /bin/sh'

# Once inside Enclave, run ComputerUse with:
# docker run -it \
#     -v /root/.anthropic:/home/computeruse/.anthropic \
#     --network host \
#     ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest

run-enclave-local: ## Run local Enclave container for testing
	docker run -it --entrypoint /bin/bash enclave

# TODO: Move these configurations into Dockerfiles
# 1. Create proper Enclave Dockerfile with:
#    - Development tools (git, curl, wget, etc.)
#    - Nix package manager
#    - Docker daemon configuration
#
# 2. Create production ComputerUse Dockerfile with:
#    - Proper user permissions
#    - Environment setup
#    - Healthchecks
#
# 3. Create docker-compose.yml for local development with:
#    - Enclave service
#    - ComputerUse service
#    - Volume mounts
#    - Network configuration

run-ubuntu: ## Run Ubuntu for testing
	docker run -it ubuntu:latest /bin/bash

run-ubuntu-nested: ## Run Ubuntu in nested Docker environment
	docker run -it --privileged \
		-v $(HOME)/.anthropic:/root/.anthropic \
		-p 8080:8080 -p 8501:8501 -p 5900:5900 -p 6080:6080 \
		docker:dind sh -c 'dockerd > /var/log/dockerd.log 2>&1 & sleep 3 && \
			docker run -it \
				-v /root/.anthropic:/home/computeruse/.anthropic \
				--network host \
				ubuntu:latest'
