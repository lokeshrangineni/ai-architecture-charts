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
    echo 'unset JAVA_TOOL_OPTIONS' >> /start-mcp.sh && \
    echo 'unset _JAVA_OPTIONS' >> /start-mcp.sh && \
    echo '# Create a saved SQLcl connection if env vars provided' >> /start-mcp.sh && \
    echo 'if [ -n "$ORACLE_USER" ] && [ -n "$ORACLE_PASSWORD" ] && [ -n "$ORACLE_CONNECTION_STRING" ]; then' >> /start-mcp.sh && \
    echo '  CONNECTION_ALIAS=${ORACLE_CONN_NAME:-oracle_connection}' >> /start-mcp.sh && \
    echo '  echo "Creating saved connection: $CONNECTION_ALIAS"' >> /start-mcp.sh && \
    echo '  echo "connect -savepwd -save $CONNECTION_ALIAS ${ORACLE_USER}/${ORACLE_PASSWORD}@${ORACLE_CONNECTION_STRING}" | /opt/oracle/sqlcl/bin/sql /NOLOG' >> /start-mcp.sh && \
    echo '  echo "connect -list" | /opt/oracle/sqlcl/bin/sql /NOLOG > /tmp/sqlcl_list.txt 2>/dev/null || true' >> /start-mcp.sh && \
    echo '  if grep -q "$CONNECTION_ALIAS" /tmp/sqlcl_list.txt; then echo "Saved connection present: $CONNECTION_ALIAS"; else echo "Saved connection NOT found in -list output"; fi' >> /start-mcp.sh && \
    echo '  touch /sqlcl-home/.startup_saved_connection || true' >> /start-mcp.sh && \
    echo 'else' >> /start-mcp.sh && \
    echo '  echo "Skipping saved connection creation; missing ORACLE_USER/ORACLE_PASSWORD/ORACLE_CONNECTION_STRING"' >> /start-mcp.sh && \
    echo 'fi' >> /start-mcp.sh && \
    echo '# Start SQLcl MCP with verbose logging' >> /start-mcp.sh && \
    echo 'exec /opt/oracle/sqlcl/bin/sql -mcp' >> /start-mcp.sh && \
    chmod +x /start-mcp.sh

# Utility script to list saved SQLcl connections
RUN echo '#!/bin/bash' > /list-saved-connections.sh && \
    echo 'unset JAVA_TOOL_OPTIONS' >> /list-saved-connections.sh && \
    echo 'unset _JAVA_OPTIONS' >> /list-saved-connections.sh && \
    echo 'echo "Listing saved SQLcl connections..."' >> /list-saved-connections.sh && \
    echo 'echo "connect -list" | /opt/oracle/sqlcl/bin/sql /NOLOG' >> /list-saved-connections.sh && \
    chmod +x /list-saved-connections.sh

# Start SQLcl in MCP mode
ENTRYPOINT ["/start-mcp.sh"]
