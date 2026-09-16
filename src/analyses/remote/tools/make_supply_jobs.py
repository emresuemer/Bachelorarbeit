#!/usr/bin/env python3
"""Generate SOEPremote `input` jobs carrying the county-year macro panel.

SOEPremote refuses e-mail attachments (SOEP Survey Paper 195, sec. 3.3); the only
sanctioned route for external data is an in-job `input ... end` block. This script
turns savedata/macro_data.dta into a small number of such jobs.

Two things keep the payload manageable:

  * only the 12 columns that any downstream regression actually reads are sent
    (traced through 00013 -> 00014 -> 00022/00023/00024), not all 57;
  * every value is scaled to an integer and rescaled inside the job, which is
    both shorter than decimal text and exactly reproducible.

`concern_immigration` and `volunt` are deliberately absent: they are built from
SOEP pl.dta collapsed to county-year, so they cannot come from here at all. They
are produced remotely by 12_soepvars_remote.do.

Run from src/analyses/:  python3 remote/tools/make_supply_jobs.py
"""

import argparse
import re
import sys
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
REMOTE = HERE.parent
JOBS = REMOTE / "jobs"
SRC = REMOTE.parent / "savedata" / "macro_data.dta"

# variable -> integer scale factor applied before transmission. Chosen so the
# round-trip error stays under 1e-3 of each variable's own standard deviation,
# which is the tolerance verify_payload.py enforces against the source file.
# Measured worst case is 8.9e-04 sd on afd_votes; most columns are exact.
COLS = {
    "course_opport": 100_000,
    "foreign_share": 100,
    "reg_unemplrate": 100,
    "reg_density": 100,
    "tax": 100,
    "gdp_per_resident": 1,
    "refugee": 1,
    "hospital_bet2012": 100,
    "land_cons": 100,
    "vac_hous": 100,
    "afd_votes": 100,
    "cdu_csu_votes": 100,
}

YEAR_BASE = 2010          # years are sent as single digits: 2013 -> 3

# DIW support (Antonia Meier, SOEP Community Management, 2026-08-07) states the
# hard constraint outright: "Die maximale Zeilenanzahl pro E-Mail sollte bei etwa
# 200 bis 250 liegen". Everything below follows from that number. Jobs are sized
# by LINE BUDGET, and the number of parts falls out of it -- the previous
# fixed --parts 4 produced 756-line jobs, three times over the limit, and part 1
# was silently cut mid-observation on job 244147.
MAX_LINES_DEFAULT = 190

# Observations packed onto one physical data line. 1 is the only value that is
# safe when the job is pasted into a mail client, because packing makes lines
# longer than the ~78-character point at which plain-text mail is re-wrapped,
# and a wrap landing inside a number corrupts the payload silently.
# Raise it only with (a) local proof that `input` reads several observations per
# line -- see tools/local_input_probe.do -- and (b) programmatic sending via
# send_job.py, which forces 7bit and never re-wraps.
OBS_PER_LINE_DEFAULT = 1

# Longest acceptable data line. 72 keeps one observation clear of every mail
# client's wrap point; the check exists so a scale factor cannot silently push
# lines past it.
WRAP_DEFAULT = 72

# Table 2 of SOEP Survey Paper 195, plus the `typ` stem the server itself named
# when it rejected place_type. Matched as whole tokens, letters only.
# Single source of truth, so a token learned from a rejection reaches every
# generator at once. It gained `update` on 2026-08-30; see preflight.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from preflight import BANNED  # noqa: E402

MARKER = "* SEND FROM HERE DOWN"


def encode(value, scale):
    if pd.isna(value):
        return "."
    return str(int(round(float(value) * scale)))


def preflight(text):
    """Return banned whole-word tokens appearing below the send marker."""
    body = text.split(MARKER, 1)[1] if MARKER in text else text
    tokens = set()
    word = []
    for ch in body:
        if ch.isalpha():
            word.append(ch.lower())
        elif word:
            tokens.add("".join(word))
            word = []
    if word:
        tokens.add("".join(word))
    return sorted(tokens & BANNED)


# Distinct primes, one per transmitted column, so that a value landing in the
# wrong column changes the checksum. All arithmetic stays in exact integers:
# the transmitted values ARE integers, and the totals below are checked against
# 2**53, inside which a Stata double is exact.
PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43]


