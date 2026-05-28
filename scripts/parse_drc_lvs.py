#!/usr/bin/env python3
"""Magic DRC + netgen LVS logs -> AgentResult JSON."""
import json, re, sys, os

def main():
    drc_path, lvs_path = sys.argv[1], sys.argv[2]
    drc = open(drc_path, encoding="utf-8", errors="replace").read() if os.path.exists(drc_path) else ""
    lvs = open(lvs_path, encoding="utf-8", errors="replace").read() if os.path.exists(lvs_path) else ""
    drc_errors = 0
    m = re.search(r"Total DRC errors found:\s+(\d+)", drc)
    if m: drc_errors = int(m.group(1))
    lvs_match = bool(re.search(r"Circuits match uniquely\.|LVS Match", lvs, re.I))
    diags = []
    if drc_errors:
        diags.append({"severity": "error", "code": "DRC_VIOLATION",
                      "message": f"{drc_errors} DRC error(s) reported by Magic"})
    if not lvs_match and lvs:
        diags.append({"severity": "error", "code": "LVS_MISMATCH",
                      "message": "netgen reports schematic vs layout mismatch"})
    is_pass = drc_errors == 0 and (lvs_match or not lvs)
    print(json.dumps({
        "agent": "drc-lvs", "pass": is_pass, "diagnostics": diags,
        "suggestedFixes": [], "artifacts": [],
        "metrics": {"drcErrors": drc_errors, "lvsMatch": lvs_match},
        "durationMs": 0, "skipped": False,
    }))

if __name__ == "__main__":
    main()
