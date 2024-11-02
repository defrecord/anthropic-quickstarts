# Enclave POC Debugging and Validation - Detailed History

This document provides a comprehensive history of the debugging process and validation steps for the Enclave Proof-of-Concept (POC) using Docker.

## Project Goal

The goal of this POC is to demonstrate the feasibility of using an Enclave environment to run Docker containers in a nested setup. This involves creating a container (the Enclave) that has Docker itself installed inside it, and then running another Docker container (the application) within this Enclave.

## Project Setup

* The project utilizes Docker for containerization and involves building two main images:
    * `enclave`: A special environment with Docker itself installed inside, allowing for isolated builds.
    * `computer-use-demo:local`: The main application image.

* The project follows this directory structure:

```
computer-use-demo/
├── Dockerfile  (symlink to dockerfiles/computer-use-demo.Dockerfile)
├── Makefile
├── dockerfiles
│   └── enclave.Dockerfile  
└── ... other project files ... 
```

* A `Makefile` is used to automate the build process.

## Initial Approach: Building Enclave with Ubuntu Base Image

* We started by creating a `Dockerfile` for the Enclave environment based on the `ubuntu:22.04` image. This involved installing essential packages, adding the Docker repository, and installing the Docker Engine, CLI, and containerd within the container.

* We encountered several challenges during this process:
    * **Docker daemon not starting:** The Docker daemon failed to start within the Enclave container due to issues with the `ulimit` settings in the Docker service script.
    * **`systemctl` incompatibility:** We couldn't use `systemctl` commands to manage the Docker service because the container's init system was not `systemd`.

* To address these issues, we manually modified the `ulimit` settings and started the Docker service using the `service docker start` command.

## Change in Direction: Using docker:dind Image

* Due to the challenges faced with the Ubuntu base image, we decided to switch to the `docker:dind` (Docker in Docker) image. This image is specifically designed for running Docker within a Docker container and eliminates the need for manually installing and configuring Docker.

* We updated the `enclave.Dockerfile` to use the `docker:dind` image and removed the steps related to Docker installation and `ulimit` configuration.

## Testing and Validation

### Building and Running the Enclave Container

* We built the Enclave image using the following command:

```bash
make build-enclave
```

* We ran the Enclave container using the following command:

```bash
docker run -it --net=host --privileged -it \
    -v $HOME/.anthropic:/root/.anthropic \
    -p 8080:8080 -p 8501:8501 -p 5900:5900 -p 6080:6080 \
    docker:dind \
    docker run -it \
        -v /root/.anthropic:/home/computeruse/.anthropic \
        -p 8080:8080 -p 8501:8501 -p 5900:5900 -p 6080:6080 \
        ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest
```

### Verifying Docker Installation and Functionality

* We verified that the Docker daemon was running correctly within the Enclave container using the following command:

```bash
docker version
```

* We then ran a simple container using the `hello-world` image to further confirm the Docker installation:

```bash
docker run hello-world
```

### Testing File Synchronization

* We tested the file synchronization between the host machine and the Enclave container by creating and modifying files in the mounted directory (`$HOME/.anthropic` on the host and `/root/.anthropic` in the container). We used commands like `touch`, `echo`, and `ls` to verify the changes were reflected on both sides.

    ```bash
    # On the host machine:
    echo "This is a test file from the host" > ~/.anthropic/test-host.txt

    # Within the Enclave container:
    echo "This is a test file from the Enclave" > /root/.anthropic/test-enclave.txt
    ```

### Running and Testing the Application

* We ran the `computer-use-demo-latest` image within the Enclave container using the nested `docker run` command shown earlier.

* We accessed the application running within the container from the host machine to confirm it was working as expected.

* We also tested file synchronization between the Enclave container and the `computer-use-demo-latest` container by creating and modifying files in the mounted directory (`/root/.anthropic` in the Enclave container and `/home/computeruse/.anthropic` in the application container).

    ```bash
    # Within the Enclave container:
    docker exec -it <computer-use-demo-container-id> /bin/bash
    echo "This is a test file from the computer-use-demo container" > /home/computeruse/.anthropic/test-computer-use.txt
    ```

* We used `curl` and `wget` to test the application's functionality within the `computer-use-demo-latest` container:

    ```bash
    curl http://localhost:8080
    # Or use 'wget' if 'curl' is not available:
    wget http://localhost:8080
    ```

## Challenges and Solutions

Throughout the process, we encountered several challenges and implemented solutions to address them:

* **Docker daemon not running:** We resolved this by modifying the `enclave.Dockerfile` to keep the terminal session open and ensure the Docker daemon was running in the background.

* **`ulimit` errors:** We addressed this by manually correcting the `ulimit` settings in the Docker service script. We also added a `sed` command to the `enclave.Dockerfile` to automate this correction in future builds.

* **`systemctl` incompatibility:** We removed `systemctl` commands from our scripts and used the `service` command instead, as `systemd` was not the init system within the container.

* **Docker connectivity issues:** We encountered issues with the Docker client in the nested container not being able to connect to the Docker daemon. We resolved this by using the `--net=host` flag to allow the client to connect through the host's Docker socket.

## More Problems

* **False Positives:** We sometimes mistakenly thought that the Docker daemon was running correctly within the Enclave container when it wasn't. This led to some confusion and backtracking in the debugging process.

* **Changing Approaches:** We initially tried to build the Enclave environment using a base Ubuntu image and manually install Docker. However, we faced challenges with this approach and eventually switched to using the `docker:dind` image, which simplified the process.

* **Reverting to Simpler Commands:** In some cases, we had to revert to simpler `docker run` commands or adjust parameters like file locations to isolate and debug specific issues.

