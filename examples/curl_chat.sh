#!/bin/bash
# Test the server with a chat completion request
curl -X POST "http://localhost:7776/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello"}], "stream": true}'
