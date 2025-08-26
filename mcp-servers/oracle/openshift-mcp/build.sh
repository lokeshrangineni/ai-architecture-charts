#!/bin/bash

# Build Oracle MCP Server Container
set -e

echo "Building Oracle MCP Server container for AMD64..."

# Build the container for AMD64 architecture
docker buildx build --platform linux/amd64 -f openshift-mcp/Containerfile -t oracle-mcp-server:latest .

# Tag for Quay.io
echo "Tagging for Quay.io..."
docker tag oracle-mcp-server:latest quay.io/lrangine/oracle-mcp-server:3.0.0

echo "Build complete!"
echo "To push to Quay.io:"
echo "  docker push quay.io/lrangine/oracle-mcp-server:3.0.0"
echo ""
echo "To deploy to OpenShift:"
echo "  oc apply -f openshift-mcp/"
echo ""
echo "To test locally with port-forwarding:"
echo "  oc port-forward svc/oracle-mcp-server 9000:9000"
