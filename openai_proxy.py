"""
Proxy server that converts non-streaming requests to streaming.
Sits between verifiers and the tinygrad server.

Usage:
    python openai_proxy.py --backend-port 7776 --proxy-port 7777
"""
import argparse
import json
import time
import httpx
from bottle import Bottle, request, response, abort

app = Bottle()

BACKEND_URL = "http://localhost:7776"


def parse_sse_line(line: str) -> dict | None:
    """Parse a Server-Sent Event line."""
    line = line.strip()
    if not line or line == "data: [DONE]":
        return None
    if line.startswith("data: "):
        try:
            return json.loads(line[6:])
        except json.JSONDecodeError:
            return None
    return None


@app.route("/v1/models", method="GET")
def models():
    """Proxy /v1/models endpoint."""
    response.content_type = "application/json"
    return json.dumps({
        "object": "list",
        "data": [{"id": "local", "object": "model", "owned_by": "tinygrad"}]
    })


def stream_chat_completions(rjson):
    """Generator for streaming chat completions."""
    rjson["stream"] = True
    with httpx.stream(
        "POST",
        f"{BACKEND_URL}/v1/chat/completions",
        json=rjson,
        timeout=600.0
    ) as r:
        for line in r.iter_lines():
            yield line + "\n"


@app.route("/v1/chat/completions", method="POST")
def chat_completions():
    """Handle chat completions - convert non-streaming to streaming."""
    rjson = json.loads(request.body.read())

    # If client wants streaming, just proxy through
    if rjson.get("stream", False):
        response.content_type = "text/event-stream"
        response.set_header("Cache-Control", "no-cache")
        return stream_chat_completions(rjson)

    # Non-streaming: collect all chunks and return complete response
    rjson["stream"] = True  # Force streaming to backend

    collected_content = []
    finish_reason = None
    completion_id = f"chatcmpl-{int(time.time())}"
    created = int(time.time())
    model = rjson.get("model", "local")

    try:
        with httpx.stream(
            "POST",
            f"{BACKEND_URL}/v1/chat/completions",
            json=rjson,
            timeout=600.0
        ) as r:
            for line in r.iter_lines():
                data = parse_sse_line(line)
                if data and "choices" in data:
                    for choice in data["choices"]:
                        if "delta" in choice and "content" in choice["delta"]:
                            collected_content.append(choice["delta"]["content"])
                        if "finish_reason" in choice and choice["finish_reason"]:
                            finish_reason = choice["finish_reason"]
    except httpx.TimeoutException:
        abort(504, "Backend timeout")
    except httpx.ConnectError:
        abort(502, "Cannot connect to backend")

    full_content = "".join(collected_content)

    response.content_type = "application/json"
    return json.dumps({
        "id": completion_id,
        "object": "chat.completion",
        "created": created,
        "model": model,
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": full_content
            },
            "finish_reason": finish_reason or "stop"
        }],
        "usage": {
            "prompt_tokens": -1,
            "completion_tokens": -1,
            "total_tokens": -1
        }
    })


def stream_completions(rjson):
    """Generator for streaming completions."""
    rjson["stream"] = True
    with httpx.stream(
        "POST",
        f"{BACKEND_URL}/v1/completions",
        json=rjson,
        timeout=600.0
    ) as r:
        for line in r.iter_lines():
            yield line + "\n"


@app.route("/v1/completions", method="POST")
def completions():
    """Handle completions - convert non-streaming to streaming."""
    rjson = json.loads(request.body.read())

    # If client wants streaming, just proxy through
    if rjson.get("stream", False):
        response.content_type = "text/event-stream"
        response.set_header("Cache-Control", "no-cache")
        return stream_completions(rjson)

    # Non-streaming: collect all chunks
    rjson["stream"] = True

    collected_text = []
    finish_reason = None
    completion_id = f"cmpl-{int(time.time())}"
    created = int(time.time())
    model = rjson.get("model", "local")

    try:
        with httpx.stream(
            "POST",
            f"{BACKEND_URL}/v1/completions",
            json=rjson,
            timeout=600.0
        ) as r:
            for line in r.iter_lines():
                data = parse_sse_line(line)
                if data and "choices" in data:
                    for choice in data["choices"]:
                        if "text" in choice:
                            collected_text.append(choice["text"])
                        if "finish_reason" in choice and choice["finish_reason"]:
                            finish_reason = choice["finish_reason"]
    except httpx.TimeoutException:
        abort(504, "Backend timeout")
    except httpx.ConnectError:
        abort(502, "Cannot connect to backend")

    full_text = "".join(collected_text)

    response.content_type = "application/json"
    return json.dumps({
        "id": completion_id,
        "object": "text_completion",
        "created": created,
        "model": model,
        "choices": [{
            "index": 0,
            "text": full_text,
            "finish_reason": finish_reason or "stop"
        }],
        "usage": {
            "prompt_tokens": -1,
            "completion_tokens": -1,
            "total_tokens": -1
        }
    })


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OpenAI API proxy for streaming-only backends")
    parser.add_argument("--backend-port", type=int, default=7776, help="Backend server port")
    parser.add_argument("--proxy-port", type=int, default=7777, help="Proxy server port")
    args = parser.parse_args()

    BACKEND_URL = f"http://localhost:{args.backend_port}"

    print(f"Starting proxy server on port {args.proxy_port}")
    print(f"Forwarding to backend at {BACKEND_URL}")
    print(f"\nEndpoints available at:")
    print(f"  POST http://localhost:{args.proxy_port}/v1/completions")
    print(f"  POST http://localhost:{args.proxy_port}/v1/chat/completions")
    print(f"  GET  http://localhost:{args.proxy_port}/v1/models")

    app.run(host="0.0.0.0", port=args.proxy_port)
