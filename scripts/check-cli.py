#!/usr/bin/env python3
"""End-to-end checks against a built or installed Stübli CLI."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

cli = Path(sys.argv[1]).resolve()

def call(*args, ok=True):
    p = subprocess.run([str(cli), *map(str, args)], capture_output=True, text=True)
    assert (p.returncode == 0) == ok, (args, p.returncode, p.stdout, p.stderr)
    return p.stdout

with tempfile.TemporaryDirectory(prefix="stuebli-check-") as temp:
    scene = Path(temp) / "scene.json"
    patch = Path(temp) / "patch.json"
    call("sample", scene)
    data = json.loads(call("inspect", scene))
    item = data["items"][0]
    call("set", scene, item["id"], "width", "1", ok=False)
    assert json.loads(scene.read_text()) == data
    patch.write_text(json.dumps({"name": "Batch test", "updates": [{"id": item["id"], "x": 2, "rotation": 90}]}))
    call("patch", scene, patch)
    changed = json.loads(call("inspect", scene, item["id"]))
    assert changed["x"] == 2 and changed["rotation"] == 90
    before = scene.read_bytes()
    patch.write_text(json.dumps({"updates": [{"id": item["id"], "x": 3}, {"id": "missing", "x": 1}]}))
    call("patch", scene, patch, ok=False)
    assert scene.read_bytes() == before
    assert len(json.loads(call("catalog", "MICKE"))) == 2
    added = json.loads(call("add", scene, "ikea-ch-80213074"))
    assert added["catalogID"] == "ikea-ch-80213074"
    call("custom", scene, added["id"])
    call("set", scene, added["id"], "width", "1.1")
    call("check", scene)
    call("routes", scene)
    print("PASS CLI: catalog, sample, product locks, batch updates, atomic rejection, additions, custom resize, checks and routes")
