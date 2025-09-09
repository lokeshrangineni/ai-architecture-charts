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
| `dev-image-build.sh` | Script to build and push the container image |
| `oracle-mcp-server-toolhive.yaml` | **Main Toolhive CRD** - defines the MCP server |
| `toolhive-oracle-scc.yaml` | Security Context Constraints for OpenShift |
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
# Update dev-image-build.sh with your registry details
vim dev-image-build.sh

# Build and push the image
./dev-image-build.sh
```

**Edit `dev-image-build.sh` to configure:**
- `QUAY_REPO`: Your container registry URL
- `IMAGE_NAME`: Your image name
- `TAG`: Version tag

### **Step 5: Configure Database Connection**

Edit `oracle-mcp-server-toolhive.yaml` and update the environment variables (these are read by the container entrypoint to create a saved connection at startup):

```yaml
env:
- name: ORACLE_USER
  value: "your_oracle_user"
- name: ORACLE_PASSWORD  
  value: "your_oracle_password"
- name: ORACLE_CONNECTION_STRING
  value: "host:port/service_name"
        # Example: "oracle23ai.arhkp-oracle-db-tpcds-loader:1521/FREEPDB1"
- name: ORACLE_CONN_NAME
  value: "oracle_connection_demo"  # Optional; default is "oracle_connection"
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

## 🧪 **Test with MCP Inspector**

You can use MCP Inspector to interactively test the MCP server over HTTP via the Toolhive proxy.

1. Port-forward the proxy service:
   ```bash
   oc port-forward svc/mcp-oracle-mcp-server-proxy 8081:8080 -n loki-toolhive-oracle-mcp &
   ```
2. Open MCP Inspector and set the server endpoint to `http://localhost:8081`.
3. Use the following tools:
   - list-connections
   - connect
   - run-sql

Examples:
- list-connections (no params)
  ```json
  {}
  ```
- connect (explicit connection)
  ```json
  { "connectionName": "oracle23ai_connection_demo" }
  ```
- run-sql (after connect)
  ```json
  { "sql": "select table_name from user_tables fetch first 5 rows only" }
  ```
- run-sql (with explicit connection)
  ```json
  {
    "connectionName": "oracle23ai_connection_demo",
    "sql": "select 1 as ok from dual"
  }
  ```

## 🔧 Runtime Behavior and Environment

- The container entrypoint (`scripts/start-mcp.sh`) ensures:
  - Stable writable home at `/sqlcl-home` for saved connections
  - Writable Java temp dir at `/sqlcl-home/tmp`
  - Profile scripts are ignored to avoid banner/interactive noise

- On startup, if `ORACLE_USER`, `ORACLE_PASSWORD`, and `ORACLE_CONNECTION_STRING` are set, a saved connection is created with alias `ORACLE_CONN_NAME` (default: `oracle_connection`).

### List saved connections inside the pod

```bash
sh /list-saved-connections.sh           # names only
```

If you see no connections listed, verify the env vars and check the pod logs during startup for the "Creating saved connection" message.

Notes:
- Use service-style connection strings `host:port/SERVICE_NAME` (e.g., `oracle23ai.arhkp-oracle-db-tpcds-loader:1521/FREEPDB1`).
- If you see "not connected", call `connect` again or include `connectionName` in `run-sql`.

 

## 🔍 **Troubleshooting**

### **Common Issues**

| Issue | Solution |
|-------|----------|
| Pod fails to start | Check SCC permissions and image pull policy |
| Connection refused | Verify port-forward and proxy service |
| Session expired | Bridge script handles this automatically |
| Permission denied | Ensure SCC is applied and bound correctly |
| Thick driver warning | Expected in thin mode; `ORACLE_HOME` is unset intentionally |
| Read-only /tmp (Jansi .lck) | Handled by `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=/sqlcl-home/tmp` |
| Saved connection missing | Ensure `HOME=/sqlcl-home`; use `/list-saved-connections.sh` to verify |
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