def checksum(rows, ordered):
    """Reproduce, in exact Python integers, what the job computes in Stata.

    ordered=True weights each observation by its position, so a shifted or
    dropped value changes the total even if the multiset of values does not.
    """
    total = 0
    for i, row in enumerate(rows, start=1):
        acc = sum(p * (0 if v == "." else int(v)) for p, v in zip(PRIMES, row))
        total += acc * i if ordered else acc
    assert total < 2 ** 53, "checksum exceeds exact double range"
    return total


def checksum_stata(varnames, ordered):
    """The same sum, as Stata lines. Missing counts as 0, matching checksum().

    Terms are packed several to a line, up to 68 characters, rather than one per
    line: the line budget is the scarce resource now, and 68 is still clear of
    any mail client's wrap point.
    """
    terms = [f"{p}*cond(missing({v}),0,{v})" for p, v in zip(PRIMES, varnames)]
    lead = "gen double zc = " + ("_n*(" if ordered else "(")
    # the trailing "+" must sit BEFORE the continuation, or Stata silently reads
    # each wrapped chunk as a new expression and the sum is wrong
    lines, cur = [], lead
    for i, term in enumerate(terms):
        last = i == len(terms) - 1
        piece = term + (")" if last else " + ")
        if len(cur) + len(piece) > 68 and cur not in (lead, "    "):
            lines.append(cur.rstrip() + " ///")
            cur = "    "
        cur += piece
    lines.append(cur)
    return lines


def wrap_tokens(rows, width, per_line):
    """Lay the encoded rows out as data lines, `per_line` observations each.

    per_line=1 is the safe default: `input` unambiguously accepts one whole
    observation per physical line, and a 72-character line cannot be re-wrapped
    by a mail client. Values above 1 shorten the job but rely on `input` reading
    free-format across observations -- prove that locally with
    tools/local_input_probe.do before using them, and send with send_job.py.

    A line holding fewer values than the varlist fails with "'' cannot be read
    as a number"; that is exactly how job 244147 ended, its last line cut in
    half in transit.
    """
    lines = []
    for i in range(0, len(rows), per_line):
        lines.append(" ".join(" ".join(r) for r in rows[i:i + per_line]))
    longest = max(len(l) for l in lines)
    if longest > width:
        sys.exit(f"longest data line is {longest} chars, over the {width} limit - "
                 f"lower --obs-per-line or reduce a scale factor in COLS")
    return lines


def build_job(part, rows, total_parts, width, per_line):
    # Values are read into single-letter placeholders and renamed afterwards.
    # Spelling the twelve real names on the `input` line would make it ~160
    # characters, and that one line is the only place a mail client's hard wrap
    # could do real damage: a break there turns the remaining names into what
    # Stata reads as data. Short placeholders keep it under 50 characters.
    # `double` is declared once and applies to the whole varlist; the values
    # arrive as scaled integers and are divided back down below, which would
    # truncate in an integer storage type.
    letters = "abcdefghijkl"[:len(COLS)]
    head = [
        MARKER,
        "clear",
        "input double kkz yr " + " ".join(letters),
    ]
    # rename in groups of four: one line per variable cost 12 lines out of a
    # ~190-line budget, which is ~90 county-years of payload per job
    groups = [(letters[i:i + 4], list(COLS)[i:i + 4]) for i in range(0, len(COLS), 4)]
    data = wrap_tokens(rows, width, per_line)

    # the checksum runs FIRST, while the values are still the exact integers that
    # were transmitted - after the rescaling below they are no longer integers
    tail = ["end"]
    tail += checksum_stata(["kkz", "yr"] + list(letters), ordered=True)
    tail += [
        "summarize zc, meanonly",
        f'display "part {part} count " %12.0f r(N)',
        f'display "part {part} check " %20.0f r(sum)',
        "soepdrop zc",
    ]
    tail += [f"rename ({' '.join(g)}) ({' '.join(n)})" for g, n in groups]
    tail += [
        "gen int year = yr + %d" % YEAR_BASE,
        "soepdrop yr",
    ]
    # macro_data is already harmonised to the post-reform codes, so no recode here;
    # 00013 recodes the SOEP side before merging
    for name, scale in COLS.items():
        if scale != 1:
            tail.append(f"replace {name} = {name}/{scale}")
    tail += [
        "isid kkz year",
        f"save $mydata/msuemer/supply_p{part}, replace",
        f'display "part {part} of {total_parts} ok"',
    ]
    return "\n".join(head + data + tail) + "\n"


