#!/bin/bash

# Build and Deploy Oracle SQLcl MCP Server to OpenShift

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Oracle SQLcl MCP Server...${NC}"

# Set image name and tag
IMAGE_NAME="oracle-mcp-server"
TAG="1.0.0"
QUAY_REPO="quay.io"  # Change this to your Quay organization
QUAY_USERNAME="lrangine"      # Set this to your Quay username

# Check if Quay username is set
if [ -z "$QUAY_USERNAME" ]; then
    echo -e "${YELLOW}Warning: QUAY_USERNAME not set in build script${NC}"
    echo -e "${YELLOW}Please update the QUAY_USERNAME variable in build.sh${NC}"
    echo -e "${YELLOW}Or set it as an environment variable: export QUAY_USERNAME=your-username${NC}"
fi


# Build the container image
echo -e "${GREEN}Building container image...${NC}"
docker build -f Containerfile -t ${IMAGE_NAME}:${TAG} .

# Tag for Quay.io
if [ ! -z "$QUAY_USERNAME" ]; then
    echo -e "${GREEN}Tagging for Quay.io...${NC}"
    docker tag ${IMAGE_NAME}:${TAG} ${QUAY_REPO}/${QUAY_USERNAME}/${IMAGE_NAME}:${TAG}
    
    echo -e "${GREEN}Container build and tag complete!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Login to Quay.io: docker login quay.io"
    echo "2. Push to Quay.io: docker push ${QUAY_REPO}/${QUAY_USERNAME}/${IMAGE_NAME}:${TAG}"
    echo "3. Update openshift/secrets.yaml with your Oracle credentials"
    echo "4. Update openshift/deployment.yaml with your Oracle service details"
    echo "5. Run deploy.sh to deploy to OpenShift"
else
    echo -e "${GREEN}Container build complete!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Set QUAY_USERNAME in build.sh or as environment variable"
    echo "2. Update openshift/secrets.yaml with your Oracle credentials"
    echo "3. Update openshift/deployment.yaml with your Oracle service details"
    echo "4. Run deploy.sh to deploy to OpenShift"
fi
