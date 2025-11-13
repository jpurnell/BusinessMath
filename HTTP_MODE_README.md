# HTTP Mode - Experimental

## Status

HTTP transport is **experimental** and has limitations compared to stdio mode.

## Current Limitations

### Architecture Mismatch
The official MCP SDK's `Transport` protocol is designed for bidirectional streaming (like stdio or websockets), while HTTP is request/response based. This creates challenges:

1. **Server-Initiated Messages**: The server cannot send unsolicited messages to clients
2. **Long-Lived Connections**: HTTP connections are short-lived, making streaming difficult
3. **Response Handling**: Matching responses to requests requires additional infrastructure

### What Works
- ✅ HTTP server starts and listens on specified port
- ✅ Health check endpoint (`GET /health`)
- ✅ Server info endpoint (`GET /mcp`)
- ✅ Receives JSON-RPC requests (`POST /mcp`)

### What Needs Work
- ⚠️ Full request/response cycle (responses not properly routed)
- ⚠️ Server-Sent Events (SSE) for server-initiated messages
- ⚠️ Proper connection management and state
- ⚠️ Error handling and timeouts

## Recommended Approach

**For Production Use:**
Use **stdio mode** (default) with Claude Desktop or other MCP clients. This is the fully-supported, production-ready mode.

```bash
./businessmath-mcp-server
```

**For HTTP/Remote Access (Future):**
The proper solution for HTTP-based MCP is to use Server-Sent Events (SSE):
- Client sends requests via HTTP POST
- Server sends responses and notifications via SSE stream
- This requires a more sophisticated transport implementation

## Future Enhancements

To make HTTP mode production-ready, we need:

1. **SSE Support**
   - Implement Server-Sent Events for server-to-client messaging
   - Maintain client connection registry
   - Handle multiplexing of responses

2. **Custom Transport**
   - Build a true HTTP+SSE transport that properly implements MCP protocol
   - Handle connection lifecycle
   - Implement proper error recovery

3. **Authentication & Security**
   - Add authentication for remote access
   - Implement HTTPS/TLS
   - Rate limiting and abuse protection

4. **Alternative: Use a Proxy**
   - Run server in stdio mode
   - Use a separate HTTP proxy that:
     - Accepts HTTP requests
     - Forwards to stdio server
     - Returns responses
   - Example: https://github.com/modelcontextprotocol/servers/tree/main/src/mcp-proxy

## Testing Current Implementation

Even though HTTP mode is experimental, you can test basic functionality:

### Start Server
```bash
./businessmath-mcp-server --http 8080
```

### Test Health Endpoint
```bash
curl http://localhost:8080/health
```

### Test Server Info
```bash
curl http://localhost:8080/mcp
```

### Send JSON-RPC Request (Limited)
```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

**Note**: Response handling is not fully implemented, so you'll receive a placeholder response.

## Conclusion

**Use stdio mode for now.** HTTP mode demonstrates the infrastructure but needs significant work to be production-ready. The official MCP community may release better HTTP transport solutions in the future.

If you need remote access:
1. Use stdio mode locally
2. Expose via SSH tunnel or similar secure method
3. Or wait for official HTTP/SSE transport implementation
