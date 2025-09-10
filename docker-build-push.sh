#!/bin/bash
set -e

# -----------------------------
# CONFIGURATION
# -----------------------------
IMAGE_NAME="arunvel1988/my-backstage"
PROJECT_DIR="$HOME/backstage"
CONTAINER_NAME="my-backstage-container"
HOST_PORT=7007
CONTAINER_PORT=7007

# -----------------------------
# Ask user for Docker tag
# -----------------------------
read -p "Enter Docker image tag (e.g., hello-$(date +%Y%m%d%H%M%S)): " IMAGE_TAG
if [ -z "$IMAGE_TAG" ]; then
    echo "No tag entered. Exiting."
    exit 1
fi

# -----------------------------
# Install Node.js & Yarn if missing
# -----------------------------
if ! command -v node &>/dev/null; then
    echo "Node.js not found. Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

if ! command -v yarn &>/dev/null; then
    echo "Yarn not found. Installing Yarn..."
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt update
    sudo apt install --no-install-recommends -y yarn
fi

# -----------------------------
# Build Backstage
# -----------------------------
cd "$PROJECT_DIR"

echo "Installing project dependencies..."
yarn install --frozen-lockfile

echo "Building Backstage..."
yarn build

# -----------------------------
# Build Docker image
# -----------------------------
FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
echo "Building Docker image $FULL_IMAGE..."
docker build -t "$FULL_IMAGE" .

# -----------------------------
# Docker login
# -----------------------------
echo "Logging into Docker Hub..."
read -p "Docker username: " DOCKER_USER
read -sp "Docker password: " DOCKER_PASS
echo
echo "$DOCKER_PASS" | docker login --username "$DOCKER_USER" --password-stdin

# -----------------------------
# Push Docker image
# -----------------------------
echo "Pushing Docker image $FULL_IMAGE to Docker Hub..."
docker push "$FULL_IMAGE"

# -----------------------------
# Run Docker container
# -----------------------------
# Stop any existing container with the same name
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Stopping existing container..."
    docker rm -f "$CONTAINER_NAME"
fi

echo "Running Docker container $CONTAINER_NAME..."
docker run -d --name "$CONTAINER_NAME" -p "$HOST_PORT:$CONTAINER_PORT" "$FULL_IMAGE"

echo "Done!"
echo "Frontend URL: http://localhost:$HOST_PORT"
echo "Backend API example: http://localhost:$HOST_PORT/api/hello"
