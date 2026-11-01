"""Summarize an xccov JSON report by area and check coverage targets.

Usage: python3 coverage_summary.py path/to/_coverage.json
Targets: pure logic and data code (GlanceShared) must stay well covered; SwiftUI view
files are reported but not gated (they're verified by running the app, not unit tests).
"""
import json
import sys

# Area → (path fragment, minimum line coverage %, gated?)
AREAS = [
    ("Logic",   "/GlanceShared/Sources/Logic/",  90, True),
    ("Store",   "/GlanceShared/Sources/Store/",  80, True),
    ("Models",  "/GlanceShared/Sources/Models/", 80, True),
    ("Design",  "/GlanceShared/Sources/Design/", 70, True),
    ("Starter", "/GlanceShared/Sources/SampleData/", 80, True),
    ("Views",   "/Glance/Sources/",               0, False),
]


def files_in(report):
    """Yields every (path, covered, executable) for the app target's files."""
    for target in report.get("targets", []):
        if not target["name"].startswith("Glance.app"):
            continue
        for f in target.get("files", []):
            yield f["path"], f["coveredLines"], f["executableLines"]


def main(path):
    report = json.load(open(path))
    files = list(files_in(report))
    failed = False
    print(f"\n{'Area':8} {'Lines':>11} {'Cover':>6}  Target")
    for name, frag, minimum, gated in AREAS:
        rows = [(p, c, e) for p, c, e in files if frag in p]
        covered, total = sum(r[1] for r in rows), sum(r[2] for r in rows)
        pct = 100 * covered / total if total else 100
        ok = (not gated) or pct >= minimum
        failed |= not ok
        mark = "ok" if ok else "BELOW"
        target = f">= {minimum}% {mark}" if gated else "(not gated)"
        print(f"{name:8} {covered:5}/{total:<5} {pct:5.1f}%  {target}")
    print("\nLeast-covered shared files:")
    shared = [(p, c, e) for p, c, e in files if "/GlanceShared/" in p and e]
    for p, c, e in sorted(shared, key=lambda r: r[1] / r[2])[:6]:
        print(f"  {100 * c / e:5.1f}%  {p.split('/Sources/')[-1]}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1])
