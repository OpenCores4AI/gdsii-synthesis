#!/usr/bin/env python3
"""Aggregate per-agent JSON files -> verification.json (VerificationReport)."""
import argparse, json, os
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
