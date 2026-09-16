# The county-year panel transfer: 22 jobs that put `macro_data.dta` on the DIW server

**Status: done 2026-08-07.** `$mydata/msuemer/cty_supply.dta` exists on the SOEPremote
server with 2,807 county-years × 16 variables, 401 counties in every year 2013–2019,
`isid kkz year` passing (re-verified by `verify_server_state.do`, 2026-08-13). It is
read by `src/stata/remote/clean_county_merge.do` and is the source of the paper's
treatment variable. This file explains how the transfer works, how each step was
verified, and how to repeat it.

Written for sending by hand from a mail client; the two programmatic senders that once
accompanied it were never used and have been removed.

---

## The logic in one page

**The problem.** `00013_data_clean.do` merges a county-year file built locally by
`00011_data_macro.do`. That file has to be on DIW's server, but SOEPremote refuses
e-mail attachments; the only sanctioned route for external data is an in-job
`input ... end` block (SOEP Survey Paper 195, §3.3).

**Why that is feasible.** Three things shrink the payload:

1. **12 columns, not 57.** Tracing `00013` → `00014` → `00022`/`00023`/`00024`, only
   twelve county-year variables are ever read again. The other 45 are inert after
   `keep $vars`.
2. **Scaled integers.** Every value is multiplied by a fixed factor, sent as an
   integer, and divided back down inside the job. Shorter than decimal text, and
   exactly reproducible.
3. **A split into 18 jobs of at most 190 lines each**, the size DIW's own support
   states a job may be (below).

**Why two columns cannot be sent at all.** `concern_immigration` and `volunt` are built
by collapsing SOEP `pl.dta` by county, so on the local EU edition (where `kkz` is `-7`
everywhere) they are 100% missing. There is nothing to embed. Job `12` recomputes them
on the server instead. This matters: `concern_immigration` becomes `z_consimmi`, a
control in every main specification of `00023`.

**At most 190 lines per job: the hard constraint, stated by DIW.** SOEP Community
Management (Antonia Meier, 2026-08-07), answering the question directly:

> Die maximale Zeilenanzahl pro E-Mail sollte bei etwa 200 bis 250 liegen, daher
> sollten Sie bitte ihre Eingabe in mehrere Teile bzw. E-Mails aufteilen.

An earlier four-job split produced 756-line jobs. Job 244147 (`10_supply_part1`) was
cut mid-observation in transit and died on `'' cannot be read as a number` /
`unexpected end of file`, having saved nothing. The part count is therefore *derived*
from the line budget in `make_supply_jobs.py` rather than fixed.

**One observation per line, every line at most 72 characters.** A line holding fewer
values than the varlist fails with `'' cannot be read as a number`, so observations are
never split across lines. 72 characters keeps every line below the ~76-character point
where mail clients hard-wrap plain text, which would otherwise break a number in half.
The only lever for line length is the scale factors, which is why they are as coarse as
accuracy allows. (Packing several observations per line would have cut the job count to
about five, but whether `input` reads free-format across observations was never
established, and eighteen jobs cost sending effort rather than calendar time.)

**Why the checksum exists.** A truncated job looks exactly like a short job that
succeeded: SOEPremote runs whatever arrives and prints `end of do-file`. Three earlier
attempts at a 376-line job were silently cut at about 340, 340 and 190 lines. The
checksum turns that from invisible into obvious.

---

## The 22 jobs

| Order | File | What it does |
|---|---|---|
| 1–18 | `10_supply_part1.do` … `10_supply_part18.do` | 156 county-years each (155 in the last), 12 variables → `supply_p1` … `supply_p18` |
| 19 | `12_soepvars_remote.do` | builds `concern_immigration` + `volunt` from SOEP → `soep_xeno`, `soep_volunt` |
| 20 | `11_supply_stack.do` | appends the 18 parts → `supply_all` |
| 21 | `13_supply_assemble.do` | merges `supply_all` with 19 → **`cty_supply.dta`** |
| 22 | `14_supply_check.do` | opens `cty_supply` in a fresh session to prove it is there |

Jobs 1–19 are independent of each other: send all nineteen, then wait once. Only 20
depends on them, 21 on 20, and 22 on 21. That is four round trips, not twenty-two.

