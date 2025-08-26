# Oracle MCP Server - OpenShift Deployment

This folder contains the OpenShift deployment configuration for the Oracle MCP Server.

## 🏗️ **Architecture**

- **MCP Server**: Python-based MCP protocol server
- **SQLcl Integration**: Oracle SQLcl for database operations
- **HTTP Transport**: Exposes MCP over HTTP for remote access
- **OpenShift Ready**: Containerized and deployable to OpenShift

## 🚀 **Quick Start**

### 1. Build Container
```bash
chmod +x build.sh
./build.sh
```

### 2. Push to Quay.io
```bash
podman push quay.io/lrangine/oracle-mcp-server:latest
```

### 3. Deploy to OpenShift
```bash
oc apply -k .
```

### 4. Test with Port-Forwarding
```bash
oc port-forward svc/oracle-mcp-server 9000:9000
```

## 📁 **Files**

- `Containerfile` - Container image definition
- `deployment.yaml` - OpenShift deployment
- `service.yaml` - Internal service
- `route.yaml` - External route
- `build.sh` - Build script
- `kustomization.yaml` - Kustomize configuration

## 🌐 **Endpoints**

- **MCP Protocol**: `POST /mcp`
- **Health Check**: `GET /health`
- **Info**: `GET /`

## 🔧 **VS Code Configuration**

Update your VS Code MCP configuration to point to the OpenShift route:

```json
{
    "mcpServers": {
        "oracle-remote": {
            "command": "curl",
            "args": [
                "-X", "POST",
                "-H", "Content-Type: application/json",
                "-d", "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"initialize\",\"params\":{}}",
                "https://oracle-mcp-server-ai-arch-charts-rhkp.apps.ai-dev02.kni.syseng.devcluster.openshift.com/mcp"
            ],
            "env": {}
        }
    }
}
```

## 📊 **Resources**

- **Memory**: 512Mi request, 1Gi limit
- **CPU**: 500m request, 1000m limit
- **Port**: 9000

## 🔍 **Troubleshooting**

- Check pod logs: `oc logs -f deployment/oracle-mcp-server`
- Check pod status: `oc get pods -l app=oracle-mcp-server`
- Check service: `oc get svc oracle-mcp-server`
- Check route: `oc get route oracle-mcp-server`
