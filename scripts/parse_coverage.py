#!/usr/bin/env python3
"""Verilator coverage annotate log -> AgentResult JSON."""
import json, re, sys

THRESHOLD = 0.85

def main():
    path, exit_code, phase = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    if phase == "build":
        # Surface the actual stderr in the diagnostic so the UI shows what
        # verilator complained about, not a generic "build failed".
        err_text = ""
        try:
            if path:
                with open(path, encoding="utf-8", errors="replace") as f:
                    err_text = f.read()
        except FileNotFoundError:
            pass
        excerpt = err_text.strip().splitlines()[-12:] if err_text.strip() else []
        msg = "Verilator coverage build failed."
        if excerpt:
            msg += "\n" + "\n".join(excerpt)
        print(json.dumps({
            "agent": "coverage", "pass": False,
            "diagnostics": [{"severity": "error", "code": "COVERAGE_BUILD",
                             "message": msg}],
            "suggestedFixes": [], "artifacts": [],
            "metrics": {"exitCode": exit_code, "phase": "build"},
            "durationMs": 0, "skipped": False,
        }))
        return
    with open(path, encoding="utf-8", errors="replace") as f:
        out = f.read()
    kinds = []
    for m in re.finditer(
        r"^\s*(line|toggle|branch|expr|fsm_state|fsm_arc)\s*:\s*([\d.]+)%\s*\(\s*(\d+)\s*/\s*(\d+)\s*\)",
        out, re.M | re.I,
    ):
        name, _, num, den = m.groups()
        d = int(den)
        if d == 0:
            continue
        kinds.append({"kind": name, "value": int(num) / d})
    overall = sum(k["value"] for k in kinds) / len(kinds) if kinds else 0
    diags = [{"severity": "warning", "code": "COVERAGE_GAP",
              "message": f"{k['kind']} coverage at {k['value']*100:.1f}%"}
             for k in kinds if k["value"] < THRESHOLD]
    print(json.dumps({
        "agent": "coverage", "pass": overall >= THRESHOLD,
        "diagnostics": diags, "suggestedFixes": [], "artifacts": [],
        "metrics": {"overall": f"{overall:.3f}", "threshold": THRESHOLD,
                    "gaps": len(diags)},
        "durationMs": 0, "skipped": False,
    }))

if __name__ == "__main__":
    main()