`10_supply_part*.do`, `11_supply_stack.do` and `EXPECTED.txt` are generated together by
`make_supply_jobs.py`, so the append list and the expected numbers can never fall out
of step with the parts on disk. They are not edited by hand.

---

## Mail client settings

Send to **`soep-exec@diw.de`**. The subject can be anything (`10 supply part 1`).

- **Plain text, not HTML.** Apple Mail: *Format → Make Plain Text*. Outlook:
  *Format Text → Plain Text*.
- **No signature.** A university signature is the most likely source of two fatal
  problems at once: German umlauts (`Universität`) break the job with a `WRONG HEADER`
  error, because the system needs pure ASCII, and ordinary words in it can hit the
  banned-token list.
- **A fresh message every time.** Replying inside an existing thread includes the
  quoted text in the job.
- **No "wrap text at N characters" setting**, if the client has one.

> **The four header lines never go into a `.do` file.** These files live under `src/`,
> which git tracks, so the password would end up in the repository; it would also
> overwrite the `SEND FROM HERE DOWN` marker, which silently disables the banned-token
> check. `preflight.py` refuses both. The header is typed into the e-mail.

---

## Step by step

### Step 0: check the jobs (no credentials needed)

```bash
python3 src/analyses/remote/tools/preflight.py src/analyses/remote/jobs/*.do
```

Every line must say `OK`, `lines` must be at most 190, and `longest` at most 73. This
checks for banned tokens and non-ASCII characters, either of which gets a job rejected
outright.

### Step 1: compose, verify what is actually in the composer, then send

Step 0 checks the file on disk. That is not what fails. Job 244147's file was correct;
what reached DIW was cut mid-observation, and had renumbered its observations in a way
no wrapping model explains. The mail client is the unverified link, so the check has to
read the text on the far side of it; that is what `check_clipboard.py` is for.

For each of the nineteen jobs:

```bash
# 1. put exactly the send block on the clipboard (never the whole .do file;
#    the documentation header is not meant to be sent)
awk '/SEND FROM HERE DOWN/{f=1;next}f' src/analyses/remote/jobs/10_supply_part1.do | pbcopy
```

2. New plain-text message to `soep-exec@diw.de`. Type these four lines first:

```
*user     = <username>
*password = <password>
*project  = <project>
*package  = STATA
```

Single `*`, and project before package; this is the format the server's own bounce
echoed back, not the one in the 2014 job-submission paper. Paste the job below the
header.

3. Click into the message body, Select All, Copy. This is the whole point: the
   clipboard now holds what the composer actually contains, not what was meant to be
   there.

```bash
# 4. verify it
python3 src/analyses/remote/tools/check_clipboard.py
```

5. Send only if it prints `SAFE TO SEND`.

Repeat for `part2` … `part18` and `12_soepvars_remote.do`. A clean run looks like this:

```
clipboard: 193 lines, 11599 bytes  ->  10_supply_part1.do
  ok   pure ASCII
  ok   auth header -- 4 lines, correct order, at the top
  ok   sent once
  ok   identical to the job file -- 189 lines
  ok   no banned tokens
  ok   payload -- 156 observations, check 37252452009 - matches EXPECTED.txt

SAFE TO SEND
```

The last line is the strong one: it re-reads the numbers out of the composer, exactly
as Stata will, and recomputes the checksum from them. A match means the values about to
be sent are the values in `macro_data.dta`, not merely that the right file was copied.
The checks catch, in order: umlauts and non-breaking spaces from a signature or a
re-wrap; a missing or mis-ordered header; a body pasted twice (which makes the server
run the job twice); truncation, naming the line it was cut at; any altered digit; and
trailing quoted text. Sending from a different machine or client means repeating steps
3–4 there.

### Step 2: check the nineteen listings (about an hour later)

For each part, find these two lines and compare them against `EXPECTED.txt`:

```
part 1 count            156
part 1 check    37252452009
```

`EXPECTED.txt` is regenerated with the jobs, so it is the authority, never a table
copied into prose. Also confirm each listing contains its
`file /srv/cifs/lissy-users-data/msuemer/supply_pN.dta saved` line.

For job 12, confirm: both `isid kkz year` checks pass, each `count` after `collapse` is
in the low thousands (roughly 400 counties × 7 years), and both `soep_xeno.dta` and
`soep_volunt.dta` report `saved`. A count in the hundreds means the `regionl` merge
failed.

### Step 3: send job 20, then job 21

