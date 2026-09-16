# SOEPremote job transcripts

The raw reply e-mails returned by the FDZ-SOEP remote-execution system
(`soep-exec@diw.de`) at DIW Berlin, one per job, named after the `.do` file that was
sent.

**These are primary evidence, not derived artifacts.** They cannot be regenerated
locally: the code runs on DIW's server against the unredacted SOEP data, and only a
plain-text listing comes back, never a dataset. Everything in `results/comparisons/`
and every regression table in `results/tables/` is transcribed or generated from these
files. That is why they live under `results/` rather than `build/`, which holds only
output that a local re-run can reproduce.

Kept as full `.eml` rather than extracted text so the provenance survives: the job
number is in the `Subject:`, the timestamp and sending host in the headers, and the DKIM
signature ties the message to `diw.de`. Each file is named after the job that produced
it, `src_stata_remote_<job>.do.eml`, i.e. the repository path of the `.do` file with the
slashes replaced.

**Coverage.** The 25 transcripts here are the complete set for the final chain: the cold
rebuild of the analytic sample and the exhibits (2026-08-13/14) and the extension
(2026-08-25/30). Replies to earlier jobs, the Phase 1 probes of the server (2026-08-02/03),
the 22 county-panel transfer jobs (2026-08-07) and the first, pre-migration runs of the
pipeline (2026-08-03 to 08-11), were not kept in the repository; their results are
recorded in `docs/lab_notebook.md` and, for the transfer, in
`src/analyses/remote/jobs/README.md`. The final chain re-derived every one of those
results from scratch under the final job and dataset names, so nothing cited in the
thesis rests on a reply that is not here.

## Contents

| Job | File | Produces |
|---|---|---|
| 244554 | `merge_soep` | `soep_merged` |
| 244555 | `clean_outcomes` | `clean_outcomes` |
| 244556 | `clean_geography` | `clean_geography` |
| 244557 | `clean_county_merge` | `clean_county` |
| 244558 | `clean_citizenship` | `clean_citizenship` |
| 244559 | `clean_citizenship_tc` | `clean_citizenship_tc` |
| 244560 | `clean_lingprox` | `clean_lingprox` |
| 244561 | `clean_confounders` | `clean_confounders` |
| 244562 | `clean_asylum` | `clean_asylum` |
| 244563 | `clean_sample` | `sample_full`, `sample_analytic`; **paper Table 1** |
| 244564 | `impute_sample` | `sample_imputed` |
| 244565 | `descriptives_micro` | **paper Table 2** |
| 244566 | `tab03_employment` | **paper Table 3** |
| 244567 | `tab04_intermediate_outcomes` | **paper Table 4** |
| 244595 | `fig02_proficiency` | **paper Figure 2, Panel A** |
| 244598 | `tab05_mediation` | **paper Table 5** |
| 244601 | `fig02_course_completion` | **paper Figure 2, Panel B** |
| 244602 | `fig02_certificate` | **paper Figure 2, Panel C** |

Jobs 244554–244563 are the cold rebuild of the analytic sample, run in that order on
2026-08-13; 244564–244567 build on it the same evening, 244595–244602 on 2026-08-14.

### Thesis extension: asylum status as a moderator

Not part of the replication. Design and outcome: `docs/extension_asylum_status.md`; send
order and checks: `README.md`, "Reproducing the extension".

| Job | File | Produces |
|---|---|---|
| 244779 | `ext_asylum_moderator` | E0, the moderator described; `results/verification/ext_asylum_moderator.md` |
| 244834 | `impute_sample_part` | `sample_imputed_part` (prerequisite for 244840) |
| 244835 | `ext_asyl_employment` | E1, and a replication of the paper's Table S6, Model 1.1.9 |
| 244836 | `ext_asyl_mediators_primary` | E2: proficiency, course completion |
| 244837 | `ext_asyl_mediators_secondary` | E2: certificate, contact (placebo) |
| 244839 | `ext_asyl_threeway` | E4, exploratory three-way |
| 244840 | `ext_asyl_participation` | E2: course participation, the sharpest test |

Run on 2026-08-25 (244779) and 2026-08-30 (the rest). **244838 is missing from the
sequence and no transcript for it was kept.** It is the rejected first submission of
`ext_asyl_participation`, the one that carried `mi update` (the scanner bans the token
`update`); it falls in exactly that gap, between 244837 at 19:43 and 244839 at 19:50.
The job number is inferred from the timestamps, not read from a saved notice.

## Reading one

```bash
python3 - <<'EOF'
import email
from email import policy
m = email.message_from_file(open('results/transcripts/<file>.eml', errors='replace'),
                            policy=policy.default)
print(m.get('Subject'))
print(m.get_body(preferencelist=('plain',)).get_content())
EOF
```

The generators in `src/python/lmi/tables/` parse them this way.

## What is and is not in them

Aggregate output only: coefficients, counts, cross-tabulations. SOEPremote screens
every reply before release precisely so that individual-level regional data cannot leave
DIW, which is the whole reason this project runs remotely (see `docs/lab_notebook.md`,
"SOEPremote remote-execution access").

The mail headers carry the submitting university address and account name. They are
clear of credentials: no job listing echoes the four-line auth header.
