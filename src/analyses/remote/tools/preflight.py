#!/usr/bin/env python3
"""Pre-flight check for SOEPremote jobs.

Checks the send block of each file for (a) banned whole-word tokens and
(b) non-ASCII characters, both of which get a job rejected outright.

The send block starts after the LAST occurrence of the marker, not the
first: doc headers legitimately mention the marker and the banned words
themselves, and must not be scanned.

Usage:  python3 remote/tools/preflight.py remote/jobs/*.do
"""

import re
import sys
from pathlib import Path

MARKER = "SEND FROM HERE DOWN"

# Table 2 of SOEP Survey Paper 195 (Goebel 2014), plus two tokens the server
# itself named in a rejection, proving the published list is understated:
#
#   typ      2026-08-03, rejecting `place_type` -- ">type/typ< is not allowed",
#            i.e. the blacklist carries stems shorter than the printed words.
#   update   2026-08-30, rejecting `mi update` in ext_asyl_participation.do --
#            ">update< is not allowed ... Updates are only possible for on side
#            administrators". The scanner is guarding the Stata command that
#            updates the installation and cannot see that the `mi` prefix makes
#            it a different, purely local operation. Nothing in the published
#            list hints at it.
#
# Add to this list whenever a rejection names a token, and say which job and
# which date -- that provenance is what stops the list drifting into folklore.
BANNED = set("""cd copy cscript dir do drop file infile keep list log macro mkdir
net print shell ssc sysuse type typ update webuse getfilename""".split())


def send_block(text):
    idx = text.rfind(MARKER)
    if idx < 0:
        return None
    return text[idx + len(MARKER):]


def credentials(text):
    """Flag anything that looks like an auth header pasted into a job file.

    The four header lines belong in the e-mail, not on disk: these files live
    under src/, which is tracked by git. Deleting the marker to make room for
    them also silently disables the banned-token check.
    """
    hits = []
    for i, line in enumerate(text.splitlines(), start=1):
        if re.match(r"\s*\*\s*(user|password|project|package)\s*=", line, re.I):
            hits.append(i)
    return hits


def tokens(text):
    out, word = set(), []
    for ch in text:
        if ch.isalpha():
            word.append(ch.lower())
        elif word:
            out.add("".join(word))
            word = []
    if word:
        out.add("".join(word))
    return out


def main(paths):
    bad = False
    for p in paths:
        text = Path(p).read_text(encoding="utf-8")
        name = Path(p).name

        creds = credentials(text)
        if creds:
            print(f"BAD {name:<26} auth header on line(s) "
                  f"{', '.join(map(str, creds))} - REMOVE IT. Credentials do not "
                  f"belong in a tracked file; type them into the e-mail, or use "
                  f"paste_block.py --with-header")
            bad = True
            continue

        block = send_block(text)
        if block is None:
            print(f"BAD {name:<26} no '{MARKER}' marker - cannot tell which lines "
                  f"are meant to be sent, so nothing was checked")
            bad = True
            continue

        hits = sorted(tokens(block) & BANNED)
        nonascii = sorted({c for c in block if ord(c) > 126})
        lines = block.strip().count("\n") + 1
        longest = max((len(l) for l in block.splitlines()), default=0)
        status = "OK " if not (hits or nonascii) else "BAD"
        if hits or nonascii:
            bad = True
        print(f"{status} {name:<26} {lines:>4} lines  "
              f"longest {longest:>4}  {len(block):>7,} bytes"
              + (f"  banned={hits}" if hits else "")
              + (f"  nonascii={nonascii}" if nonascii else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or sorted(Path("remote/jobs").glob("*.do"))))
