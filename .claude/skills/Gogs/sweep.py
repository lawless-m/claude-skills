"""Gitea sweep: what is mine to action, on any repo. Usage: sweep.py <owner>/<repo>"""
import json, os, sys, urllib.request

REPO = sys.argv[1] if len(sys.argv) > 1 else "matthew.heath/CagesWaitrose"
BASE = os.environ["GOGS_URL"] + "/api/v1/repos/" + REPO
ME = "claude"   # the account Claude posts as, via the Sudo header


def get(path):
    r = urllib.request.Request(BASE + path,
                               headers={"Authorization": "token " + os.environ["GOGS_TOKEN"]})
    return json.load(urllib.request.urlopen(r))


mine, theirs = [], []
for i in get("/issues?state=open"):
    labels = {l["name"] for l in i.get("labels") or []}
    n, title = i["number"], i["title"]
    if "triage" in labels:
        mine.append((n, title, "triage -> investigate and post a plan"))
    elif "execute plan" in labels:
        mine.append((n, title, "execute plan -> build it"))
    elif "fix failed" in labels:
        mine.append((n, title, "fix failed -> re-plan"))
    elif "plan" in labels:
        cs = get(f"/issues/{n}/comments")
        last = cs[-1]["user"]["login"] if cs else None
        if last != ME:
            mine.append((n, title, f"plan -> {last} replied, revise the plan"))
        else:
            theirs.append((n, title, "plan -> awaiting review"))

for tag, rows in (("MINE TO ACTION", mine), ("WITH MATTHEW", theirs)):
    print(f"\n== {tag} ==" if rows else f"\n== {tag} == (none)")
    for n, title, why in rows:
        print(f"  #{n:<3} {title[:44]:<46} {why}")
