#!/usr/bin/env python3
import argparse, json, sys

def to_dict(data):
    if isinstance(data, dict):
        # Already {path: hash}
        return {str(k): str(v) for k, v in data.items()}
    if isinstance(data, list):
        out = {}
        for item in data:
            if not isinstance(item, dict): continue
            k = item.get("path") or item.get("name") or item.get("file") or item.get("map")
            v = item.get("hash") or item.get("sha") or item.get("digest")
            if k and v:
                out[str(k)] = str(v)
        return out
    return {}

def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return to_dict(json.load(f))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old_json")
    ap.add_argument("new_json")
    ap.add_argument("--changed-out", default="changed_maps.txt")
    ap.add_argument("--summary-out", default="hash_diff_summary.txt")
    args = ap.parse_args()

    old = load(args.old_json)
    new = load(args.new_json)

    oldk, newk = set(old), set(new)
    added   = sorted(newk - oldk)
    removed = sorted(oldk - newk)
    inter   = oldk & newk
    changed = sorted([k for k in inter if old[k] != new[k]])
    same    = sorted([k for k in inter if old[k] == new[k]])

    with open(args.changed_out, "w", encoding="utf-8") as f:
        for k in changed + added:
            f.write(k + "\n")

    with open(args.summary_out, "w", encoding="utf-8") as f:
        f.write(f"added:{len(added)} removed:{len(removed)} changed:{len(changed)} same:{len(same)}\n")

    # GitHub Actions outputs
    ghout = []
    ghout.append(f"any_changed={'true' if (changed or added or removed) else 'false'}")
    ghout.append(f"changed_count={len(changed)}")
    ghout.append(f"added_count={len(added)}")
    ghout.append(f"removed_count={len(removed)}")
    print("\n".join(ghout))

if __name__ == "__main__":
    sys.exit(main())
