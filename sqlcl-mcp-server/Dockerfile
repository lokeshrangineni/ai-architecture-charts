# SQLcl MCP Server Docker Image
FROM container-registry.oracle.com/database/sqlcl:latest

# Set environment variables for Oracle SQLcl
ENV ORACLE_HOME=/opt/oracle/sqlcl
ENV JAVA_HOME=/usr/lib/jvm/jdk-17-oracle-x64
ENV PATH=/opt/oracle/sqlcl/bin:$PATH

# Enable verbose logging for MCP server
ENV MCP_LOG_LEVEL=DEBUG
ENV SQLCL_DEBUG=true

# Create a startup script that starts MCP server with verbose logging
RUN echo '#!/bin/bash' > /start-mcp.sh && \
    echo 'echo "Starting Oracle SQLcl MCP Server with verbose logging..."' >> /start-mcp.sh && \
    echo 'echo "ORACLE_HOME: $ORACLE_HOME"' >> /start-mcp.sh && \
    echo 'echo "JAVA_HOME: $JAVA_HOME"' >> /start-mcp.sh && \
    echo 'echo "PATH: $PATH"' >> /start-mcp.sh && \
    echo 'echo "Oracle Connection: $ORACLE_CONNECTION_STRING"' >> /start-mcp.sh && \
    echo 'echo "MCP Log Level: $MCP_LOG_LEVEL"' >> /start-mcp.sh && \
    echo 'echo "SQLcl Debug: $SQLCL_DEBUG"' >> /start-mcp.sh && \
    echo 'echo "Starting MCP Server for Toolhive proxy access..."' >> /start-mcp.sh && \
    echo 'echo "Enabling verbose output for MCP operations..."' >> /start-mcp.sh && \
    echo '# Start SQLcl MCP with verbose logging' >> /start-mcp.sh && \
    echo 'exec /opt/oracle/sqlcl/bin/sql -mcp' >> /start-mcp.sh && \
    chmod +x /start-mcp.sh

# Start SQLcl in MCP mode
ENTRYPOINT ["/start-mcp.sh"]
