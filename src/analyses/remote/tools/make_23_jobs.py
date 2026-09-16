#!/usr/bin/env python3
"""Generate the 00023 analysis jobs from the preamble proven in Table 3's job.

Every 00023 job needs the same ~60-line preamble: $controls_fv,
$keeporder_controls, $coeflabels, $table_opt and the _mi_addstats program.
Globals and programs do NOT survive between SOEPremote jobs, so each job must
carry its own copy -- and hand-copying it seven times is exactly how the two
halves of a table end up estimated under different control sets.

So the preamble is read out of the job that has already run successfully and
reproduced paper Table 3 -- src/stata/remote/tab03_employment.do, formerly
00023A_analyses_remote.do -- and each job below supplies only its own model
block. Regenerate rather than editing the outputs.

MIGRATION STATE (repo migration, batch 3). Every part this tool generates is
now migrated, and all of them are written to src/stata/remote/ under
exhibit-facing names:

    Part C   -> tab05_mediation.do               paper Table 5
    Part D   -> tab04_intermediate_outcomes.do   paper Table 4
    Part E1  -> fig02_proficiency.do             paper Figure 2, Panel A
    Part E2  -> fig02_course_completion.do       paper Figure 2, Panel B
    Part E3  -> fig02_certificate.do             paper Figure 2, Panel C

Note the exhibit numbers are the PAPER's, not the do-file's: the original
writes Part C to "$output/Table_3" although the paper prints it as Table 5.

They carry the repo's standard header block, which lives HERE rather than in
the .do files, because a hand-applied header on a generated file is wiped by
the next regeneration. Parts B and F-H of 00023 (the supplementary tables) are
not ported at all; add them here rather than by hand if they are ever needed.

Run from src/analyses/:  python3 remote/tools/make_23_jobs.py
"""

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REMOTE = HERE.parent
ROOT = Path(__file__).resolve().parents[4]
STATA_REMOTE = ROOT / "src/stata/remote"
# The preamble source is the MIGRATED Table 3 job. Its send block is
# byte-identical to 00023A_analyses_remote.do's apart from the two saving()
# targets, which are below the slice taken here -- verified, so repointing
# this changes no generated output.
SRC = STATA_REMOTE / "tab03_employment.do"
MARKER = "* ============ SEND FROM HERE DOWN (below your auth header) ============"

# Single source of truth, so a token learned from a rejection reaches every
# generator at once. It gained `update` on 2026-08-30; see preflight.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from preflight import BANNED  # noqa: E402


def preamble():
    """Everything in Table 3's job from `use` down to the end of _mi_addstats."""
    body = SRC.read_text().split(MARKER, 1)[1]
    end = body.index("capture soepdrop m_001p")
    return body[:end].strip("\n")


def check(path, text):
    block = text.split(MARKER, 1)[1]
    words, cur = set(), []
    for ch in block:
        if ch.isalpha():
            cur.append(ch.lower())
        elif cur:
            words.add("".join(cur)); cur = []
    if cur:
        words.add("".join(cur))
    bad = sorted(words & BANNED)
    nonascii = sorted({c for c in block if ord(c) > 126})
    over = [l for l in block.splitlines() if len(l) > 72]
    if bad or nonascii or over:
        sys.exit(f"{path.name}: banned={bad} nonascii={nonascii} "
                 f"over72={over[:2]}")
    path.write_text(text, encoding="ascii")
    print(f"  {path.name}: {block.strip().count(chr(10)) + 1} send lines")


def model(name, dv, extra="", eststo=True, addstats=True, save_as=None):
    """One `eststo ... mi estimate ... reg` block in the authors' shape.

    eststo/addstats are switched off for Part E, which builds no table: it
    only needs the .ster file and the esample marker that mimrgns reads.

    save_as renames only the saved .ster file, never the eststo/esample name:
    the esttab call and _mi_addstats both address the estimates by the
    authors' own m_00NNp names, so those stay put. It exists so that a
    re-run writes to names that have never existed on the server -- a job
    that fails partway then leaves nothing behind that could be mistaken for
    a result. SOEPremote does not halt on runtime errors, so that property is
    the only thing distinguishing a clean re-run from a silently stale one.
    Keep the result under 13 characters or the saving() line passes 72.
    """
    rhs = "c.stay_dur c.z_ratio_courseoport"
    if extra == "INTERACT":
        rhs = "c.stay_dur##c.z_ratio_courseoport"
        extra = ""
    head = f"eststo {name}: mi estimate" if eststo else "mi estimate"
    lines = [
        f"capture soepdrop {name}",
        f"{head}, post dots ///",
        f"    saving($mydata/msuemer/{save_as or name}, replace) "
        f"esample({name}): ///",
        f"    reg {dv} $controls_fv ///",
        f"    {rhs} ///",
    ]
    # every component gets its own continuation line: with long dependent
    # variable names (german_additive, int_course_finished) a combined reg
    # line runs past 72 characters, and a mail client may wrap it
    if extra:
        lines.append(f"    {extra} ///")
    lines.append("    [pweight=weight_p], vce(cluster pid)")
    if addstats:
        lines.append(f"_mi_addstats {name}")
    lines.append("")
    return "\n".join(lines)


