.PHONY: help build-enclave build-computer-use-demo build-all run-computer-use-demo run-enclave

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build-enclave: ## Enclave
	docker build -t enclave -f dockerfiles/enclave.Dockerfile .

build-computer-use-demo: ## ComputerUse
	docker build -t computer-use-demo:local -f Dockerfile .

build-all: build-enclave build-computer-use-demo ## Build all images

run-computer-use-demo: ## Run ComputerUse directly on host
	docker run \
		-e ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY) \
		-v $$HOME/.anthropic:/home/computeruse/.anthropic \
		-p 5900:5900 \
		-p 8501:8501 \
		-p 6080:6080 \
		-p 8080:8080 \
		-it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest

run-enclave: ## Run Enclave container for testing
	docker run -it --entrypoint /bin/bash enclave
