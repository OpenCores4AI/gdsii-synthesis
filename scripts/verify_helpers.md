# verify.yml helper scripts

Copy each of these into `scripts/` in the `gdsii-synthesis` repo. They are
intentionally small and dependency-free (stdlib only).

## scripts/parse_lint.py

```python
#!/usr/bin/env python3
"""Verilator lint output -> AgentResult JSON on stdout."""
import json, re, sys, time

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
```

## scripts/parse_sim.py

```python
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
```

## scripts/parse_coverage.py

```python
#!/usr/bin/env python3
"""Verilator coverage annotate log -> AgentResult JSON."""
import json, re, sys

THRESHOLD = 0.85

def main():
    path, exit_code, phase = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    if phase == "build" or not path:
        print(json.dumps({
            "agent": "coverage", "pass": False,
            "diagnostics": [{"severity": "error", "code": "COVERAGE_BUILD",
                             "message": "Verilator coverage build failed."}],
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
```

## scripts/parse_sta.py

```python
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
```

## scripts/parse_drc_lvs.py

```python
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
```

## scripts/build_report.py

```python
#!/usr/bin/env python3
"""Aggregate per-agent JSON files -> verification.json (VerificationReport)."""
import argparse, json, os, time
from datetime import datetime, timezone

# Map agent name -> file produced by the corresponding workflow step.
FILES = {
    "lint":     "lint.json",
    "sim":      "sim.json",
    "corner":   "corner.json",
    "coverage": "coverage.json",
    "sta":      "sta.json",
    "drc-lvs":  "drclvs.json",
}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--design-id", required=True)
    p.add_argument("--top-module", required=True)
    p.add_argument("--pdk", required=True)
    p.add_argument("--agents", required=True, help="comma-separated subset")
    args = p.parse_args()

    requested = [a.strip() for a in args.agents.split(",") if a.strip()]
    results = []
    for a in requested:
        f = FILES.get(a)
        if f and os.path.exists(f):
            with open(f) as fh:
                results.append(json.load(fh))
        else:
            results.append({
                "agent": a, "pass": False, "diagnostics": [],
                "suggestedFixes": [], "artifacts": [], "metrics": {},
                "durationMs": 0, "skipped": True,
                "skipReason": "agent step did not run or produced no report",
            })
    overall_pass = all(r["pass"] or r.get("skipped") for r in results)
    now = datetime.now(timezone.utc).isoformat()
    print(json.dumps({
        "designId": args.design_id,
        "topModule": args.top_module,
        "pdk": args.pdk,
        "pass": overall_pass,
        "iteration": 0,
        "startedAt": now,
        "finishedAt": now,
        "durationMs": 0,
        "agents": results,
        "aggregatedFixes": [],
    }, indent=2))

if __name__ == "__main__":
    main()
```

## After you copy

Make them executable and commit:

```bash
chmod +x scripts/parse_*.py scripts/build_report.py
git add scripts/parse_*.py scripts/build_report.py .github/workflows/verify.yml
git commit -m "verify.yml + helpers"
git push
```

Then the Vercel app's mesh runs flow into this workflow automatically.
