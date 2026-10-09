"""Gitea milestone sweep: which milestones can be planned, and whose turn each is.

Usage: milestones.py <owner>/<repo> [<owner>/<repo> ...]
       milestones.py --org <organisation>        (every repo with open milestones)
"""
import json, os, sys, urllib.request


def env(key):
    """GITEA_* since 2026-10-09; GOGS_* kept as fallback for machines not yet updated."""
    return os.environ.get("GITEA_" + key) or os.environ["GOGS_" + key]


ME = "claude"
ROOT = env("URL") + "/api/v1"


def get(path):
    r = urllib.request.Request(ROOT + path,
                               headers={"Authorization": "token " + env("TOKEN")})
    return json.load(urllib.request.urlopen(r))


def verdict(ms, issues, blocking):
    """(whose, why) for one open milestone. blocking = title of the open milestone before it."""
    if blocking:
        return "BLOCKED", f"waits on {blocking}"
    if not issues:
        return "PLANNABLE", "no issue yet -> raise one on triage and plan it"
    labels = set()
    for i in issues:
        labels |= {l["name"] for l in i.get("labels") or []}
    n = issues[0]["number"]
    if "triage" in labels:
        return "PLANNABLE", f"#{n} on triage -> investigate and post a plan"
    if "execute plan" in labels:
        return "MINE", f"#{n} on execute plan -> build it"
    if "fix failed" in labels:
        return "MINE", f"#{n} on fix failed -> re-plan"
    if "plan" in labels:
        cs = get(f"/repos/{ms['repo']}/issues/{n}/comments")
        last = cs[-1]["user"]["login"] if cs else None
        if last != ME:
            return "MINE", f"#{n} on plan -> {last} replied, revise the plan"
        return "MATTHEW", f"#{n} on plan -> awaiting review"
    if "fixed" in labels:
        return "MATTHEW", f"#{n} fixed -> close it to advance the milestone"
    return "MINE", f"#{n} has no workflow label"


def sweep(repo):
    milestones = sorted(get(f"/repos/{repo}/milestones?state=all"), key=lambda m: m["id"])
    if not milestones:
        return []
    by_milestone = {}
    for i in get(f"/repos/{repo}/issues?state=all&limit=100"):
        m = i.get("milestone")
        if m:
            by_milestone.setdefault(m["id"], []).append(i)

    rows, blocking = [], None
    for m in milestones:
        if m["state"] != "open":
            continue
        m["repo"] = repo
        issues = by_milestone.get(m["id"], [])
        whose, why = verdict(m, issues, blocking)
        rows.append((repo, m["title"], whose, why,
                     f"{m['closed_issues']}/{m['closed_issues'] + m['open_issues']} issues closed"))
        if blocking is None:
            blocking = m["title"]      # the first open milestone blocks every later one
    return rows


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--org":
        # /orgs/<org>/repos needs the `organization` token scope, which this token hasn't;
        # /user/repos returns the same repos (everything claude can reach) and needs none.
        org = sys.argv[2].lower()
        repos = [r["full_name"] for r in get("/user/repos?limit=100")
                 if r["owner"]["login"].lower() == org]
    elif len(sys.argv) > 1:
        repos = sys.argv[1:]
    else:
        sys.exit(__doc__)

    rows = []
    for repo in repos:
        rows += sweep(repo)

    order = {"PLANNABLE": 0, "MINE": 1, "MATTHEW": 2, "BLOCKED": 3}
    for tag in order:
        here = [r for r in rows if r[2] == tag]
        print(f"\n== {tag} ==" if here else f"\n== {tag} == (none)")
        for repo, title, _, why, progress in here:
            print(f"  {repo:<34} {title[:40]:<42} {why}")
            if tag != "BLOCKED":
                print(f"  {'':<34} {'':<42} {progress}")


main()
