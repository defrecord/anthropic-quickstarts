{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python311.withPackages (ps: with ps; [
    anthropic
    requests
    streamlit
    pip
    virtualenv
  ]);

in pkgs.mkShell {
  name = "computer-use-demo-environment";
  buildInputs = with pkgs; [
    pythonEnv
    docker
    docker-compose
    git
    jq
    curl
  ];

  shellHook = ''
    # Ensure directories exist
    mkdir -p $HOME/.anthropic
    mkdir -p $HOME/.anthropic_backups
    
    # Set up environment marker
    export PS1="\n\[\033[1;35m\](computer-use-demo)\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] \$ "
    
    # Define container management functions
    start_demo() {
      if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "Warn: ANTHROPIC_API_KEY not set"
        return 0
      fi

      if [ -z "$GITHUB_TOKEN" ]; then
        echo "Warn: GITHUB_TOKEN not set"
        return 0
      fi
      
      docker run \
        -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
        -e GITHUB_TOKEN=$GITHUB_TOKEN \
        -v $HOME/.anthropic:/home/computeruse/.anthropic \
        -p 5900:5900 \
        -p 8501:8501 \
        -p 6080:6080 \
        -p 8080:8080 \
        -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest
    }

    # Export functions
    export -f start_demo

    echo "🚀 ComputerUse environment activated"
    echo ""
    echo "Commands:"
    echo "  start_demo  - Start the ComputerUse container"
    echo ""
    echo "Ports:"
    echo "  5900 - VNC server"
    echo "  8501 - Streamlit interface"
    echo "  6060 - noVNC web interface"
    echo "  8080 - HTTP server"
  '';
}