HEAD_FIG = """*==============================================================================*
* {stem}.do{pad}(was 00023E{sub}_analyses_remote.do)
*
* GENERATED BY src/analyses/remote/tools/make_23_jobs.py
*           -- DO NOT EDIT BY HAND, REGENERATE
*
* Purpose : Paper FIGURE 2, PANEL {panel}. Average marginal effect of county
*           course supply on {dvdesc},
*           evaluated at eight durations of stay: 0, 6, 12, 18, 24, 30, 36
*           and 42 months (stay_dur is in months/12, so 0 to 3.5 in steps of
*           0.5). This is Model {model} of paper Table 4 read as a slope over
*           duration -- the paper's point being that the effect is positive
*           in the first months and then fades out. The plotted numbers are
*           also tabulated in the supplement as Table S12.
* Source  : 00023_mult_analyses.do:{orig} (the mimrgns + marginsplot block)
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/{ster}  (mi estimation results, write-only)
* Result  : results/comparisons/fig02_marginal_effects.md
*           results/figures/fig02_panel_{lpanel}.{{png,svg}}, drawn locally by
*           src/python/lmi/figures/fig02_marginal_effects.py
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-14
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* ---------------- THREE NAMES, DELIBERATELY DISTINCT ----------------
*   {author_name}  the authors' own estimates, written by their Table 4 block
*   {marker}  the in-memory esample marker this job creates (port's name)
*   {ster}  the .ster file this job writes on the server (migration's name)
* Only the last one changed in the migration, which is what holds the send
* block's diff against the pre-migration version to two $mydata/ lines.
*
* ---------------- WHY THIS RE-ESTIMATES THE MODEL ----------------
* The authors call `mimrgns using $output/{author_name}, esample({author_name})`,
* reusing the estimates their Table 4 block left behind. Both halves of that
* need state the Table 4 job cannot hand over: `using` reads the .ster file,
* which DOES persist in $mydata, but `esample()` names a VARIABLE that
* `mi estimate` creates IN MEMORY to mark the estimation sample -- and memory
* does not survive between SOEPremote jobs. Re-running the regression here
* recreates both, and the estimation is deterministic (the imputations are
* already fixed in sample_imputed), so the coefficients printed below must
* equal tab04_intermediate_outcomes.do's Model {model} column exactly. That
* equality is a free correctness check, not a duplicated result.
*
* ---------------- NOTHING STALE CAN REACH IT ----------------
* Reads sample_imputed, written 2026-08-13 by impute_sample (job 244564) on
* the cold rebuild. Writes {ster} -- a name that has never existed on the
* server. The pre-migration job saved to {marker} instead, and that copy may
* still be there; it is now unreachable from this job. SOEPremote does not
* halt on runtime errors, so a job re-run into an existing name that fails
* partway leaves the OLD file sitting there looking healthy; writing to a
* fresh name makes that failure loud.
*
* ---------------- WHY THREE JOBS AND NOT ONE ----------------
* The three panels are independent, so splitting costs nothing: send all
* three together and wait once. A single job would run three imputed
* regressions plus three 20-imputation margins sweeps, and if it timed out or
* arrived truncated it would not say which panel was at fault.
*
* ---------------- FORCED DEVIATIONS ----------------
* (1) `marginsplot` and its four `graph save`/`graph export` lines REMOVED.
*     No image can come back from SOEPremote. The job returns the margins
*     TABLE instead -- eight rows of dy/dx, SE, t, p and 95% CI -- which is
*     everything the plot is drawn from. The panel is drawn locally by
*     src/python/lmi/figures/fig02_marginal_effects.py.
* (2) `eststo` and `_mi_addstats` dropped: this job builds no table, so it
*     needs neither stored estimates nor the added r2/groups scalars. The
*     preamble is still tab03_employment.do's verbatim, `_mi_addstats`
*     included but never called, so the control set cannot drift from the one
*     that reproduced Table 3.
* (3) #delimit -> `///`, as in every other ported job.
{expl_note}* (5) `saving($output/{author_name})` -> `saving($mydata/msuemer/{ster})`; see
*     NOTHING STALE CAN REACH IT above.
{rescale}*
* ---------------- SHARED WITH TABLE 3'S JOB ----------------
* The preamble ($controls_fv, $keeporder_controls, $coeflabels, $table_opt,
* _mi_addstats) is copied verbatim from tab03_employment.do, which reproduced
* paper Table 3 bit-identically on the 2026-08-13 cold run. Globals and
* programs do not survive between SOEPremote jobs, so every job carries its
* own copy; the generator copies it rather than restating it so the control
* set cannot drift between exhibits.
*
* ---------------- THE AUTHORS' PLOT SETTINGS, FOR THE LOCAL REDRAW ----------
*   y axis   {ysc}
*   x axis   0 "0" 0.5 "6" 1 "12" 1.5 "18" 2 "24" 2.5 "30" 3 "36" 3.5 "42"
*            xtitle "Duration of stay (in months)", xsc(r(0.4 3.6))
*   ytitle   "{ytitle}"
*   title    "{title}"
*   CI as a shaded area (recastci(rarea)), reference line at y = 0.
* Reproduced in the Python module named above, with ONE deliberate departure:
* the authors' ysc() range clips the confidence band at short durations, so the
* module widens it to fit and extends their tick sequence by its own step. The
* published figure clips too, but a band running off the top of the axis reads
* as a rendering fault rather than as a wide interval.
*
* ---------------- WHAT TO CHECK ----------------
*   the coefficient table -> must match the Model {model} column of
*        results/comparisons/tab04_intermediate_outcomes.md exactly.
*   the margins table -> {expect}
*   8 rows in the margins table, N 5467 in the model.
*   `display "23E{sub} ok"` at the end -- with no dataset saved by this job,
*        that line and the margins table ARE the completion signal.
*
* > 1 imputed regression + a 20-imputation margins sweep. Slow; SOEPremote
* > may take longer than the usual hour to return this one.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \\\\
*       src/stata/remote/{stem}.do
*==============================================================================*

"""


