#!/usr/bin/env python3
"""Resolve outdated GitHub PR review threads.

Requires GitHub CLI (`gh`) authenticated with repo access. The script is dry-run
by default and only mutates GitHub when --resolve is passed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Any


QUERY = """
query($owner:String!,$repo:String!,$number:Int!,$limit:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:$limit) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first:10) {
            nodes {
              author { login }
              body
              url
              outdated
              path
              line
              originalLine
            }
          }
        }
      }
    }
  }
}
"""


MUTATION = """
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread {
      id
      isResolved
    }
  }
}
"""


@dataclass
class ThreadSummary:
    id: str
    is_resolved: bool
    is_outdated: bool
    path: str
    line: int | None
    original_line: int | None
    author: str
    url: str
    body: str


def run_gh_graphql(fields: dict[str, str]) -> dict[str, Any]:
    cmd = ["gh", "api", "graphql"]
    for key, value in fields.items():
        flag = "-F" if key in {"number", "limit"} else "-f"
        cmd.extend([flag, f"{key}={value}"])
    completed = subprocess.run(
        cmd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or completed.stdout.strip())
    return json.loads(completed.stdout)


def parse_repo(repo: str) -> tuple[str, str]:
    parts = repo.split("/")
    if len(parts) != 2 or not all(parts):
        raise ValueError("--repo must be in OWNER/REPO form")
    return parts[0], parts[1]


def fetch_threads(repo: str, pr: int, limit: int) -> list[ThreadSummary]:
    owner, name = parse_repo(repo)
    payload = run_gh_graphql(
        {
            "owner": owner,
            "repo": name,
            "number": str(pr),
            "limit": str(limit),
            "query": QUERY,
        }
    )
    pr_data = payload["data"]["repository"]["pullRequest"]
    if pr_data is None:
        raise RuntimeError(f"PR #{pr} not found in {repo}")

    result: list[ThreadSummary] = []
    for node in pr_data["reviewThreads"]["nodes"]:
        comments = node["comments"]["nodes"]
        first = comments[0] if comments else {}
        body = " ".join((first.get("body") or "").split())
        result.append(
            ThreadSummary(
                id=node["id"],
                is_resolved=bool(node["isResolved"]),
                is_outdated=bool(node["isOutdated"]),
                path=node.get("path") or first.get("path") or "(unknown)",
                line=node.get("line"),
                original_line=node.get("originalLine"),
                author=((first.get("author") or {}).get("login") or "(unknown)"),
                url=first.get("url") or "",
                body=body[:180],
            )
        )
    return result


def resolve_thread(thread_id: str) -> None:
    run_gh_graphql({"threadId": thread_id, "query": MUTATION})


def format_location(thread: ThreadSummary) -> str:
    line = thread.line if thread.line is not None else thread.original_line
    return f"{thread.path}:{line}" if line is not None else thread.path


def print_group(title: str, threads: list[ThreadSummary]) -> None:
    print(f"\n{title}: {len(threads)}")
    for thread in threads:
        print(f"- {format_location(thread)}")
        print(f"  author: {thread.author}")
        print(f"  url: {thread.url}")
        if thread.body:
            print(f"  body: {thread.body}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="List or resolve outdated GitHub PR review threads."
    )
    parser.add_argument("--repo", required=True, help="GitHub repo, e.g. owner/name")
    parser.add_argument("--pr", required=True, type=int, help="Pull request number")
    parser.add_argument("--limit", default=100, type=int, help="Thread fetch limit")
    parser.add_argument(
        "--resolve",
        action="store_true",
        help="Resolve outdated unresolved threads. Omit for dry-run.",
    )
    args = parser.parse_args()

    try:
        threads = fetch_threads(args.repo, args.pr, args.limit)
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        return 1

    outdated = [
        thread for thread in threads if thread.is_outdated and not thread.is_resolved
    ]
    current = [
        thread for thread in threads if not thread.is_outdated and not thread.is_resolved
    ]
    resolved = [thread for thread in threads if thread.is_resolved]

    print(f"PR: {args.repo}#{args.pr}")
    print(f"mode: {'resolve' if args.resolve else 'dry-run'}")
    print(f"threads fetched: {len(threads)}")
    print_group("outdated unresolved candidates", outdated)
    print_group("current unresolved threads left alone", current)
    print_group("already resolved threads", resolved)

    if not args.resolve:
        print("\nNo changes made. Re-run with --resolve to resolve candidates.")
        return 0

    failures = 0
    for thread in outdated:
        try:
            resolve_thread(thread.id)
            print(f"resolved: {format_location(thread)}")
        except Exception as exc:  # noqa: BLE001
            failures += 1
            print(f"failed: {format_location(thread)}: {exc}", file=sys.stderr)

    print(f"\nresolved count: {len(outdated) - failures}")
    if failures:
        print(f"failed count: {failures}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
