#!/usr/bin/env python3
"""OpenSTA report -> AgentResult JSON."""
import json, re, sys

def main():
    path, exit_code = sys.argv[1], int(sys.argv[2])
    with open(path, encoding="utf-8", errors="replace") as f:
        out = f.read()
    setup_viol = len(re.findall(r"VIOLATED.*\(setup\)", out, re.I))
    hold_viol  = len(re.findall(r"VIOLATED.*\(hold\)",  out, re.I))
    wns = None
    m = re.search(r"worst slack\s+([-\d.]+)", out, re.I)
    if m:
        try: wns = float(m.group(1))
        except ValueError: pass
    diags = []
    if setup_viol:
        diags.append({"severity": "error", "code": "STA_SETUP",
                      "message": f"{setup_viol} setup violation(s)"})
    if hold_viol:
        diags.append({"severity": "error", "code": "STA_HOLD",
                      "message": f"{hold_viol} hold violation(s)"})
    is_pass = exit_code == 0 and setup_viol == 0 and hold_viol == 0
    print(json.dumps({
        "agent": "sta", "pass": is_pass, "diagnostics": diags,
        "suggestedFixes": [], "artifacts": [],
        "metrics": {"setupViolations": setup_viol, "holdViolations": hold_viol,
                    "wns": wns, "exitCode": exit_code},
        "durationMs": 0, "skipped": False,
    }))

if __name__ == "__main__":
    main()