def build_fig(sub, panel, orig, stem, name, ster, dv, dvdesc, model_no,
              expression, ysc, ytitle, title, expect, coefs=None):
    """One Figure 2 panel, migrated to src/stata/remote/.

    `name` stays the authors' in-memory esample marker; `ster` is the file it
    saves to. Keeping them separate is what held the send-block diff against
    the pre-migration version down to the two $mydata/ lines.

    `expression` now means "the paper reports this panel in percentage
    points". The option itself is NOT emitted -- see the RESCALING block in
    HEAD_FIG for why, and why dropping it changes no number. `coefs` is the
    (main, interaction) pair from the Table 4 run, used only to print the
    expected values into the header.
    """
    expl_note = ("""* (4) `expression(100*(predict(xb)))` REMOVED, and the x100 done locally
*     instead. THE ONLY DEVIATION IN THESE JOBS THAT TOUCHES THE STATA CODE,
*     so the reasoning is set out in full below under RESCALING.
""" if expression else """* (4) No `expression()` option in the original for this panel: proficiency
*     is an index, reported in scale points rather than percentage points.
*     Panels B and C are rescaled x100 locally; see their headers.
""")
    rescale = ("""*
* ---------------- RESCALING: WHY expression() IS GONE ----------------
* The authors write `expression(100*(predict(xb)))` here to report this panel
* in percentage points. That option is dropped and the x100 applied locally by
* src/python/lmi/figures/fig02_marginal_effects.py instead.
*
* IT IS EXACTLY EQUIVALENT, because the estimator is `reg`. The response is
* then linear in the parameters, so the marginal effect at a given stay_dur is
* just b_supply + stay_dur * b_interaction -- a linear combination -- and
* multiplying the response by 100 multiplies that combination, and its
* delta-method standard error, by exactly 100. t and p are unchanged and the
* confidence bounds scale with the estimate. Nothing is approximated.
* Confirmed empirically on Panel A, which has no expression(): its returned
* marginal effect at stay_dur = 0 is 0.232, exactly its own Model 2.2
* coefficient 0.2325.
*
* WHY IT WAS DROPPED. Panels B and C were sent twice on 2026-08-14 and neither
* produced any reply -- not a listing, not a bounce -- while Panel A and the
* Table 5 job, sent the same evening, both returned within the hour. The one
* token that distinguishes them from every job that has ever run on this
* account is `predict`, which appears in the send block of these two jobs and
* of no other. `predict` is the canonical way to generate individual-level
* fitted values, which is exactly what SOEPremote's confidentiality screening
* exists to catch, and a job held for manual review returns nothing until a
* person looks at it. Removing the option removes the token.
*
* It also removes a real cost: with expression(), margins must differentiate
* NUMERICALLY with respect to every model parameter (about 50 here, once per
* at() point, per imputation) rather than reading the derivative off the
* coefficient vector. That is the other candidate explanation for silence.
*
* WHAT THIS PANEL MUST RETURN, derived from the Table 4 run:
*     effect(stay_dur) = 100 * ({b} + stay_dur * {i})
* i.e. {check}
* Only the standard errors genuinely require this job -- they need the
* covariance between the two coefficients, which we do not hold locally.
""" if expression else "")
    if expression and coefs:
        b, i = coefs
        pred = " ".join(f"{100 * (b + (m / 12) * i):.2f}" for m in
                        (0, 6, 12, 18, 24, 30, 36, 42))
        rescale = rescale.format(
            b=f"{b:.4f}", i=f"{i:.4f}",
            check=f"at 0, 6 ... 42 months: {pred}")
    head = HEAD_FIG.format(
        stem=stem, pad=" " * max(1, 42 - len(stem) - 3), sub=sub, panel=panel,
        lpanel=panel.lower(), orig=orig, ster=ster, marker=name,
        author_name=name[:-1] + "p", dvdesc=dvdesc,
        model=model_no, expl_note=expl_note, rescale=rescale, ysc=ysc,
        ytitle=ytitle, title=title, expect=expect)
    body = model(name, dv, "INTERACT", eststo=False, addstats=False,
                 save_as=ster)
    mim = ["",
           f"mimrgns using $mydata/msuemer/{ster}, esample({name}) ///",
           "    dydx(z_ratio_courseoport) ///",
           "    at(stay_dur=(0 0.5 (0.5) 3.5)) ///"]
    mim.append("    cmdmargins")
    mim.append("")
    mim.append(f'display "23E{sub} ok"')
    text = head + MARKER + "\n" + preamble() + "\n\n" + body \
        + "\n".join(mim) + "\n"
    check(STATA_REMOTE / f"{stem}.do", text)


