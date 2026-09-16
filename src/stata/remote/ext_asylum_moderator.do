*==============================================================================*
* ext_asylum_moderator.do
*
* Purpose : Characterise asylum status as a MODERATOR in the analytic sample --
*           person-level counts, within-person switching, treatment variation
*           and complete-case outcome means, all by status. Closes the gaps
*           left open in docs/extension_asylum_status.md section 1.5. Reads
*           only; writes nothing.
* Source  : none -- written for this thesis
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_sample.do -> $mydata/msuemer/sample_analytic
* Saves   : nothing
* Result  : results/verification/ext_asylum_moderator.md
* Author  : Emre Suemer  ·  2026-08-25
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
*
* WHY THIS EXISTS
*
* The extension moderates the paper's treatment by asyl_req_stat. Three numbers
* that the write-up currently ASSUMES rather than measures have to come from the
* server, because sample_analytic exists nowhere else:
*
*   (1) PERSONS per status group. docs/extension_asylum_status.md quotes
*       ~1,070 / 1,040 / 625, obtained by dividing person-years by T-bar. That
*       is an assumption. The power statement in the thesis rests on it, so it
*       must be measured before it is written down.
*   (2) WITHIN-PERSON SWITCHING. asyl_req_stat is built per person-year
*       (00013_data_clean.do:1296-1301) and changes over waves; the treatment
*       z_ratio_courseoport does not (fixed at first allocation, within-person
*       sd = 0). The share of persons who switch decides how far the
*       baseline-status robustness check can diverge from the main one. If it
*       is near zero the robustness check is a formality; if it is large the
*       two specifications answer different questions.
*   (3) TREATMENT VARIATION WITHIN each group. An interaction is only
*       identified where the treatment actually varies. Counties per group is
*       the honest version of this -- a group concentrated in few counties
*       cannot support a group-specific supply effect however many
*       person-years it has.
*
* WHAT THE OUTPUT MUST SHOW -- POSITIVE CONTROL FIRST
*
* The first tabulate must return 2,140 / 2,076 / 1,251 (39.14 / 37.97 / 22.88),
* matching job 244565. If it does not, the job is reading a different or a
* rebuilt file and NOTHING BELOW IT IS COMPARABLE with the replicated tables.
* Check this before reading any other number.
*
* Expect no missing category: asyl_req_stat is complete in the analytic sample
* (5,467 of 5,467), which is why the moderator itself needs no imputation.
*
* WHY sample_analytic AND NOT sample_imputed
*
* The moderator is fully observed, so imputation buys nothing for it, and mi
* would complicate every tabulate here. The cost is that the outcome and
* mediator means below are COMPLETE-CASE -- trauma_exp-style missingness is not
* filled in. They are descriptive context for the write-up, not estimates;
* every estimate in the extension still runs on sample_imputed.
*
* BASELINE STATUS IS BUILT WITHOUT egenmore
*
* `by pid (syear): generate asyl_base = asyl_req_stat[1]` is plain official
* Stata and makes the ordering explicit. egenmore's first() is installed
* (verified 2026-08-03) but carries an implicit sort assumption, and there is
* no reason to depend on a package for one line.
*
* NO PERSON-LEVEL OUTPUT
*
* Every command here aggregates. Nothing lists or displays a row, so this job
* should clear confidentiality screening without manual review -- job 244565
* returned output of this shape and size unflagged.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/ext_asylum_moderator.do
*   python3 src/analyses/remote/tools/check_clipboard.py     (after composing)
* ==========================================================================
* ============ SEND FROM HERE DOWN (below your auth header) ============
display "EXT ASYL START"

use $mydata/msuemer/sample_analytic, clear

count
tabulate asyl_req_stat, missing

sort pid syear
by pid: generate byte firstobs = _n == 1
by pid: generate byte nwaves = _N
by pid: generate byte asyl_base = asyl_req_stat[1]
label values asyl_base asyl_req_stat
label variable asyl_base "asylum status at first observation"

count if firstobs == 1

display "EXT ASYL persons by status at first observation"
tabulate asyl_base if firstobs == 1, missing

display "EXT ASYL person-years by baseline status"
tabulate asyl_base, missing

by pid: egen byte asyl_min = min(asyl_req_stat)
by pid: egen byte asyl_max = max(asyl_req_stat)
generate byte asyl_switch = asyl_min != asyl_max
label variable asyl_switch "status changes during observation"

display "EXT ASYL persons whose status changes"
tabulate asyl_switch if firstobs == 1
tabulate asyl_switch nwaves if firstobs == 1

display "EXT ASYL transition matrix, baseline by current"
tabulate asyl_base asyl_req_stat, row

display "EXT ASYL waves observed by baseline status"
tabulate nwaves asyl_base if firstobs == 1, column

display "EXT ASYL treatment variation by status"
summarize z_ratio_courseoport init_course_opport
tabulate asyl_req_stat, summarize(z_ratio_courseoport)
tabulate asyl_base, summarize(z_ratio_courseoport)

egen byte ctag = tag(asyl_req_stat kkz1st)
display "EXT ASYL counties represented per status group"
tabulate asyl_req_stat if ctag == 1 & kkz1st > 0 & kkz1st < .

display "EXT ASYL duration of stay by status"
tabulate asyl_req_stat, summarize(stay_dur)

display "EXT ASYL outcome and mediator means by status, complete case"
tabulate asyl_req_stat, summarize(paid_work)
tabulate asyl_req_stat, summarize(german_additive)
tabulate asyl_req_stat, summarize(int_course_part)
tabulate asyl_req_stat, summarize(int_course_finished)
tabulate asyl_req_stat, summarize(germ_cert_any)
tabulate asyl_req_stat, summarize(contacts_germ)

display "EXT ASYL END"
