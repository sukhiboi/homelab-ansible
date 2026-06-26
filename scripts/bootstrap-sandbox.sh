#!/bin/zsh

DOCKER_BUILD_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --reset)
      echo "------> Deleting existing image..."
      docker image rm -f homelab-sandbox
      DOCKER_BUILD_ARGS+=("--no-cache")
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--reset]"
      echo ""
      echo "--reset           Will delete the current docker image and rebuild it without any cache"
      exit 1
      ;;
  esac
done

(
cd scripts
echo "------> Building new image..."
docker build "${DOCKER_BUILD_ARGS[@]}" -f ./env/Dockerfile.sandbox -t homelab-sandbox .
docker run -d -v /var/run/docker.sock:/var/run/docker.socki --name homelab-sandbox -p 2221:22 homelab-sandbox
)