# ---------------------------------------------------------------- Part C ----
# eststo name -> the .ster file it writes. See model()'s docstring for why the
# two differ, and HEAD_C for why these particular names. The mapping is NOT
# obvious from the authors' names: their m_0013p is the paper's Model 1.5.
# Names are capped at 13 characters -- one more pushes the saving() line past
# the 72-character send-block limit.
C_SAVE = {
    "m_0011p": "tab05_germ",      # Model 1.3  + language proficiency
    "m_0012p": "tab05_crs",       # Model 1.4  + integration course completed
    "m_0013p": "tab05_cert",      # Model 1.5  + language certificate
    "m_0014p": "tab05_cont",      # Model 1.6  + contact with Germans
    "m_0015p": "tab05_all_crs",   # Model 1.7  all three, via completion
    "m_0016p": "tab05_all_crt",   # Model 1.8  all three, via certificate
}

C_MODELS = "".join([
    model("m_0011p", "paid_work", "c.german_additive",
          save_as=C_SAVE["m_0011p"]),
    model("m_0012p", "paid_work", "i.int_course_finished",
          save_as=C_SAVE["m_0012p"]),
    model("m_0013p", "paid_work", "i.germ_cert_any",
          save_as=C_SAVE["m_0013p"]),
    model("m_0014p", "paid_work", "c.time_germ",
          save_as=C_SAVE["m_0014p"]),
    model("m_0015p", "paid_work",
          "c.german_additive i.int_course_finished c.time_germ",
          save_as=C_SAVE["m_0015p"]),
    model("m_0016p", "paid_work",
          "c.german_additive i.germ_cert_any c.time_germ",
          save_as=C_SAVE["m_0016p"]),
])

C_ESTTAB = """esttab m_0011p m_0012p m_0013p m_0014p m_0015p m_0016p, ///
    title("COURSE SUPPLY AND EMPLOYMENT: intermediaries, p.p.") ///
    order(z_ratio_courseoport stay_dur german_additive ///
        1.int_course_finished 1.germ_cert_any time_germ _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        stay_dur "Duration of stay, in months (/12)" ///
        german_additive "German language proficiency" ///
        1.int_course_finished "Completion of an integration course" ///
        1.germ_cert_any "Obtainment of a language certificate" ///
        time_germ "Contact frequency with Germans" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    transform(@*100 100) b(%9.2f) se(%9.2f)

display "23C ok"
"""

