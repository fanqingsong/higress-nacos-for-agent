#!/usr/bin/env python3
"""Convert project openapi-spec.json to Nacos McpToolSpecification JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def resolve_ref(spec: dict[str, Any], ref: str) -> dict[str, Any]:
    if not ref.startswith("#/"):
        return {"type": "object"}
    node: Any = spec
    for part in ref.lstrip("#/").split("/"):
        node = node.get(part, {})
    return node if isinstance(node, dict) else {"type": "object"}


def schema_from_parameter(param: dict[str, Any], spec: dict[str, Any]) -> dict[str, Any]:
    schema = param.get("schema") or {"type": "string"}
    if "$ref" in schema:
        schema = resolve_ref(spec, schema["$ref"])
    out = dict(schema)
    if param.get("description"):
        out["description"] = param["description"]
    return out


def schema_from_request_body(body: dict[str, Any] | None, spec: dict[str, Any]) -> dict[str, Any] | None:
    if not body:
        return None
    content = body.get("content") or {}
    app_json = content.get("application/json") or {}
    schema = app_json.get("schema")
    if not schema:
        return None
    if "$ref" in schema:
        return resolve_ref(spec, schema["$ref"])
    return schema


def build_input_schema(
    parameters: list[dict[str, Any]], body_schema: dict[str, Any] | None, spec: dict[str, Any]
) -> dict[str, Any]:
    properties: dict[str, Any] = {}
    required: list[str] = []
    for param in parameters:
        name = param["name"]
        properties[name] = schema_from_parameter(param, spec)
        if param.get("required"):
            required.append(name)
    if body_schema and body_schema.get("type") == "object":
        for key, val in (body_schema.get("properties") or {}).items():
            properties[key] = val
        for key in body_schema.get("required") or []:
            if key not in required:
                required.append(key)
    elif body_schema:
        properties["body"] = body_schema
        required.append("body")
    schema: dict[str, Any] = {"type": "object", "properties": properties}
    if required:
        schema["required"] = required
    return schema


def template_url(path: str) -> str:
    out = path
    for segment in path.split("/"):
        if segment.startswith("{") and segment.endswith("}"):
            name = segment[1:-1]
            out = out.replace(segment, "{{.args." + name + "}}")
    return out


def build_tools(openapi_path: Path) -> dict[str, Any]:
    spec = json.loads(openapi_path.read_text(encoding="utf-8"))
    tools: list[dict[str, Any]] = []
    tools_meta: dict[str, Any] = {}

    for path, methods in (spec.get("paths") or {}).items():
        for method, op in methods.items():
            if method.lower() not in {"get", "post", "put", "patch", "delete"}:
                continue
            op_id = op.get("operationId")
            if not op_id:
                continue
            parameters = op.get("parameters") or []
            body_schema = schema_from_request_body(op.get("requestBody"), spec)
            input_schema = build_input_schema(parameters, body_schema, spec)
            description = op.get("description") or op.get("summary") or op_id
            tools.append(
                {
                    "name": op_id,
                    "description": description,
                    "inputSchema": input_schema,
                }
            )
            method_upper = method.upper()
            request_template: dict[str, Any] = {
                "method": method_upper,
                "url": template_url(path),
            }
            if method_upper == "GET":
                request_template["argsToUrlParam"] = True
            elif body_schema:
                request_template["argsToJsonBody"] = True
            tools_meta[op_id] = {
                "enabled": True,
                "invokeContext": {"path": path, "method": method_upper},
                "templates": {
                    "json-go-template": {
                        "requestTemplate": request_template,
                    }
                },
            }

    return {"tools": tools, "toolsMeta": tools_meta}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    openapi_path = root / "openapi-spec.json"
    if len(sys.argv) > 1:
        openapi_path = Path(sys.argv[1])
    out = build_tools(openapi_path)
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