* **Makefile Errors:** We encountered minor errors in the Makefile, such as using `$$HOME` instead of `$HOME`, which required correction.

## Conclusion

This detailed history provides a comprehensive overview of the steps taken, challenges faced, and solutions implemented during the Enclave POC debugging and validation process. It serves as a valuable record for future reference and can help guide further development and testing efforts. The "More Problems" section highlights some of the pitfalls and detours encountered during the process, providing further insights into the debugging workflow.

# Enclave POC Debugging and Validation - Status

```json
{
  "timestamp": "2024-11-02T17:45:30.205319Z",
  "key_achievements": [
    "Created a Makefile to orchestrate building and running Docker images.",
    "Successfully built an Enclave image using the `docker:dind` base image.",
    "Resolved a 'ulimit' error that prevented the Docker daemon from starting within the Enclave container.",
    "Verified file synchronization between the host machine and the Enclave container.",
    "Ran the `computer-use-demo-latest` application image within the nested container environment.",
    "Accessed the `computer-use-demo-latest` application from the host machine."
  ],
  "unresolved_tasks": [
    {
      "description": "Finalize the 'ulimit' correction in the 'enclave.Dockerfile' to automate the fix.",
      "priority": 2,
      "dependencies": [],
      "estimated_effort": "small"
    },
    {
      "description": "Thoroughly test file synchronization between the host, the Enclave container, and the 'computer-use-demo-latest' container.",
      "priority": 2,
      "dependencies": [],
      "estimated_effort": "medium"
    },
    {
      "description": "Test the functionality of the 'computer-use-demo-latest' application within the nested container environment.",
      "priority": 1,
      "dependencies": [],
      "estimated_effort": "medium"
    },
    {
      "description": "Refine the Enclave environment and Dockerfiles based on the testing results.",
      "priority": 3,
      "dependencies": [
        "Thoroughly test file synchronization between the host, the Enclave container, and the 'computer-use-demo-latest' container.",
        "Test the functionality of the 'computer-use-demo-latest' application within the nested container environment."
      ],
      "estimated_effort": "medium"
    },
    {
      "description": "Document the Enclave POC setup, testing process, and results in a comprehensive Markdown file.",
      "priority": 4,
      "dependencies": [
        "Finalize the 'ulimit' correction in the 'enclave.Dockerfile' to automate the fix.",
        "Thoroughly test file synchronization between the host, the Enclave container, and the 'computer-use-demo-latest' container.",
        "Test the functionality of the 'computer-use-demo-latest' application within the nested container environment.",
        "Refine the Enclave environment and Dockerfiles based on the testing results."
      ],
      "estimated_effort": "medium"
    }
  ],
  "status_report": "Successfully set up a nested Docker environment and ran the application within it; further testing and refinement are needed.",
  "technical_domain": [
    "Docker",
    "Containerization",
    "Linux",
    "Shell Scripting",
    "Debugging"
  ],
  "primary_focus": "Docker"
}
```


# Enclave POC Debugging and Validation - Detailed Timeline

This document provides a comprehensive timeline of the debugging process and validation steps for the Enclave Proof-of-Concept (POC) using Docker.

**Date:** 2024-11-02

**Time:** All times are approximate and in Eastern Time (ET).

**10:23 AM:**

* Begin exploring the `computer-use-demo` project directory.
* Check the Docker version on the host machine.
* Start working on setting up the Enclave environment.

**10:38 AM:**

* Examine the `Dockerfile` for the `computer-use-demo` image.
* Discuss the structure of the project directory and decide to create a separate directory (`dockerfiles`) to store Dockerfiles.

**10:50 AM:**

* Create a `Makefile` to automate the build process.
* Add targets to the `Makefile` for building the Enclave and `computer-use-demo` images.
* Encounter an error related to `ulimit` while building the Enclave image.
* Manually fix the `ulimit` issue by editing the Docker service script.

**10:59 AM:**

* Successfully build the Enclave image.
* Run the Enclave container and attempt to execute commands within it.

**11:09 AM:**

* Refine the `Makefile` to include targets for running the `computer-use-demo` image directly on the host and within the Enclave container.

**11:23 AM:**

* Create a symbolic link from the `Dockerfile` in the project root to the `computer-use-demo.Dockerfile` in the `dockerfiles` directory.

**11:32 AM:**

* Continue debugging the Enclave environment.
* Encounter issues with the Docker daemon not running correctly within the container.
* Modify the `enclave.Dockerfile` to keep the terminal session open and ensure the Docker daemon runs in the background.

**12:55 PM:**

* Successfully run the Enclave container and verify that the Docker daemon is running.
* Attempt to run the `computer-use-demo` image within the Enclave container.
* Encounter issues with `curl` and other commands not being found within the container.
* Manually install `curl` and other necessary tools within the container.

**1:03 PM:**

* Test file synchronization between the host machine and the Enclave container by creating and modifying files in the mounted directory.
* Successfully confirm that file changes are reflected on both sides.

**1:17 PM:**

* Attempt to run the `computer-use-demo` image within the Enclave container using a nested `docker run` command.
* Encounter errors related to Docker connectivity and DNS resolution.
* Try different approaches to resolve the connectivity issues, including specifying the `DOCKER_HOST` environment variable and using the `--net=host` flag.

**1:23 PM:**

* Successfully run the `computer-use-demo` image within the Enclave container and access the application from the host machine.
* Celebrate the successful completion of the Enclave POC!

**1:34 PM:**

* Compile a detailed history of the debugging and validation process in Markdown format.
* Discuss the next steps for refining the Enclave environment and finalizing the POC.

This detailed timeline captures the key events and challenges faced during the Enclave POC debugging and validation process. It provides a comprehensive record of the progress made and can serve as a valuable reference for future development and testing efforts.