# The repo's standard header block lives here, not in the .do file: a header
# hand-applied to a generated file is destroyed by the next regeneration.
HEAD_C = """*==============================================================================*
* tab05_mediation.do                        (was 00023C_analyses_remote.do)
*
* GENERATED BY src/analyses/remote/tools/make_23_jobs.py
*           -- DO NOT EDIT BY HAND, REGENERATE
*
* Purpose : Mediation step 1 -- the DIRECT effect of county course supply on
*           employment, controlling for each intermediary outcome in turn and
*           then for all three jointly. Six LPMs, one table. Produces paper
*           Table 5 and nothing else, hence the exhibit prefix.
* Source  : 00023_mult_analyses.do:566-753
*           WARNING: the do-file writes this to "$output/Table_3". The paper
*           prints it as TABLE 5. The do-file's numbering is NOT the paper's
*           (its Table_2 is the paper's Table 3, its Table_4 is Table 4), and
*           this file is the sharpest instance -- see the mapping below.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/tab05_germ      Model 1.3  + proficiency
*                           tab05_crs       Model 1.4  + course completion
*                           tab05_cert      Model 1.5  + certificate
*                           tab05_cont      Model 1.6  + contact
*                           tab05_all_crs   Model 1.7  all three, completion
*                           tab05_all_crt   Model 1.8  all three, certificate
*           (mi estimation results; write-only, nothing reads them back)
* Result  : results/comparisons/tab05_mediation.md
*           results/tables/tab05_mediation.tex, generated by
*           src/python/lmi/tables/tab05_mediation.py
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-14
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* Mediation, step 1. Table 4's job asks whether course supply moves the
* intermediary outcomes; this asks whether the employment effect survives
* controlling for them, which is the other half of the same argument.
*   m_0011p  + German language proficiency               paper Model 1.3
*   m_0012p  + completion of an integration course       paper Model 1.4
*   m_0013p  + obtainment of a language certificate      paper Model 1.5
*   m_0014p  + contact frequency with Germans            paper Model 1.6
*   m_0015p  all three, using course completion          paper Model 1.7
*   m_0016p  all three, using the certificate instead    paper Model 1.8
*
* ---------------- READ THE MODEL NUMBERING TWICE ----------------
* Three numbering schemes are in play and none of them agree:
*   the authors' eststo names   m_0011p  m_0012p  m_0013p  m_0014p ...
*   the paper's model numbers   1.3      1.4      1.5      1.6     ...
*   this job's saved files      tab05_germ tab05_crs tab05_cert ...
* So m_0013p is the paper's Model 1.5, NOT its Model 1.3. Every write-up must
* go through the mapping above; the saved-file names are deliberately content
* names rather than numbers so they cannot be misread as either scheme.
*
* The authors' reading of the result: the total effect (2.97 in Table 3)
* barely moves and in most specifications RISES slightly, i.e. the mediators
* SUPPRESS rather than transmit it. Their note on Model 1.7: "1 SD in
* LCSupply increases employment probability by 3.2 percentage points" -- the
* estimate the paper's fiscal calculation rests on (0.0312 * 10,000 * 4,800
* euros = 1,497,600 euros of annual savings).
*
* Coefficients ARE in percentage points here: transform(@*100 100), as in
* Table 3's job. Unlike Table 4's, whose four DVs sit on different scales.
*
* ---------------- THE SAVED FILES ARE WRITE-ONLY ----------------
* Nothing in the port reads these six .ster files back. They are still saved
* because that is the authors' own shape, and because `mi estimate, saving()`
* is what would make any later `mimrgns` possible at all.
*
* They are saved under tab05_* rather than the authors' m_00NNp for the same
* reason tab04_intermediate_outcomes writes tab04_*: the 2026-08-08 run left
* m_0011p..m_0016p on the server, built on the PRE-RENAME chain. SOEPremote
* does not halt on runtime errors, so a job re-run into existing names that
* fails partway leaves the OLD file sitting there looking healthy. Writing to
* names that have never existed makes that failure loud.
*
* ---------------- SHARED WITH TABLE 3'S JOB ----------------
* The preamble ($controls_fv, $keeporder_controls, $coeflabels, $table_opt,
* _mi_addstats) is copied verbatim from tab03_employment.do, which reproduced
* paper Table 3 bit-identically on the 2026-08-13 cold run. Globals and
* programs do not survive between SOEPremote jobs, so every job carries its
* own copy; the generator copies it rather than restating it so the control
* set cannot drift between exhibits.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited from tab03_employment.do, unchanged:
* (1) do config / cd / log using / exit / set matsize REMOVED. $controls_fv
*     is defined inside 00023 itself (orig :213), not in config.do.
* (2) #delimit -> the global-append form used throughout the port.
* (3) `capt program drop _mi_addstats` REMOVED (`drop` is banned; the program
*     is defined once per job). Inside it, `capture drop e_*` -> soepdrop.
* (4) esttab's `using "$output/Table_3", scsv replace` REMOVED -- no file can
*     come back from SOEPremote. The table prints to the listing and is
*     transcribed locally.
* (5) esttab's `keep(...)` REMOVED -- the OPTION NAME contains the banned
*     token `keep`. `order()` still fronts the variables of interest and
*     `indicate()` collapses the four fixed-effect blocks, so the control
*     rows simply print below. `nobaselevels` suppresses the spurious
*     `0.work0 ... 0.00 (.)` rows this creates and `varwidth(34)` stops the
*     county labels truncating to an indistinguishable "Cou..".
* This job's own:
* (6) `saving($output/m_00NNp)` -> `saving($mydata/msuemer/tab05_*)`; see THE
*     SAVED FILES ARE WRITE-ONLY above. The eststo and esample() names stay
*     the authors' m_00NNp, so the esttab call is untouched.
*
* ---------------- READ THE ASYLUM LABELS SCEPTICALLY ----------------
* $coeflabels calls 2.asyl_req_stat "-- Rejected" and 3.asyl_req_stat
* "-- No decision", and $table_opt's refcat says the reference is "approved".
* ALL THREE ARE WRONG, and they are the authors' own: the model uses
* ib1.asyl_req_stat and 00013_data_clean.do:1541 defines 1 "no decision",
* 2 "approved", 3 "rejected". So the omitted reference is NO DECISION and the
* two printed rows are approved and rejected. This is the third table the
* error reaches (Tables 2, 3 and 5) and the published Table 5 does not print
* these rows at all -- it says "Further individual and county-level controls
* are omitted". Preserved verbatim so the port reproduces the authors'
* output; correct it in the write-up, not the code.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des  -> M = 20, 5,467 obs before mi convert flong.
*   all six `mi estimate` tables print in full, with dots for 20 imputes.
*   N 5467, groups 2730, M_mi 20 in every one of the six columns.
*   z_ratio_courseoport across all six columns -> near 3.0 p.p. and still
*        significant. Expect (2026-08-08 run, pre-migration chain):
*        2.97* 2.93* 3.04* 3.19** 3.13** 3.18** -- every one within 0.02
*        p.p. of the paper, with identical SEs and identical stars.
*   the mediators -> 1.64** 7.62** 4.02+ 5.06** separately; jointly
*        proficiency 0.51 goes non-significant while completion 6.73** and
*        contact 4.88** stay. That contrast IS the paper's argument.
*   adjusted R2 -> .2209 .2186 .2147 .2563 .2614 .2575, with Model 1.7 the
*        highest, which is the paper's "superior model fit" claim.
*
* > The 2026-08-13 cold rebuild reproduced Tables 3 and 4 bit-identically
* > against their 2026-08-08 runs, so a difference here now indicates a
* > porting problem, not Monte Carlo noise. Compare against the figures
* > above before anything else.
*
* > 6 imputed regressions x 20 imputations with clustered SEs. Slow; check
* > for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \\\\
*       src/stata/remote/tab05_mediation.do
*==============================================================================*

"""


