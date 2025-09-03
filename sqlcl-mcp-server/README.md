# Oracle SQLcl MCP Server with Toolhive on OpenShift

This directory contains everything needed to deploy an Oracle SQLcl MCP (Model Context Protocol) server using Toolhive on OpenShift.

## 📋 **Overview**

The Oracle SQLcl MCP Server provides AI assistants (like Cursor IDE) with the ability to:
- Connect to Oracle databases
- Execute SQL queries
- Retrieve database schemas and metadata
- Perform database operations through natural language

This implementation uses **Toolhive** to manage the MCP server deployment and provide HTTP/SSE proxy capabilities for easy integration.

## 🏗️ **Architecture**

```
Cursor IDE → Bridge Script → Port-Forward → Toolhive Proxy → Oracle MCP Server → Oracle Database
```

- **Oracle MCP Server**: SQLcl-based container running MCP protocol over stdio
- **Toolhive Proxy**: Converts stdio to HTTP/SSE for web access
- **Bridge Script**: Handles session management between Cursor and Toolhive
- **OpenShift**: Container orchestration platform

## 📁 **Files in this Directory**

| File | Purpose |
|------|---------|
| `Dockerfile` | Container image definition for Oracle SQLcl MCP server |
| `build.sh` | Script to build and push the container image |
| `oracle-mcp-server-toolhive.yaml` | **Main Toolhive CRD** - defines the MCP server |
| `toolhive-oracle-scc.yaml` | Security Context Constraints for OpenShift |
| `openshift-deployment.yaml` | Alternative Kubernetes deployment (without Toolhive) |
| `cursor-toolhive-bridge.sh` | Bridge script for Cursor IDE integration |
| `README.md` | This documentation |

## 🚀 **Prerequisites**

### **OpenShift Cluster**
- OpenShift 4.x cluster with admin access
- `oc` CLI tool installed and configured
- Access to create namespaces, CRDs, and security policies

### **Toolhive Installation**
- Toolhive operator installed on the cluster
- Toolhive CRDs available (`toolhive.stacklok.dev/v1alpha1`)

### **Container Registry**
- Access to a container registry (e.g., Quay.io, Docker Hub)
- Registry credentials configured in OpenShift

### **Oracle Database**
- Oracle database accessible from OpenShift cluster
- Database credentials (username, password, connection string)

## 📦 **Installation Steps**

### **Step 1: Install Toolhive Operator**

If Toolhive is not already installed:

```bash
# Install Toolhive operator (cluster admin required)
oc apply -f https://github.com/stacklok/toolhive/releases/latest/download/toolhive-operator.yaml

# Verify installation
oc get pods -n toolhive-system
```

### **Step 2: Create Namespace**

```bash
# Create namespace for the MCP server
oc new-project loki-toolhive-oracle-mcp

# Or use existing namespace
oc project loki-toolhive-oracle-mcp
```

### **Step 3: Apply Security Context Constraints**

```bash
# Apply SCC (cluster admin required)
oc apply -f toolhive-oracle-scc.yaml

# Verify SCC is created
oc get scc toolhive-oracle-scc
```

### **Step 4: Build and Push Container Image**

```bash
# Update build.sh with your registry details
vim build.sh

# Build and push the image
./build.sh
```

**Edit `build.sh` to configure:**
- `REGISTRY`: Your container registry URL
- `IMAGE_NAME`: Your image name
- `TAG`: Version tag

### **Step 5: Configure Database Connection**

Edit `oracle-mcp-server-toolhive.yaml` and update the environment variables:

```yaml
env:
- name: ORACLE_USER
  value: "your_oracle_user"
- name: ORACLE_PASSWORD  
  value: "your_oracle_password"
- name: ORACLE_CONNECTION_STRING
  value: "host:port/service_name"
```

**Security Note**: For production, use Kubernetes secrets instead of plain text:

```yaml
env:
- name: ORACLE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: oracle-credentials
      key: password
```

### **Step 6: Deploy MCP Server**

```bash
# Deploy the Toolhive MCP server
oc apply -f oracle-mcp-server-toolhive.yaml

# Verify deployment
oc get mcpserver oracle-mcp-server
oc get pods -l toolhive-name=oracle-mcp-server
```

### **Step 7: Verify Deployment**

```bash
# Check MCP server pod
oc logs oracle-mcp-server-0

# Check Toolhive proxy pod  
oc logs -l app=mcpserver

# Test connectivity
oc port-forward svc/mcp-oracle-mcp-server-proxy 8081:8080 &
curl -s http://localhost:8081/sse | head -3
```

## 🔧 **Cursor IDE Integration**

### **Step 1: Set Up Port Forward**

```bash
# Forward Toolhive proxy to local port
oc port-forward svc/mcp-oracle-mcp-server-proxy 8081:8080 -n loki-toolhive-oracle-mcp &
```

### **Step 2: Configure Cursor MCP**

Create or update `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "oracle-database-toolhive": {
      "command": "/path/to/cursor-toolhive-bridge.sh",
      "args": [],
      "env": {}
    }
  }
}
```

### **Step 3: Update Bridge Script**

Ensure `cursor-toolhive-bridge.sh` has the correct port:

```bash
# Edit the bridge script
vim cursor-toolhive-bridge.sh

# Update PROXY_URL to match your port-forward
PROXY_URL="http://localhost:8081"
```

### **Step 4: Test in Cursor**

1. **Restart Cursor IDE** completely
2. **Open a new chat** in Cursor
3. **Test queries**:
   - "What Oracle database tools are available?"
   - "Show me the database schemas"
   - "List tables in the HR schema"

## 🔍 **Troubleshooting**

### **Common Issues**

| Issue | Solution |
|-------|----------|
| Pod fails to start | Check SCC permissions and image pull policy |
| Connection refused | Verify port-forward and proxy service |
| Session expired | Bridge script handles this automatically |
| Permission denied | Ensure SCC is applied and bound correctly |
| Image pull errors | Check registry credentials and image name |

### **Debugging Commands**

```bash
# Check MCP server logs
oc logs oracle-mcp-server-0 -f

# Check Toolhive proxy logs
oc logs -l app=mcpserver -f

# Check pod status
oc describe pod oracle-mcp-server-0

# Test bridge script manually
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}' | ./cursor-toolhive-bridge.sh

# Check Toolhive resources
oc get mcpserver
oc describe mcpserver oracle-mcp-server
```

### **Log Locations**

- **MCP Server**: `oc logs oracle-mcp-server-0`
- **Toolhive Proxy**: `oc logs -l app=mcpserver`
- **Bridge Script**: Outputs to stderr when running

## 🔒 **Security Considerations**

### **Database Credentials**
- Use Kubernetes secrets for production deployments
- Rotate credentials regularly
- Limit database user permissions to minimum required

### **Network Security**
- MCP server only accessible within cluster
- Toolhive proxy provides controlled external access
- Port-forward creates secure tunnel to local machine

### **OpenShift Security**
- SCC provides minimal required permissions
- No privileged containers or host access
- Scoped to specific service account

## 📚 **Additional Resources**

- [Toolhive Documentation](https://github.com/stacklok/toolhive)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Oracle SQLcl Documentation](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/)
- [OpenShift Security Context Constraints](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Need help?** Check the troubleshooting section or open an issue in the repository.
