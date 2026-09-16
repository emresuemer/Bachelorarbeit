*==============================================================================*
* ext_asyl_employment.do
*
* Purpose : EXTENSION step E1. Paper Table 3 Model 1.1, plus the treatment
*           interacted with asylum status -- the reduced-form test of whether
*           the county supply effect on EMPLOYMENT depends on legal status.
*           Estimated twice: with status measured in the survey year, and
*           with status at the person's first observation.
* Source   : 00023_mult_analyses.do:201-343 (Model 1.1) with the interaction
*           form of :377-383 (the authors' own Table S6 loop). The design is
*           docs/extension_asylum_status.md, section 2, step 1.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/ext_e1_cur   status in the survey year
*                           ext_e1_base  status at first observation
*           (mi estimation results; read back by this job's own mimrgns)
* Result  : results/comparisons/ext_asyl_employment.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* ============ THIS JOB IS ALSO A REPLICATION OF TABLE S6 ============
*
* The authors' S6 loop estimates, for asyl_req_stat (orig :377-383):
*
*     reg paid_work $controls_fv c.stay_dur c.z_ratio_courseoport
*         c.z_ratio_courseoport#i.asyl_req_stat
*         [pweight=weight_p], vce(cluster pid)
*
* which is character-for-character the first model below. So m_e1c IS
* Table S6 Model 1.1.9, and porting 00023 Part B separately would buy
* nothing: the other thirteen columns belong either to the WITHDRAWN
* human-capital extension or to unrelated heterogeneity tests.
*
* THE PUBLISHED VALUES THIS MUST REPRODUCE (Supplementary Material p. 12,
* read with the label correction below):
*
*     supply main effect, i.e. for NO DECISION     3.98*  (1.55)
*     Approved x supply   (vs. no decision)       -1.30   (1.90)
*     Rejected x supply   (vs. no decision)       -2.58   (2.48)
*
* Both interactions are insignificant in the paper. Reproducing that is the
* point: the extension's contribution is at the MEDIATOR stage (E2), not
* here, and E1 exists to establish the baseline honestly rather than to find
* an effect. Commit to reporting the null.
*
* *** ALSO CHECK N. S6 prints N observations 5473 / N individuals 2732, while
* Tables 3-5 print 5467 / 2730 on what should be the same sample and the same
* controls. This job settles it: if it returns 5467 / 2730 -- which every
* other ported model on sample_imputed has -- then the S6 figures are an
* error in the paper, and it is the fourth one this replication has found.
*
* ---------------- THE ASYLUM LABELS ARE CORRECTED HERE ----------------
* Every REPLICATION job preserves the authors' mislabelling verbatim, because
* the point of a port is to reproduce their output. This is not a replication
* job, so shipping a known-wrong reference category into our own table would
* be a pure transcription hazard.
*
* The preamble below is tab03_employment.do's, byte-identical apart from
* EXACTLY THREE lines, all of them label text and none of them affecting any
* estimate:
*
*   2.asyl_req_stat "-- Rejected"      ->  "-- Approved"
*   3.asyl_req_stat "-- No decision"   ->  "-- Rejected"
*   refcat "...(Ref.: approved): "     ->  "...(Ref.: no decision): "
*
* Justification: the model uses ib1.asyl_req_stat and 00013_data_clean.do:1541
* defines 1 "no decision", 2 "approved", 3 "rejected". So the omitted
* reference is NO DECISION and the two printed rows are approved and rejected
* respectively. Verify against results/comparisons/tab03_employment.md, where
* the same correction is argued from the raw mi estimate output.
*
* ---------------- WHY BOTH SPECIFICATIONS ----------------
* asyl_req_stat is measured PER PERSON-YEAR and changes within persons; the
* treatment z_ratio_courseoport does not (within-person sd = 0, fixed at
* initial allocation). Mixing a time-invariant treatment with a time-varying
* moderator means part of the interaction is identified off within-person
* status changes, which is not what the theory is about -- and decisions are
* handed down AFTER the allocation, so contemporaneous status is
* post-allocation precisely for the persons who move.
*
* Measured 2026-08-25 (results/verification/ext_asylum_moderator.md):
* 369 of 2,730 persons (13.5%) switch, and switching is strictly absorbing --
* approved -> approved 100%, rejected -> rejected 100%, only "no decision"
* moves. With 86.5% never switching the two specifications cannot diverge
* wildly, so a divergence would be a finding rather than noise.
*
* m_e1c (contemporaneous) is reported for comparability with Table 3 and S6.
* m_e1b (baseline) is the conceptually cleaner one. Say which is which.
*
* ---------------- HOW asyl_base IS BUILT, AND WHY THERE ----------------
* It is constructed AFTER `mi convert flong`, so the preamble stays verbatim.
*
*     bysort _mi_m pid (syear): generate byte asyl_base = asyl_req_stat[1]
*
* `_mi_m` in the bysort is LOAD-BEARING: without it the [1] reaches across
* imputation copies and every person gets m = 0's value. The (syear) sort key
* is what makes "first" mean first wave rather than first row.
*
* `mi register regular asyl_base` is correct because asyl_req_stat is
* COMPLETE in the analytic sample (5,467 of 5,467) -- so asyl_base is
* identical in all 21 copies and needs no imputation. This is also why the
* moderator needs no imputation anywhere in the extension.
*
* *** THAT ONE LINE IS WHAT THE SECOND MODEL STANDS ON. mi estimate refuses
* to put an unregistered variable in a model, and SOEPremote does not halt on
* runtime errors -- so if the register fails, m_e1c still returns normally and
* m_e1b quietly does not. Confirm BOTH columns are present in the esttab
* before reading anything; a one-column table is a failure, not a short job.
*
* ---------------- WHY mi test COMES BEFORE _mi_addstats ----------------
* _mi_addstats runs `mi est, post: mean ...` internally, which OVERWRITES
* e(). Any test that reads the regression's e() must therefore run first.
* Getting this order wrong produces a test of the wrong model that looks
* perfectly well-formed. mimrgns is unaffected -- it reads the .ster file.
*
* ---------------- READ THE AMEs, NOT THE INTERACTION TERMS ----------------
* The hypotheses are about the effect of supply WITHIN each status group, so
* mimrgns reports that directly and the write-up should quote it. The raw
* interaction coefficients are contrasts against whichever category happens
* to be omitted, which is exactly what the paper got wrong.
*
*   H1 (motivation)  predicts monotone: rejected < no decision < approved.
*   H2 (rationing)   predicts a PEAK at "no decision" -- supply binds where
*                    entitlement is absent but enrolment is still possible.
* This is why the moderator must stay categorical: an ordinal or binary
* coding can represent H1 but is mechanically incapable of showing H2.
*
* The joint `mi test` is the primary inference under the pre-committed
* multiple-testing rule (design doc section 3e): one omnibus p-value per
* outcome, individual contrasts descriptive.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited from tab03_employment.do, unchanged:
* (1) do config / cd / log using / exit / set matsize REMOVED. $controls_fv
*     is defined inside 00023 itself (orig :213), not in config.do.
* (2) #delimit -> the global-append form used throughout the port.
* (3) `capt program drop _mi_addstats` REMOVED (`drop` is banned; the program
*     is defined once per job). Inside it, `capture drop e_*` -> soepdrop.
* (4) esttab's `using "$output/..." , scsv replace` REMOVED -- no file can
*     come back from SOEPremote. The table prints to the listing and is
*     transcribed locally.
* (5) esttab's `keep(...)` REMOVED -- the OPTION NAME carries the banned
*     token. `order()` fronts the terms of interest and `indicate()` in
*     $table_opt collapses the four fixed-effect blocks; `nobaselevels` and
*     `varwidth(34)` clean up what that leaves.
* This job's own:
* (6) The three label corrections above -- the ONLY deviation that touches
*     the preamble, and it changes no estimate.
* (7) $controls_b is $controls_fv with its single asylum line repointed at
*     asyl_base. Written out rather than built by substitution so it fails
*     loudly if the control set ever changes upstream.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des    -> M = 20, 5,467 obs before mi convert flong.
*   tabulate asyl_base asyl_req_stat -> the absorbing transition matrix from
*        results/verification/ext_asylum_moderator.md: approved row 100% in
*        the approved column, rejected row 100% rejected, and only the
*        "no decision" row spreading (74.4 / 15.0 / 10.7).
*   both mi estimate tables print in full, with dots for 20 imputations.
*   N 5467, groups 2730, M_mi 20 in BOTH columns -- see the S6 note above.
*   m_e1c against the published S6 values quoted above.
*
*   *** THE AME IDENTITY -- a free correctness check, do not skip it.
*   The model is linear and the moderator categorical, so the mimrgns AME
*   for a group must equal a sum of two numbers printed in the same listing:
*
*        AME(no decision) = b[z_ratio_courseoport]
*        AME(approved)    = b[z_ratio_courseoport]
*                         + b[2.asyl_req_stat#c.z_ratio_courseoport]
*        AME(rejected)    = b[z_ratio_courseoport]
*                         + b[3.asyl_req_stat#c.z_ratio_courseoport]
*
*   Any mismatch means the interaction is mis-specified. This is the same
*   trick that validated Figure 2 Panel A (0.232 against its own 0.2325).
*   Note the esttab prints percentage points and mimrgns prints the raw
*   scale, so compare after scaling by 100.
*
*   *** POWER, to be stated BEFORE reading the estimates. Group shares are
*   39 / 38 / 23 percent of person-years, so subgroup SEs run roughly 1.6 to
*   2.1 times the pooled 1.19 -- which is exactly why S6 reports 1.90 and
*   2.48. A difference in supply effects below about 4 p.p. is NOT detectable
*   at this outcome stage. That is a statement about the design, not an
*   excuse made after the fact.
*
* > If mimrgns rejects over(), nothing is lost: the AMEs are recoverable by
* > hand from the coefficients via the identity above. Do not pre-emptively
* > work around it.
*
* > 2 imputed regressions x 20 imputations with clustered SEs, plus two
* > margins sweeps. Slow. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/ext_asyl_employment.do
*==============================================================================*

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/sample_imputed, clear
mi query
mi des, detail
mi convert flong, clear

global controls_fv ib1.immigroup_nat i.nuts1_first i.syear
global controls_fv $controls_fv i.msample i.work0
global controls_fv $controls_fv c.total_years_edu0
global controls_fv $controls_fv i.female i.h_child i.arriv_fam
global controls_fv $controls_fv i.family0 i.trauma_exp c.age1st
global controls_fv $controls_fv ib1.asyl_req_stat
global controls_fv $controls_fv c.z_foreign_share c.z_density
global controls_fv $controls_fv c.z_unemplrate c.z_consimmi c.z_cdu

global keeporder_controls total_years_edu0 1.work0 1.female
global keeporder_controls $keeporder_controls 1.h_child 1.arriv_fam
global keeporder_controls $keeporder_controls 1.family0 age1st
global keeporder_controls $keeporder_controls 1.trauma_exp
global keeporder_controls $keeporder_controls 2.asyl_req_stat
global keeporder_controls $keeporder_controls 3.asyl_req_stat
global keeporder_controls $keeporder_controls z_foreign_share
global keeporder_controls $keeporder_controls z_density
global keeporder_controls $keeporder_controls z_unemplrate
global keeporder_controls $keeporder_controls z_consimmi z_cdu

global coeflabels total_years_edu0 "Premigration years of education"
global coeflabels $coeflabels ///
    1.work0 "With premigration work experience"
global coeflabels $coeflabels 1.female "Female"
global coeflabels $coeflabels 1.h_child "Children below 16 in household"
global coeflabels $coeflabels ///
    1.arriv_fam "Arrival to Germany with family"
global coeflabels $coeflabels 1.family0 "Premigration family support"
global coeflabels $coeflabels age1st "Age at the first interview"
global coeflabels $coeflabels 1.trauma_exp "With trauma experiences"
global coeflabels $coeflabels 2.asyl_req_stat "-- Approved"
global coeflabels $coeflabels 3.asyl_req_stat "-- Rejected"
global coeflabels $coeflabels ///
    z_foreign_share "County share foreigners, std."
global coeflabels $coeflabels ///
    z_density "County population density, std."
global coeflabels $coeflabels ///
    z_unemplrate "County unemployment rate, std."
global coeflabels $coeflabels ///
    z_consimmi "County concerns immigration, std."
global coeflabels $coeflabels z_cdu "County share CDU/CSU voters, std."

global table_opt collabels(none) constant not wide
global table_opt $table_opt starlevels(+ 0.1 * 0.05 ** 0.01)
global table_opt $table_opt compress nogaps nodepvars
global table_opt $table_opt refcat(2.asyl_req_stat ///
    "Status of the asylum request (Ref.: no decision): ", nolabel)
global table_opt $table_opt indicate("Survey year fe = *.syear" ///
    "Survey sample fe = *.msample" ///
    "Federal State fe = *.nuts1_first" ///
    "Country of origin (aggregated) fe = *.immigroup_nat")
global table_opt $table_opt scalars(N groups M_mi e_r2 e_r2a)
global table_opt $table_opt sfmt(%9.0f %9.0f %9.0f %9.4f %9.4f)

program define _mi_addstats
    quietly {
        capture soepdrop e_*
        args estimates
        est des `estimates'
        mi xeq: `r(cmdline)'; gen e_r2 = e(r2); gen e_r2a = e(r2_a)
        foreach var of varlist e_* {
            mi est, post: mean `var'
            local `var' = _b[`var']
            estadd scalar `var' = ``var'', replace: `estimates'
        }
        soepdrop e_*
        capture soepdrop groups
        bysort pid: generate groups = _n
        count if groups == 1
        local groups = r(N)
        display `groups'
        estadd scalar groups = `groups', replace: `estimates'
    }
end


bysort _mi_m pid (syear): generate byte asyl_base = asyl_req_stat[1]
mi register regular asyl_base
label values asyl_base asyl_req_stat
label variable asyl_base "asylum status at first observation"
tabulate asyl_base asyl_req_stat, row

global controls_b ib1.immigroup_nat i.nuts1_first i.syear
global controls_b $controls_b i.msample i.work0
global controls_b $controls_b c.total_years_edu0
global controls_b $controls_b i.female i.h_child i.arriv_fam
global controls_b $controls_b i.family0 i.trauma_exp c.age1st
global controls_b $controls_b ib1.asyl_base
global controls_b $controls_b c.z_foreign_share c.z_density
global controls_b $controls_b c.z_unemplrate c.z_consimmi c.z_cdu

capture soepdrop m_e1c
eststo m_e1c: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e1_cur, replace) esample(m_e1c): ///
    reg paid_work $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e1c
mimrgns using $mydata/msuemer/ext_e1_cur, esample(m_e1c) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

capture soepdrop m_e1b
eststo m_e1b: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e1_base, replace) esample(m_e1b): ///
    reg paid_work $controls_b ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_base ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_base#c.z_ratio_courseoport ///
    3.asyl_base#c.z_ratio_courseoport
_mi_addstats m_e1b
mimrgns using $mydata/msuemer/ext_e1_base, esample(m_e1b) ///
    dydx(z_ratio_courseoport) over(asyl_base) cmdmargins

esttab m_e1c m_e1b, ///
    title("COURSE SUPPLY x ASYLUM STATUS: employment, p.p.") ///
    order(z_ratio_courseoport ///
        2.asyl_req_stat#c.z_ratio_courseoport ///
        3.asyl_req_stat#c.z_ratio_courseoport ///
        2.asyl_base#c.z_ratio_courseoport ///
        3.asyl_base#c.z_ratio_courseoport ///
        stay_dur $keeporder_controls _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        2.asyl_req_stat#c.z_ratio_courseoport "x Approved" ///
        3.asyl_req_stat#c.z_ratio_courseoport "x Rejected" ///
        2.asyl_base#c.z_ratio_courseoport "x Approved at entry" ///
        3.asyl_base#c.z_ratio_courseoport "x Rejected at entry" ///
        2.asyl_base "-- Approved at entry" ///
        3.asyl_base "-- Rejected at entry" ///
        stay_dur "Duration of stay, in months (/12)" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    transform(@*100 100) b(%9.2f) se(%9.2f) ///
    mtitles("Status in survey year" "Status at first observation")

display "EXT E1 ok"