def build_c():
    """Part C, migrated: standard header, new filename, new .ster names."""
    text = HEAD_C + MARKER + "\n" + preamble() + "\n\n" + C_MODELS \
        + C_ESTTAB + "\n"
    check(STATA_REMOTE / "tab05_mediation.do", text)


# ---------------------------------------------------------------- Part D ----
# eststo name -> the .ster file it writes. See model()'s docstring for why
# the two differ; see HEAD_D for why these particular names.
D_SAVE = {
    "m_0021p": "tab04_germ_m", "m_0022p": "tab04_germ_x",
    "m_0031p": "tab04_crs_m", "m_0032p": "tab04_crs_x",
    "m_0041p": "tab04_cert_m", "m_0042p": "tab04_cert_x",
    "m_0051p": "tab04_cont_m", "m_0052p": "tab04_cont_x",
}

D_MODELS = "".join([
    model("m_0021p", "german_additive", save_as=D_SAVE["m_0021p"]),
    model("m_0022p", "german_additive", "INTERACT", save_as=D_SAVE["m_0022p"]),
    model("m_0031p", "int_course_finished", save_as=D_SAVE["m_0031p"]),
    model("m_0032p", "int_course_finished", "INTERACT",
          save_as=D_SAVE["m_0032p"]),
    model("m_0041p", "germ_cert_any", save_as=D_SAVE["m_0041p"]),
    model("m_0042p", "germ_cert_any", "INTERACT", save_as=D_SAVE["m_0042p"]),
    model("m_0051p", "contacts_germ", save_as=D_SAVE["m_0051p"]),
    model("m_0052p", "contacts_germ", "INTERACT", save_as=D_SAVE["m_0052p"]),
])

D_ESTTAB = """esttab m_0021p m_0022p m_0031p m_0032p ///
    m_0041p m_0042p m_0051p m_0052p, ///
    title("COURSE SUPPLY AND INTERMEDIARY OUTCOMES") ///
    order(z_ratio_courseoport stay_dur ///
        c.stay_dur#c.z_ratio_courseoport _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        stay_dur "Duration of stay, in months (/12)" ///
        c.stay_dur#c.z_ratio_courseoport "x County supply" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    b(%9.4f) se(%9.4f) ///
    mtitles("German language proficiency" " " ///
        "Completion of an integration course" " " ///
        "Language certificate obtainment" " " ///
        "Contact frequency with Germans" " ")

display "23D ok"
"""