Only once all nineteen above are clean. Same compose → Select All → Copy →
`check_clipboard.py` loop as step 1.

`11_supply_stack.do` must report **2,807** observations, `isid kkz year` passing,
**401 per year for 2013–2019**, and `supply_all.dta saved`. Anything less means a part
is missing or truncated on the server. This happened on the first run: `supply_p13`
had never been saved, `append` hit `r(601)`, and because runtime errors do not halt a
job it carried on and saved a 2,651-row file that passed `isid`. `tabulate year` was
the only tell (2017 short by 133, 2018 by 23, exactly part 13's composition).

`13_supply_assemble.do` must show

```
assembled count          2807
assembled check   34674005709
```

plus `isid kkz year` passing and `cty_supply.dta saved`. The check number comes from
`EXPECTED.txt`: job 13's checksum expression rescales each column with factors of its
own, which are not the transmitted scale factors, and `make_supply_jobs.py` parses
those factors out of `13_supply_assemble.do` to derive the prediction. They were once
maintained separately, which made the first correct run of 13 look like a corrupted
panel.

Both merges against job 12 report `Not matched … from using 1`. That one row is a
county-year SOEP has and the macro panel does not; `soepkeep if _merge != 2` drops it
by design. Anything larger from `using` means parts are missing.

### Step 4: send job 22

`14_supply_check.do` opens the file in a fresh session. **2,807 observations, 16
variables, 401 per year for 2013–2019** is the proof that the panel is on the account
and readable by everything downstream.

---

## What the check number means

Each part job computes, while the values are still exact integers, the sum over rows of
(row position × Σ prime<sub>column</sub> × value). Every column gets its own prime and
every row its own weight, so a value that is dropped, duplicated, altered, or shifted
into the wrong column changes the total. All arithmetic stays under 2⁵³, where a Stata
double is exact, so there is no floating-point ambiguity.

A plain observation count is not enough on its own: a shifted value leaves the row count
intact. That is why both numbers are checked. Job 13's check is order-independent
(append and merge re-sort the data), so it verifies that all 18 parts are present and
none was duplicated.

---

## If something does not match

- **A count or check is wrong**: that job did not arrive intact. Resend that one file
  and check again; the other parts are unaffected.
- **The same part truncates twice**: lower the line budget and resend all of them
  (`make_supply_jobs.py --max-lines 120`). The part count follows from the budget. This
  rewrites the parts, `11_supply_stack.do` and `EXPECTED.txt`; run `verify_payload.py`
  and `preflight.py` afterwards and use the new expected values.
- **A blank "was rejected" with no detail**: resend once before assuming anything about
  the content. Real content rejections name the offending token; blank bounces have
  turned out to be transient.
- **The listing shows the job running twice**: the e-mail contained the body both above
  and below the auth header.
- **`WRONG HEADER`**: a non-ASCII character somewhere in the message, usually an umlaut
  in a signature, or mistyped header lines.
- **Job 11 or 13 reports fewer than 2,807 observations**: one part is missing or
  truncated on the server. Re-check step 2 for all 18, resend the bad one, then resend
  11 and 13.

---

## Regenerating the jobs

Only needed if `savedata/macro_data.dta` is rebuilt (which needs the authors' OSF
package; see `../../README.md`) or the split changes.

```bash
python3 src/analyses/remote/tools/make_supply_jobs.py    # part count derived from --max-lines
python3 src/analyses/remote/tools/verify_payload.py      # decodes them back, diffs vs. the source
python3 src/analyses/remote/tools/preflight.py src/analyses/remote/jobs/*.do
```

`verify_payload.py` is the local guarantee that the payload equals the source file: all
2,807 rows, identical missingness, and a worst-case rounding error of 8.9e-04 of a
standard deviation (`afd_votes`, sent at two decimals).

---

## Two deviations from the authors' data, both deliberate

Neither is a transfer error, and no checksum can catch them.

1. **Rounding.** Values travel as scaled integers, so the panel is not bit-identical to
   `macro_data.dta`. Worst error 8.9e-04 of a standard deviation. The paper's Table 2
   descriptives of the standardised county variables nonetheless reproduce to four
   decimals on mean, SD and range.
2. **12 of 57 columns.** The ported `$vars` in `clean_sample.do` is trimmed to match;
   the 45 untransmitted columns are read by nothing downstream.
