#!/usr/bin/env python3
"""Fetch GitLab MR review comments and flatten them into agent-actionable records.

Given an MR identifier (URL, MR number, or 'current' branch), this script:
  1. Resolves it to (host, project, mr_iid) — MR URL parsing included
  2. Runs `gitlab-comment-extractor` to fetch structured raw JSON
  3. Saves the raw JSON to /tmp/mr_<iid>_comments.json
  4. Flattens general + file comments into action items with code anchors
  5. Saves them to /tmp/mr_<iid>_action_items.json and prints a digest

Usage:
    fetch_mr_comments.py <MR_URL>
    fetch_mr_comments.py <MR_NUMBER> [--project group/project] [--host gitlab.example.com]
    fetch_mr_comments.py current          # MR for the current git branch (via glab)

Exit codes follow the extractor: 0 success, 1 general error, 2 auth failed,
3 MR not found, 4 not a git repository (and no --project given or derivable).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse

TOOL = "gitlab-comment-extractor"
DEFAULT_HOST = "gitlab.evroc.dev"  # only used as a glab hint for 'current' mode


def die(msg, code=1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def resolve_current_mr():
    """Resolve the open MR for the current git branch via glab."""
    env = dict(os.environ)
    env.setdefault("GLAB_HOST", DEFAULT_HOST)
    try:
        out = subprocess.run(["glab", "mr", "view", "--json"],
                            capture_output=True, text=True, timeout=30, env=env)
    except FileNotFoundError:
        die("`glab` CLI not found. Install it, or pass an explicit MR URL/number.")
    if out.returncode != 0:
        die("No open MR found for the current branch (or glab not authenticated). "
            "Pass an explicit MR URL or MR number.")
    try:
        payload = json.loads(out.stdout)
    except json.JSONDecodeError:
        die(f"Could not parse `glab mr view --json` output: {out.stdout[:200]!r}")
    for candidate in (payload.get("iid"),
                      (payload.get("data") or {}).get("iid") if isinstance(payload.get("data"), dict) else None):
        if candidate:
            try:
                return int(candidate)
            except (TypeError, ValueError):
                pass
    die("glab did not report an MR iid for the current branch.")


def resolve_input(target, project=None, host=None):
    """Resolve any accepted input form to (host, project, mr_iid, note_focus)."""
    target = (target or "").strip()
    if not target:
        die("Provide an MR URL, an MR number, or 'current'.")

    # MR URL: https://<host>/<group/.../project>/-/merge_requests/<iid>[?query][#note_<id>]
    if "://" in target:
        parsed = urllib.parse.urlparse(target)
        if not parsed.hostname:
            die(f"Unparseable MR URL: {target}")
        host = host or parsed.hostname
        parts = [p for p in parsed.path.split("/") if p]
        try:
            i = parts.index("-")
        except ValueError:
            die(f"Not an MR URL (missing /-/merge_requests/ segment): {target}")
        if len(parts) < i + 3 or parts[i + 1] != "merge_requests":
            die(f"Not an MR URL (missing merge_requests segment): {target}")
        project = project or "/".join(parts[:i])
        try:
            mr_iid = int(parts[i + 2])
        except ValueError:
            die(f"Non-numeric MR ID in URL: {parts[i + 2]!r} (suffixes like /diffs are fine)")
        note_focus = None
        m = re.match(r"^note_(\d+)", urllib.parse.unquote(parsed.fragment or ""))
        if m:
            note_focus = int(m.group(1))
        else:
            q = urllib.parse.parse_qs(parsed.query or "")
            if "note" in q and q["note"][0].isdigit():
                note_focus = int(q["note"][0])
        return host, project, mr_iid, note_focus

    # 'current' -> MR for the checked-out branch
    if target == "current":
        return host, project, resolve_current_mr(), None

    # Plain MR number
    try:
        return host, project, int(target), None
    except ValueError:
        die(f"Unrecognized MR reference: {target!r} "
            "(expected an MR URL, an MR number, or 'current').")


def run_extractor(mr_iid, host, project, timeout):
    """Run gitlab-comment-extractor; return its raw JSON as a dict."""
    cmd = [TOOL, "--mr", str(mr_iid)]
    if host:
        cmd += ["--host", host]
    if project:
        cmd += ["--project", project]
    if timeout:
        cmd += ["--timeout", str(timeout)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True,
                            timeout=timeout + 30)
    except FileNotFoundError:
        die(f"`{TOOL}` not found. Build it: cd ~/development/gitlab-comment-extractor "
            "&& go build -o ~/.local/bin/gitlab-comment-extractor .")
    except subprocess.TimeoutExpired:
        die(f"{TOOL} timed out after {timeout + 30}s.")
    if out.returncode != 0:
        hints = {2: "Authenticate: glab auth login --hostname gitlab.evroc.dev",
                 3: "MR not found — verify the MR number and project path",
                 4: "Not a git repository — pass --project group/project, or use a full MR URL"}
        die(f"{TOOL} failed (exit {out.returncode}): {out.stderr.strip()} "
            f"{hints.get(out.returncode, '')}", out.returncode or 1)
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        die(f"{TOOL} produced invalid JSON (empty MRs still emit a valid skeleton). "
            f"Stdout started with: {out.stdout[:200]!r}")


def make_record(c, rtype, anchor, anchor_kind, anchor_detail, note_focus):
    return {
        "id": c.get("id"),
        "type": rtype,                  # "DiffNote" | "general"
        "anchor": anchor,               # "src/file.go:45" | "src/file.go" | "MR !1234 (general)"
        "anchor_kind": anchor_kind,     # "line" | "old-line" | "file" | "mr-general"
        "anchor_detail": anchor_detail,
        "author": (c.get("author") or {}).get("username"),
        "created_at": c.get("created_at"),
        "resolvable": c.get("resolvable", False),
        "resolved": c.get("resolved", False),
        "from_note_url": bool(note_focus) and c.get("id") == note_focus,
        "body": c.get("body", ""),
    }


def flatten(data, note_focus):
    """Convert raw extractor JSON into a flat list of agent-actionable records."""
    items = []

    for path, comments in (data.get("file_comments") or {}).items():
        for c in comments:
            pos = c.get("position") or {}
            new_path, new_line = pos.get("new_path"), pos.get("new_line")
            old_path, old_line = pos.get("old_path"), pos.get("old_line")
            # Prefer the new-line anchor: it targets the source-branch version,
            # the code an acting agent would edit. old-line-only anchors mean
            # the comment sits on deleted code (compare against the target branch).
            if new_line:
                anchor, kind, detail = f"{new_path}:{new_line}", "line", \
                    "targets source-branch (new) code"
            elif old_line:
                anchor, kind, detail = f"{old_path}:{old_line}", "old-line", \
                    "comment sits on deleted (old) code — check out target branch"
            else:
                anchor, kind, detail = new_path or old_path or path, "file", \
                    "file-level comment (no line)"
            items.append(make_record(c, "DiffNote", anchor, kind, detail, note_focus))

    iid = (data.get("mr") or {}).get("iid", "?")
    for c in data.get("general_comments") or []:
        items.append(make_record(c, "general", f"MR !{iid} (general)", "mr-general",
                                 "MR-level comment, not tied to code", note_focus))

    # Unresolved first (the actionable ones), then stable by anchor and time
    items.sort(key=lambda r: (r["resolved"], str(r["anchor"]), r["created_at"] or ""))
    return items


def main():
    ap = argparse.ArgumentParser(description="Fetch GitLab MR comments as agent-actionable records.")
    ap.add_argument("target", nargs="?",
                    help="MR URL, MR number, or 'current'")
    ap.add_argument("--project", help="GitLab project path (default: auto-detect from git remote)")
    ap.add_argument("--host", help="GitLab host (default: auto-detect from git remote)")
    ap.add_argument("--raw", help="override raw JSON save path (default /tmp/mr_<iid>_comments.json)")
    ap.add_argument("--items", help="override flattened items save path (default /tmp/mr_<iid>_action_items.json)")
    ap.add_argument("--unresolved-only", action="store_true",
                    help="drop already-resolved items from records and digest")
    ap.add_argument("--quiet", action="store_true", help="print digest headers only, not bodies")
    ap.add_argument("--no-save", action="store_true", help="do not write files, print only")
    ap.add_argument("--timeout", type=int, default=30, help="API timeout in seconds (default 30)")
    args = ap.parse_args()

    host, project, mr_iid, note_focus = resolve_input(args.target, args.project, args.host)
    data = run_extractor(mr_iid, host, project, args.timeout)
    items = flatten(data, note_focus)
    if args.unresolved_only:
        items = [i for i in items if not i["resolved"]]

    mr = data.get("mr") or {}
    n_total, n_unres = len(items), sum(1 for i in items if not i["resolved"])
    n_files = len(data.get("file_comments") or {})
    raw_path = args.raw or f"/tmp/mr_{mr_iid}_comments.json"
    items_path = args.items or f"/tmp/mr_{mr_iid}_action_items.json"
    if not args.no_save:
        with open(raw_path, "w") as f:
            json.dump(data, f, indent=2)
        with open(items_path, "w") as f:
            json.dump(items, f, indent=2)

    base = f"https://{host or '?'}" + (f"/{project}" if project else "")
    print(f"MR: {mr.get('title', '?')} (!{mr.get('iid', mr_iid)}) state={mr.get('state', '?')} "
          f"{mr.get('source_branch', '?')} -> {mr.get('target_branch', '?')}")
    print(f"MR URL: {base}/-/merge_requests/{mr_iid}")
    print(f"Comments: {n_total} fetched ({n_unres} unresolved) | files with comments: {n_files}"
          f"{'' if not args.unresolved_only else ' | filtered: unresolved only'}")
    print(f"Raw JSON:      {raw_path if not args.no_save else '(not saved)'}")
    print(f"Action items:  {items_path if not args.no_save else '(not saved)'}")
    if note_focus:
        if any(i["from_note_url"] for i in items):
            print(f"URL focus: comment id={note_focus} marked (from_note_url=true)")
        else:
            print(f"URL focus: note id={note_focus} not in fetched set "
                  "(may be a resolve/system note the extractor filters)")
    print()

    for n, i in enumerate(items, 1):
        status = "RESOLVED" if i["resolved"] else ("UNRESOLVED" if i["resolvable"] else "FOR INFO")
        header = (f"[{n}] {i['anchor']} ({i['anchor_kind']}) "
                  f"@{i['author']} {status} id={i['id']}")
        if i["from_note_url"]:
            header += "  <-- note anchor from URL"
        print(header)
        if not args.quiet:
            print(f"    {i['body']}")
        print()


if __name__ == "__main__":
    main()