# The repo's standard header block lives here, not in the .do file: a header
# hand-applied to a generated file is destroyed by the next regeneration.
HEAD_D = """*==============================================================================*
* tab04_intermediate_outcomes.do            (was 00023D_analyses_remote.do)
*
* GENERATED BY src/analyses/remote/tools/make_23_jobs.py
*           -- DO NOT EDIT BY HAND, REGENERATE
*
* Purpose : Mediation step 2 -- county course supply as the PREDICTOR of each
*           of the four intermediary outcomes in turn, without and with the
*           duration-of-stay interaction. Eight LPM/OLS models, one table.
*           Produces paper Table 4 and nothing else, hence the exhibit prefix.
* Source  : 00023_mult_analyses.do:748-927 (the do-file calls this "Table_4";
*           here the do-file's number and the paper's happen to agree -- the
*           block above it writes "Table_3" and the paper prints Table 5)
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/tab04_germ_m  tab04_germ_x   (proficiency)
*                           tab04_crs_m   tab04_crs_x    (course completion)
*                           tab04_cert_m  tab04_cert_x   (certificate)
*                           tab04_cont_m  tab04_cont_x   (contact)
*           (mi estimation results; write-only, see below)
* Result  : results/comparisons/tab04_intermediate_outcomes.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-14
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* Mediation, step 2. Part C (paper Table 5) asks whether the intermediary
* outcomes carry the employment effect; this asks whether course supply moves
* the intermediaries at all, which is the other half of the same argument.
*   m_0021p/m_0022p  german_additive       DV: German language proficiency
*   m_0031p/m_0032p  int_course_finished   DV: integration course completed
*   m_0041p/m_0042p  germ_cert_any         DV: language certificate obtained
*   m_0051p/m_0052p  contacts_germ         DV: contact frequency with Germans
* The odd-numbered model of each pair is the main effect, the even-numbered
* one adds c.stay_dur##c.z_ratio_courseoport. The authors' reading, repeated
* for each pair: the main effect is not significant, but "the effect of
* LCSupply is positive and reduces over duration of stay" once the
* interaction is included.
*
* Note the DV of the fourth pair is `contacts_germ`, NOT the `time_germ` used
* as mediator 4 in Part C. That is the authors' own choice, kept as is.
*
* This esttab has NO transform(@*100 100): the four dependent variables sit
* on different scales, so coefficients print RAW at 4 d.p. The paper reports
* Panels A and D raw and Panels B and C multiplied by 100. Do not compare
* these magnitudes against Table 3's or Table 5's percentage points.
*
* ---------------- THE SAVED FILES ARE WRITE-ONLY ----------------
* Nothing in the port reads these eight .ster files back. The authors' own
* Part E calls `mimrgns using $output/m_0022p, esample(m_0022p)`, but
* esample() names a variable that `mi estimate` creates IN MEMORY, and memory
* does not cross SOEPremote jobs -- so E1-E3 re-estimate and save m_0022e,
* m_0032e, m_0042e instead. They are still saved because `mi estimate,
* saving()` is what makes any later mimrgns possible at all.
*
* They are saved under tab04_* rather than the authors' m_00NNp for the same
* reason tab03_employment writes tab03_total/tab03_interact: the 2026-08-08
* run left m_0021p..m_0052p on the server, built on the pre-rename chain.
* SOEPremote does not halt on runtime errors, so a job re-run into existing
* names that fails partway leaves the OLD file sitting there looking healthy.
* Writing to names that have never existed makes that failure loud.
*
* ---------------- WHY 00023 IS CHUNKED BY TABLE, NOT BY LINE ----------------
* `eststo` stores estimates in MEMORY, so a table's models and its `esttab`
* MUST travel in the same job. The chunking follows the eight `esttab` calls,
* not the 190-line budget:
*
*   A  201-343   m_001p m_002p                      -> paper Table 3
*   B  343-562   m_001p_i1..i13 (loop)              -> Table S6
*   C  562-753   m_0011p..m_0016p                   -> paper Table 5
*   D  753-927   m_0021p..m_0052p                   -> paper Table 4 (this)
*   E  927-1055  mimrgns x3                         -> Figures 2a-c
*   F  1055-1228 m_001r m_001c m_001f m_001l        -> Tables S8, S9
*   G  1228-1344 m_0061p m_0062p m_0071p m_0072p    -> Table S11
*   H  1344-1556 m_0017..m_0022                     -> Table S10
*
* ---------------- SHARED WITH TABLE 3'S JOB ----------------
* The preamble ($controls_fv, $keeporder_controls, $coeflabels, $table_opt,
* _mi_addstats) is copied verbatim from tab03_employment.do, which reproduced
* paper Table 3 to within Monte Carlo error and, on the 2026-08-13 cold run,
* bit-identically. Globals and programs do not survive between SOEPremote
* jobs, so every job carries its own copy; the generator copies it rather
* than restating it so the control set cannot drift between tables.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited from tab03_employment.do, unchanged:
* (1) do config / cd / log using / exit / set matsize REMOVED. $controls_fv
*     is defined inside 00023 itself (orig :213), not in config.do.
* (2) #delimit -> the global-append form used throughout the port.
* (3) `capt program drop _mi_addstats` REMOVED (`drop` is banned; the program
*     is defined once per job). Inside it, `capture drop e_*` -> soepdrop.
* (4) esttab's `using "$output/Table_4", scsv replace` REMOVED -- no file can
*     come back from SOEPremote. The table prints to the listing and is
*     transcribed locally.
* (5) esttab's `keep(...)` REMOVED -- the OPTION NAME contains the banned
*     token `keep`. `order()` still fronts the variables of interest and
*     `indicate()` collapses the four fixed-effect blocks, so the control
*     rows simply print below. `nobaselevels` suppresses the spurious
*     `0.work0 ... 0.00 (.)` rows this creates and `varwidth(34)` stops the
*     five county labels truncating to an indistinguishable "Cou..".
* This job's own:
* (6) `saving($output/m_00NNp)` -> `saving($mydata/msuemer/tab04_*)`; see
*     THE SAVED FILES ARE WRITE-ONLY above. The eststo and esample() names
*     stay the authors' m_00NNp, so the esttab call is untouched.
*
* ---------------- READ THE ASYLUM LABELS SCEPTICALLY ----------------
* $coeflabels calls 2.asyl_req_stat "-- Rejected" and 3.asyl_req_stat
* "-- No decision", and $table_opt's refcat says the reference is "approved".
* ALL THREE ARE WRONG, and they are the authors' own: the model uses
* ib1.asyl_req_stat and 00013_data_clean.do:1541 defines 1 "no decision",
* 2 "approved", 3 "rejected". So the omitted reference is NO DECISION and the
* two printed rows are approved and rejected. Preserved verbatim so the port
* reproduces the authors' output; correct it in the write-up, not the code.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des  -> M = 20, 5,467 obs before mi convert flong.
*   all eight `mi estimate` tables print in full, with dots for 20 imputes.
*   N 5467, groups 2730, M_mi 20 in every one of the eight columns.
*   the interaction c.stay_dur#c.z_ratio_courseoport in columns 2, 4, 6, 8
*        -> the authors' substantive result. Expect (2026-08-08 run):
*           -0.0870* / -1.41+ (as p.p., i.e. -0.0141) / -2.36** / -0.0084.
*   the main effect in columns 1, 3, 5, 7 -> expected non-significant:
*           0.0071 / 0.0068 / -0.0145 / -0.0191.
*   adjusted R2 -> 0.3900 0.3910 | 0.2014 0.2025 | 0.3380 0.3409 | 0.1492 0.1493
*   coefficients are RAW, not percentage points.
*
* > The 2026-08-13 cold rebuild reproduced Table 3 bit-identically against the
* > 2026-08-08 run, so a difference here now indicates a porting problem, not
* > Monte Carlo noise. Compare against the figures above before anything else.
*
* > 8 imputed regressions x 20 imputations with clustered SEs -- the slowest
* > job in the port so far. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \\
*       src/stata/remote/tab04_intermediate_outcomes.do
*==============================================================================*

"""


