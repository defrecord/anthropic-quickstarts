# Start Enclave

# for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done

# Validation 
docker run -it --net=host \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    ubuntu:22.04 \
    docker run -it \
        -v /home/computeruse/.anthropic:/home/computeruse/.anthropic \
	-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
        -p 8080:8080 -p 8501:8501 -p 5900:5900 -p 6080:6080 \
        ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest

# Baseline 
docker run \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -p 5900:5900 \
    -p 8501:8501 \
    -p 6080:6080 \
    -p 8080:8080 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest
