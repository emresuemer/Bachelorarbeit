#!/usr/bin/env python3
"""Verify the message you are about to send, by reading it back off the clipboard.

WHY THIS EXISTS. preflight.py and verify_payload.py both check the .do file on
disk. Job 244147 proves that is not the thing that fails: the file was correct,
and what reached DIW was cut mid-observation -- and numbered its observations
differently from the file we sent, which no wrapping model explains. The mail
client is the unverified link, so this checks the text on the other side of it.

THE WORKFLOW IT IS BUILT FOR (do it in this order):

  1. awk '/SEND FROM HERE DOWN/{f=1;next}f' remote/jobs/10_supply_part1.do | pbcopy
  2. paste into a new plain-text message, and type the four header lines above it
  3. click into the message body, Select All, Copy
  4. python3 remote/tools/check_clipboard.py
  5. only if it says SAFE TO SEND, send it

Step 3 is the point. Checking straight after step 1 only proves pbcopy works;
checking after the text has been through the composer is what catches truncation,
re-wrapping, a signature, smart quotes, and non-breaking spaces.

The job file is auto-detected from the `save $mydata/msuemer/...` line, so no
argument is needed. Pass one to be explicit, or --from-file to check a saved
message instead of the clipboard.

This reads the payload back exactly as Stata will and recomputes the checksum
from it, so a match here means the numbers in the composer are the numbers in
macro_data.dta -- not merely that the right file was copied.
"""

import argparse
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_supply_jobs import COLS, JOBS, PRIMES, checksum  # noqa: E402
from preflight import BANNED, tokens  # noqa: E402

MARKER = "SEND FROM HERE DOWN"
HEADER_RE = re.compile(r"\s*\*\s*(user|password|project|package)\s*=", re.I)
SAVE_RE = re.compile(r"save\s+\$mydata/\w+/(\w+)")
# `mi estimate, saving()` writes a .ster file rather than a dataset; it is the
# only thing the 00023-family jobs write, so identification needs it too.
SAVING_RE = re.compile(r"saving\(\$mydata/\w+/(\w+)")

# Where job files live. `jobs/` holds the generated ones; the migrated ports live
# under src/stata/remote/, so both are searched. Add directories here rather than
# moving files back -- an unfindable job silently fails the "job identified" check,
# which is the gate that catches a truncated or wrongly-copied message.
_REPO = Path(__file__).resolve().parents[4]
JOB_DIRS = [JOBS, _REPO / "src/stata/remote"]


def job_files():
    for d in JOB_DIRS:
        if d.is_dir():
            yield from sorted(d.glob("*.do"))


def clipboard():
    try:
        out = subprocess.run(["pbpaste"], capture_output=True, check=True)
    except FileNotFoundError:
        sys.exit("pbpaste not found - this tool assumes macOS. Use --from-file.")
    return out.stdout.decode("utf-8", errors="replace")


def send_block(text):
    idx = text.rfind(MARKER)
    return text[idx + len(MARKER):].lstrip("\n") if idx >= 0 else text


def targets(text):
    """Every dataset name a job writes: `save` AND `mi estimate, saving()`.

    The 00023-family jobs (tab03, tab04, tab05, the three fig02 panels) save
    NO dataset at all -- they only write .ster files through saving(), so
    matching on `save` alone leaves all six indistinguishable.
    """
    return SAVE_RE.findall(text) + SAVING_RE.findall(text)


def find_job(body):
    """Identify the job, so the check needs no argument.

    Preferred tell is what the job writes. A truncated message has lost some
    of those lines -- which is exactly the case that most needs identifying --
    so fall back to the longest matching run of opening lines.

    That fallback USED to compare only the first 8 lines, which silently
    misidentified every 00023-family job: all six open with the same ~60-line
    preamble ($controls_fv, $coeflabels, $table_opt, _mi_addstats) and differ
    only at the model block below it, so the first alphabetically always won.
    Matching the longest common prefix instead lets them separate at the point
    they actually diverge, and an ambiguous best is reported as unidentified
    rather than guessed -- an unidentified job fails the gate, a wrongly
    identified one compares the message against the wrong file.
    """
    names = targets(body)
    if names:
        hits = [p for p in job_files()
                if targets(send_block(p.read_text())) == names]
        if len(hits) == 1:
            return hits[0]

    lines = [l for l in body.split("\n") if l.strip()]
    if len(lines) < 3:
        return None
    best, score = [], 0
    for path in job_files():
        cand = [l for l in send_block(path.read_text()).split("\n") if l.strip()]
        n = 0
        for ours, theirs in zip(lines, cand):
            if ours != theirs:
                break
            n += 1
        if n > score:
            best, score = [path], n
        elif n == score and n:
            best.append(path)
    return best[0] if score >= 3 and len(best) == 1 else None


def expected_row(stem):
    """The count and check that jobs/EXPECTED.txt records for this part."""
    path = JOBS / "EXPECTED.txt"
    if not path.exists():
        return None
    for line in path.read_text().splitlines():
        cells = line.split()
        if len(cells) == 3 and cells[0] == stem and cells[2].isdigit():
            return int(cells[1]), int(cells[2])
    return None


def report(ok, label, detail=""):
    print(f"  {'ok  ' if ok else 'FAIL'} {label}" + (f" -- {detail}" if detail else ""))
    return ok


def check_characters(body):
    """Non-ASCII is fatal (WRONG HEADER), and the usual causes are invisible."""
    bad = {}
    for ch in body:
        if ord(ch) > 126:
            bad.setdefault(ch, 0)
            bad[ch] += 1
    if not bad:
        return report(True, "pure ASCII")
    shown = ", ".join(
        f"U+{ord(c):04X} {unicodedata.name(c, '?')} x{n}" for c, n in bad.items())
    hint = ""
    if any(ord(c) == 0xA0 for c in bad):
        hint = " -- non-breaking space: the composer re-wrapped the text"
    elif any(c in "‘’“”–—" for c in bad):
        hint = " -- smart quotes/dashes: the message is not plain text"
    return report(False, "pure ASCII", shown + hint)


def check_header(lines):
    head = [l for l in lines if HEADER_RE.match(l)]
    if len(head) != 4:
        return report(False, "auth header",
                      f"found {len(head)} of the 4 header lines")
    order = [HEADER_RE.match(l).group(1).lower() for l in head]
    if order != ["user", "password", "project", "package"]:
        return report(False, "auth header",
                      f"order is {'/'.join(order)}, must be "
                      f"user/password/project/package")
    if lines.index(head[0]) != 0:
        return report(False, "auth header",
                      f"starts on line {lines.index(head[0]) + 1}, must be line 1")
    return report(True, "auth header", "4 lines, correct order, at the top")


def check_payload(body, job):
    """Recompute the checksum from the clipboard text, exactly as Stata reads it."""
    lines = body.splitlines()
    if not any(l.startswith("input ") for l in lines):
        # 11/12/13/14 carry no embedded data; there is nothing to checksum
        return report(True, "payload", "no embedded data in this job")
    try:
        start = next(i for i, l in enumerate(lines) if l.startswith("input "))
        stop = next(i for i, l in enumerate(lines) if l.strip() == "end")
    except StopIteration:
        return report(False, "payload", "no complete `input ... end` block - the "
                                        "message is cut off")

    width = len(COLS) + 2
    values = []
    for offset, line in enumerate(lines[start + 1:stop], start=start + 2):
        row = line.split()
        if not row or len(row) % width:
            return report(False, "payload",
                          f"line {offset} holds {len(row)} values, not a multiple "
                          f"of {width} - this is where it was cut")
        values += row

    rows = [values[i:i + width] for i in range(0, len(values), width)]
    got = (len(rows), checksum(rows, ordered=True))

    want = expected_row(job.stem) if job else None
    if want is None:
        return report(True, "payload",
                      f"{got[0]} observations, check {got[1]} "
                      f"(no EXPECTED.txt entry to compare against)")
    if got != want:
        return report(False, "payload",
                      f"count/check {got[0]}/{got[1]}, EXPECTED.txt says "
                      f"{want[0]}/{want[1]}")
    return report(True, "payload",
                  f"{got[0]} observations, check {got[1]} - matches EXPECTED.txt")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("job", nargs="?", help="job file; auto-detected if omitted")
    ap.add_argument("--from-file", help="check this file instead of the clipboard")
    args = ap.parse_args()

    text = (Path(args.from_file).read_text(encoding="utf-8", errors="replace")
            if args.from_file else clipboard())
    if not text.strip():
        sys.exit("clipboard is empty")

    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    while lines and not lines[-1].strip():
        lines.pop()

    # Strip the auth header by matching it, not by assuming four lines: if it is
    # missing or mistyped, dropping four lines blindly would hide the job's own
    # opening lines and every check below would compare the wrong text.
    n_head = 0
    for line in lines[:4]:
        if not HEADER_RE.match(line):
            break
        n_head += 1
    body = "\n".join(lines[n_head:])

    job = Path(args.job) if args.job else find_job(body)
    source = job.read_text(encoding="utf-8") if job else None
    print(f"clipboard: {len(lines)} lines, {len(text)} bytes"
          + (f"  ->  {job.name}" if job else "  ->  job not identified"))

    ok = True
    ok &= check_characters(text)
    ok &= check_header(lines)

    # A body pasted both above and below the header makes the server run the job
    # twice (seen on the Part A run). Counting `use $mydata` openers gives a false
    # positive on any job that legitimately reloads a file it saved earlier --
    # clean_sample.do does exactly that. The unambiguous tell is the job's own
    # FIRST line occurring more than once.
    body_lines = [l.strip() for l in body.split("\n") if l.strip()]
    first = body_lines[0] if body_lines else ""
    openers = body_lines.count(first)
    if openers > 1:
        ok &= report(False, "sent once",
                     f"opening line appears {openers} times - the body is duplicated")
    else:
        ok &= report(True, "sent once")

    if source:
        want = send_block(source).rstrip("\n").split("\n")
        got = body.rstrip("\n").split("\n")
        if got == want:
            ok &= report(True, "identical to the job file", f"{len(want)} lines")
        else:
            n = next((i for i, (a, b) in enumerate(zip(got, want)) if a != b),
                     min(len(got), len(want)))
            if n >= len(got):
                detail = (f"TRUNCATED after body line {n} of {len(want)} - "
                          f"{len(want) - n} lines are missing, starting "
                          f"{want[n]!r}")
            elif n >= len(want):
                detail = (f"{len(got) - n} extra line(s) after the job ends, "
                          f"starting {got[n]!r} - a signature or quoted text")
            else:
                detail = (f"body line {n + 1} of {len(want)} differs: file has "
                          f"{want[n]!r}, message has {got[n]!r}")
            ok &= report(False, "identical to the job file", detail)
    else:
        ok &= report(False, "job identified",
                     "cannot match this against any file in remote/jobs - "
                     "copied from the wrong place, or the opening lines are "
                     "already mangled")

    hits = sorted(tokens(body) & BANNED)
    ok &= report(not hits, "no banned tokens", ", ".join(hits) if hits else "")

    ok &= check_payload(body, job)

    print("\n" + ("SAFE TO SEND" if ok else "DO NOT SEND - fix the FAIL lines above"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
