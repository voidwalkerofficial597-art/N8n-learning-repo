#!/usr/bin/env python3
"""
Validate render.yaml against Render's official JSON schema.

Usage:
    pip install jsonschema pyyaml
    python scripts/validate-render-yaml.py [path/to/render.yaml]

The schema is downloaded from https://render.com/schema/render.yaml.json
(override with RENDER_SCHEMA_URL or point RENDER_SCHEMA_FILE at a local copy).
Exit code 0 = valid, 1 = invalid, 2 = could not run (missing deps / schema).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

SCHEMA_URL = os.environ.get("RENDER_SCHEMA_URL", "https://render.com/schema/render.yaml.json")


def die(msg: str, code: int = 2) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def load_schema() -> dict:
    local = os.environ.get("RENDER_SCHEMA_FILE")
    if local:
        return json.loads(Path(local).read_text(encoding="utf-8"))
    req = urllib.request.Request(SCHEMA_URL, headers={"User-Agent": "render-yaml-validator/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:  # noqa: S310 (fixed https URL)
        return json.loads(resp.read().decode("utf-8"))


def extra_checks(doc: dict) -> list[str]:
    """Project-specific sanity checks that the JSON schema cannot express."""
    problems: list[str] = []
    services = doc.get("services", []) or []
    databases = doc.get("databases", []) or []
    names = {s.get("name") for s in services} | {d.get("name") for d in databases}

    # All resources must share one region (private network is per-region).
    regions = {r.get("region") for r in services + databases if r.get("region")}
    if len(regions) > 1:
        problems.append(f"resources span multiple regions {sorted(regions)}; use one region")

    for svc in services:
        for ev in svc.get("envVars", []) or []:
            ref = ev.get("fromService") or ev.get("fromDatabase")
            if ref and ref.get("name") not in names:
                problems.append(f"{svc.get('name')}: env {ev.get('key')} references unknown resource {ref.get('name')!r}")
        if svc.get("runtime") == "docker":
            dockerfile = svc.get("dockerfilePath", "./Dockerfile")
            if not Path(dockerfile).exists():
                problems.append(f"{svc.get('name')}: dockerfilePath {dockerfile!r} not found (run from repo root)")
    return problems


def main() -> None:
    try:
        import yaml  # type: ignore
        import jsonschema  # type: ignore
    except ImportError as exc:  # pragma: no cover
        die(f"missing dependency ({exc.name}); run: pip install jsonschema pyyaml")

    path = Path(sys.argv[1] if len(sys.argv) > 1 else "render.yaml")
    if not path.exists():
        die(f"{path} not found")
    os.chdir(path.parent or ".")

    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    try:
        schema = load_schema()
    except Exception as exc:  # network / parse failure
        die(f"could not load schema from {SCHEMA_URL}: {exc}")

    validator_cls = jsonschema.validators.validator_for(schema)
    validator = validator_cls(schema)
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.absolute_path))

    problems = extra_checks(doc)
    if errors or problems:
        for err in errors:
            loc = "/".join(str(p) for p in err.absolute_path) or "<root>"
            if not err.context:
                print(f"schema: {loc}: {err.message}")
                continue
            # oneOf/anyOf errors are huge; list the distinct underlying causes instead
            # (one per candidate branch, most relevant first).
            print(f"schema: {loc}: does not match any allowed resource shape. Possible causes:")
            seen: set[str] = set()
            ranked = sorted(err.context, key=jsonschema.exceptions.relevance, reverse=True)
            for sub in ranked:
                sub_loc = "/".join(str(p) for p in sub.absolute_path) or loc
                msg = f"  - {sub_loc}: {sub.message}"
                if msg not in seen:
                    seen.add(msg)
                    print(msg[:400])
                if len(seen) >= 6:
                    break
        for p in problems:
            print(f"check:  {p}")
        sys.exit(1)

    print(f"OK: {path.name} is valid ({len(doc.get('services', []))} services, {len(doc.get('databases', []))} databases)")


if __name__ == "__main__":
    main()