def overhead(total_parts, per_line):
    """Lines a job spends on everything except data. Sizing needs this first."""
    probe = build_job(total_parts, [["0"] * (len(COLS) + 2)], total_parts,
                      10 ** 6, per_line)
    return probe.count("\n") - 1


def build_stack(total_parts, nobs):
    """The job that puts the parts back together, generated so it cannot drift.

    Splitting by line budget means the number of parts changes whenever the
    budget or the encoding does. Hand-maintaining the append list is exactly the
    kind of thing that silently loses a part, so it is emitted from the same
    loop that writes them.
    """
    head = [
        "* ======================================================================",
        "* STACK THE TRANSMITTED SUPPLY PARTS -- GENERATED, DO NOT EDIT BY HAND",
        "* Regenerate with: python3 remote/tools/make_supply_jobs.py",
        "* DOCUMENTATION -- DO NOT SEND THIS HEADER",
        "* ======================================================================",
        "* Send after all %d parts have returned, and only once every one of them"
        % total_parts,
        "* has shown its own count and check line matching jobs/EXPECTED.txt.",
        "* A part that truncated in transit still reports `end of do-file`, so the",
        "* absence of a complaint here proves nothing on its own.",
        "*",
        "* Produces $mydata/msuemer/supply_all.dta, the input to",
        "* 13_supply_assemble.do. Must report exactly %d observations." % nobs,
        "* ======================================================================",
        "",
        MARKER,
        "use $mydata/msuemer/supply_p1, clear",
    ]
    body = [f"append using $mydata/msuemer/supply_p{p}"
            for p in range(2, total_parts + 1)]
    tail = [
        "isid kkz year",
        "count",
        "tabulate year",
        "save $mydata/msuemer/supply_all, replace",
        'display "stack ok"',
    ]
    return "\n".join(head + body + tail) + "\n"


ASSEMBLE = "13_supply_assemble.do"


def assemble_scales():
    """Read 13's checksum factors out of 13 itself, rather than assuming them.

    13 is hand-maintained (the 9561/9571 recode and the two job-12 merges are
    not generated), and its checksum expression rescales each column back to an
    integer with factors of its own. Those drifted from COLS -- `course_opport`
    x1e6 against a x1e5 payload, `hospital_bet2012` x1e4 against x1e2 -- so the
    number EXPECTED.txt predicted could never match the number the server
    computed, and the first real run of 13 looked like a corrupted panel when
    the data was in fact exact.

    Deriving the prediction from the job text removes the second source of
    truth. If the expression is edited, the expected value follows.
    """
    text = (JOBS / ASSEMBLE).read_text(encoding="utf-8")
    text = text.split(MARKER, 1)[1] if MARKER in text else text
    scales = {}
    for name in COLS:
        rounded = re.search(rf"cond\(missing\({name}\),0,round\({name}\*(\d+)\)\)", text)
        plain = re.search(rf"cond\(missing\({name}\),0,{name}\)", text)
        if rounded:
            scales[name] = int(rounded.group(1))
        elif plain:
            scales[name] = 1
        else:
            sys.exit(f"{ASSEMBLE}: no checksum term found for {name}")
    return scales


