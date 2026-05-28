#!/usr/bin/env python3
"""Icarus compile log or vvp runtime log -> AgentResult JSON."""
import json, re, sys

def main():
    path, exit_code, phase = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    agent = sys.argv[4] if len(sys.argv) > 4 else "sim"
    with open(path, encoding="utf-8", errors="replace") as f:
        out = f.read()
    diags = []
    if phase == "compile":
        for m in re.finditer(r"^([^:\n]+):(\d+):\s+(error|warning|syntax error|sorry):\s+(.+)$", out, re.M | re.I):
            file_, line, sev, msg = m.groups()
            diags.append({
                "severity": "error" if "error" in sev else "warning",
                "code": "ICARUS",
                "message": msg.strip(),
                "location": {"file": file_, "line": int(line)},
            })
    else:
        for line in out.splitlines():
            if re.search(r"\bFATAL\b|\$fatal", line, re.I):
                diags.append({"severity": "fatal", "code": "SIM_FATAL", "message": line.strip()})
            elif re.search(r"\bERROR\b|\$error", line, re.I):
                diags.append({"severity": "error", "code": "SIM_ERROR", "message": line.strip()})
            elif re.search(r"Assertion .* failed", line, re.I):
                diags.append({"severity": "error", "code": "ASSERT_FAILED", "message": line.strip()})
            elif re.search(r"mismatch", line, re.I) and re.search(r"expected", line, re.I):
                diags.append({"severity": "error", "code": "GOLDEN_MISMATCH", "message": line.strip()})
    failed = any(d["severity"] in ("error", "fatal") for d in diags)
    is_pass = (not failed) and exit_code == 0
    print(json.dumps({
        "agent": agent, "pass": is_pass, "diagnostics": diags,
        "suggestedFixes": [], "artifacts": [],
        "metrics": {"exitCode": exit_code, "phase": phase,
                    "fatals": sum(1 for d in diags if d["severity"] == "fatal")},
        "durationMs": 0, "skipped": False,
    }))

if __name__ == "__main__":
    main()
