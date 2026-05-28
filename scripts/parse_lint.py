#!/usr/bin/env python3
"""Verilator lint output -> AgentResult JSON on stdout."""
import json, re, sys

def main():
    path, exit_code = sys.argv[1], int(sys.argv[2])
    with open(path, encoding="utf-8", errors="replace") as f:
        out = f.read()
    diags = []
    pat = re.compile(
        r"^%(Error|Warning|Info)(?:-([A-Z_]+))?:\s+([^:]+):(\d+)(?::(\d+))?:\s+(.+)$",
        re.M,
    )
    for m in pat.finditer(out):
        sev_raw, code, file_, line, col, msg = m.groups()
        sev = "error" if sev_raw == "Error" else "warning" if sev_raw == "Warning" else "info"
        d = {"severity": sev, "code": code or "VERILATOR", "message": msg.strip(),
             "location": {"file": file_, "line": int(line)}}
        if col:
            d["location"]["column"] = int(col)
        diags.append(d)
    errors = sum(1 for d in diags if d["severity"] in ("error", "fatal"))
    warnings = sum(1 for d in diags if d["severity"] == "warning")
    # Guard against false-pass when verilator failed to run at all.
    if exit_code != 0 and not diags:
        print(json.dumps({
            "agent": "lint", "pass": False, "diagnostics": [], "suggestedFixes": [],
            "artifacts": [], "metrics": {"exitCode": exit_code},
            "durationMs": 0, "skipped": True,
            "skipReason": f"verilator did not produce parseable output (exit {exit_code})",
        }))
        return
    print(json.dumps({
        "agent": "lint", "pass": errors == 0, "diagnostics": diags,
        "suggestedFixes": [], "artifacts": [],
        "metrics": {"errors": errors, "warnings": warnings, "exitCode": exit_code},
        "durationMs": 0, "skipped": False,
    }))

if __name__ == "__main__":
    main()
