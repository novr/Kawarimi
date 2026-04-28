#!/usr/bin/env python3
"""OpenAPI 3.1 perf fixtures (N GET ops, op0..op{N-1})."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


GENERATOR_CONFIG = """\
generate:
  - types
namingStrategy: defensive
accessModifier: public
"""

KAWARIMI_CONFIG = "handlerStubPolicy: throw\n"


def build_paths(n: int) -> dict:
    paths: dict = {}
    for i in range(n):
        paths[f"/op{i}"] = {
            "get": {
                "operationId": f"op{i}",
                "responses": {"200": {"description": "OK"}},
            }
        }
    return paths


def document_dict(n: int) -> dict:
    return {
        "openapi": "3.1.0",
        "info": {"title": "KawarimiPerfFixture", "version": "1.0.0"},
        "paths": build_paths(n),
    }


def write_yaml(path: Path, n: int) -> None:
    doc = document_dict(n)
    lines = [
        'openapi: "3.1.0"',
        "info:",
        "  title: KawarimiPerfFixture",
        '  version: "1.0.0"',
        "paths:",
    ]
    for i in range(n):
        lines.append(f"  /op{i}:")
        lines.append("    get:")
        lines.append(f"      operationId: op{i}")
        lines.append("      responses:")
        lines.append("        '200':")
        lines.append("          description: OK")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(path: Path, n: int) -> None:
    text = json.dumps(document_dict(n), indent=2) + "\n"
    path.write_text(text, encoding="utf-8")


def preset_operations(name: str) -> int:
    if name == "small":
        return 16
    if name == "large":
        return 832
    raise ValueError(f"unknown preset: {name}")


def main() -> int:
    p = argparse.ArgumentParser(description="OpenAPI perf fixtures for Kawarimi.")
    p.add_argument(
        "out_dir",
        type=Path,
        help="Directory to write openapi.yaml / openapi.json and config files into",
    )
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument(
        "--preset",
        choices=("small", "large"),
        help="small (~100 YAML lines) or large (~5000 YAML lines)",
    )
    g.add_argument(
        "--operations",
        type=int,
        metavar="N",
        help="Exact number of GET operations (operationId op0 .. op{N-1})",
    )
    p.add_argument(
        "--format",
        choices=("yaml", "json", "both"),
        default="yaml",
        help="Which spec file(s) to write (default: yaml)",
    )
    args = p.parse_args()

    n = preset_operations(args.preset) if args.preset else args.operations
    if n < 1:
        print("--operations must be >= 1", file=sys.stderr)
        return 2

    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "openapi-generator-config.yaml").write_text(GENERATOR_CONFIG, encoding="utf-8")
    (out_dir / "kawarimi-generator-config.yaml").write_text(KAWARIMI_CONFIG, encoding="utf-8")

    if args.format in ("yaml", "both"):
        ypath = out_dir / "openapi.yaml"
        write_yaml(ypath, n)
        ylines = len(ypath.read_text(encoding="utf-8").splitlines())
        print(f"Wrote {ypath} ({ylines} lines, {n} operations)")
    if args.format in ("json", "both"):
        jpath = out_dir / "openapi.json"
        write_json(jpath, n)
        jlines = len(jpath.read_text(encoding="utf-8").splitlines())
        print(f"Wrote {jpath} ({jlines} lines, {n} operations)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