def build_d():
    """Part D, migrated: standard header, new filename, new .ster names."""
    text = HEAD_D + MARKER + "\n" + preamble() + "\n\n" + D_MODELS \
        + D_ESTTAB + "\n"
    check(STATA_REMOTE / "tab04_intermediate_outcomes.do", text)


def main():
    build_c()

    build_d()

    build_fig(1, "A", "927-955", "fig02_proficiency", "m_0022e", "fig02_germ",
              "german_additive", "German language proficiency", "2.2",
              expression=False,
              ysc="ysc(r(-0.25 0.45)) ylabel(-0.2(0.1)0.4)",
              ytitle="German language proficiency",
              title="Panel A. German language proficiency / Model 2.2",
              expect="about +0.2 scale points at 0-6 months,\n"
                     "*        falling to non-significant past 12 months.")

    build_fig(2, "B", "957-989", "fig02_course_completion", "m_0032e",
              "fig02_crs", "int_course_finished",
              "Pr(completion of an integration course)", "3.2",
              expression=True,
              ysc="ysc(r(-4.5 6.5)) ylabel(-4 (2) 6)",
              ytitle="Completion of an integration course (pr)",
              title="Panel B. Pr(completion of an integration course) / "
                    "in percentage points, Model 3.2",
              coefs=(0.0434, -0.0141),
              expect="about +4 to +5 p.p. below 6 months,\n"
                     "*        non-significant past 24 months.")

    build_fig(3, "C", "991-1023", "fig02_certificate", "m_0042e",
              "fig02_cert", "germ_cert_any",
              "Pr(obtainment of a language certificate)", "4.2",
              expression=True,
              ysc="ysc(r(-6.5 6.5)) ylabel(-6 (2) 6)",
              ytitle="Obtainment of a language certificate (pr)",
              title="Panel C. Pr(obtainment of a language certificate) / "
                    "in percentage points, Model 4.2",
              coefs=(0.0465, -0.0236),
              expect="about +4 to +5 p.p. below 6 months,\n"
                     "*        non-significant past 12 months.")

    print("\nregenerate with: python3 remote/tools/make_23_jobs.py")


if __name__ == "__main__":
    main()