def assemble_checksum(rows, scales):
    """What 13 will compute, in exact integers.

    A transmitted value is `int / COLS[name]`, and 13 rounds `value * scales
    [name]` back to an integer, so the contribution is `int * (scales/COLS)`
    exactly -- no floating point, provided the ratio is whole.
    """
    total = 0
    for row in rows:
        acc = PRIMES[0] * int(row[0]) + PRIMES[1] * int(row[1])
        for i, (p, (name, scale)) in enumerate(zip(PRIMES[2:], COLS.items()), start=2):
            if scales[name] % scale:
                sys.exit(f"{ASSEMBLE}: {name} is rescaled by {scales[name]}, which "
                         f"is not a multiple of the transmitted scale {scale} - "
                         f"the check cannot be predicted exactly")
            acc += p * (0 if row[i] == "." else int(row[i]) * (scales[name] // scale))
        total += acc
    assert total < 2 ** 53, "checksum exceeds exact double range"
    return total


def write_expected(written, encoded):
    """The numbers each returned listing must show. Checked by eye, one line each."""
    lines = [
        "EXPECTED SOEPremote OUTPUT - generated by make_supply_jobs.py",
        "=" * 62,
        "",
        "Compare every returned listing against these. A mismatch on ANY line",
        "means that job did not arrive intact: regenerate nothing, just resend",
        f"that one part and check again. Do not send 11_supply_stack until all",
        f"{len(written)} parts match.",
        "",
        "The check number is an exact integer: each transmitted value times a",
        "distinct prime for its column, times its row position, summed. Any",
        "value that is dropped, duplicated, altered or shifted into the wrong",
        "column changes it.",
        "",
        f"{'job':<24}{'count':>8}{'check':>22}",
        "-" * 54,
    ]
    for path, nobs, _text, chk in written:
        lines.append(f"{path.stem:<24}{nobs:>8}{chk:>22}")
    lines += [
        "-" * 54,
        f"{'11_supply_stack':<24}{len(encoded):>8}{'-':>22}",
        f"{'13_supply_assemble':<24}{len(encoded):>8}"
        f"{assemble_checksum(encoded, assemble_scales()):>22}",
        "",
        "13's check is order-independent (append and merge re-sort the data),",
        f"so it verifies all {len(written)} parts are present and none is",
        f"duplicated. 11 and 13 must both report {len(encoded)} observations",
        "and pass isid kkz year.",
    ]
    (JOBS / "EXPECTED.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--max-lines", type=int, default=MAX_LINES_DEFAULT,
                    help="line budget per job (DIW's stated ceiling is 200-250)")
    ap.add_argument("--obs-per-line", type=int, default=OBS_PER_LINE_DEFAULT,
                    help="observations per data line; >1 needs free-format "
                         "`input` and programmatic sending")
    ap.add_argument("--wrap", type=int, default=None,
                    help="max characters per data line "
                         f"(default {WRAP_DEFAULT} per packed observation)")
    ap.add_argument("--parts", type=int, default=None,
                    help="override the part count derived from --max-lines")
    args = ap.parse_args()

    if not SRC.exists():
        sys.exit(f"missing {SRC} - run 00011_data_macro.do first")

    wrap = args.wrap or WRAP_DEFAULT * args.obs_per_line

    frame = pd.read_stata(SRC)
    frame = frame.sort_values(["year", "kkz"])

    encoded = []
    for _, r in frame.iterrows():
        encoded.append(
            [str(int(r["kkz"])), str(int(r["year"]) - YEAR_BASE)]
            + [encode(r[c], s) for c, s in COLS.items()]
        )

    # Size the split from the line budget rather than fixing the part count:
    # the budget is the real constraint, and the arithmetic below is what job
    # 244147 got wrong. `overhead` depends only weakly on the part count (the
    # digits in "part N of M"), so one pass with a pessimistic guess is enough.
    per_line = args.obs_per_line
    if args.parts:
        parts = args.parts
    else:
        budget = args.max_lines - overhead(99, per_line)
        if budget < 1:
            sys.exit(f"--max-lines {args.max_lines} leaves no room for data")
        parts = -(-len(encoded) // (budget * per_line))

    JOBS.mkdir(parents=True, exist_ok=True)
    for stale in JOBS.glob("10_supply_part*.do"):
        stale.unlink()

    size = -(-len(encoded) // parts)
    written = []
    for part in range(1, parts + 1):
        chunk = encoded[(part - 1) * size: part * size]
        if not chunk:
            continue
        text = build_job(part, chunk, parts, wrap, per_line)
        hits = preflight(text)
        if hits:
            sys.exit(f"part {part}: banned tokens in send block: {hits}")
        path = JOBS / f"10_supply_part{part}.do"
        path.write_text(text, encoding="ascii")
        written.append((path, len(chunk), text, checksum(chunk, ordered=True)))

    (JOBS / "11_supply_stack.do").write_text(
        build_stack(len(written), len(encoded)), encoding="ascii")
    write_expected(written, encoded)

    print(f"{len(frame)} county-years, {len(COLS)} variables, "
          f"{per_line} obs/line, budget {args.max_lines} lines\n")
    over = 0
    for path, nobs, text, _chk in written:
        lines = text.count("\n")
        longest = max(len(l) for l in text.splitlines())
        over += lines > args.max_lines
        print(f"  {path.name}: {nobs:>4} obs  {lines:>4} lines  "
              f"{len(text):>7,} bytes  longest line {longest}")
    if over:
        sys.exit(f"\n{over} job(s) over the {args.max_lines}-line budget")
    print(f"\npreflight clean; send the {len(written)} parts (they are "
          f"independent), verify each against jobs/EXPECTED.txt, then\n"
          f"11_supply_stack.do, 12_soepvars_remote.do, 13_supply_assemble.do")


if __name__ == "__main__":
    main()
