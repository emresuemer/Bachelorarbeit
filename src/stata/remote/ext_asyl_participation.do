*==============================================================================*
* ext_asyl_participation.do
*
* Purpose : EXTENSION step E2, third part -- THE CLEANEST TEST OF H2.
*           County course supply interacted with asylum status on
*           PARTICIPATION in an integration course. Does local supply convert
*           into actual enrolment differently depending on legal entitlement?
*           No equivalent panel exists in the paper: int_course_part is the
*           reviewer's variant and appears in no main-text table.
* Source  : 00023_mult_analyses.do:753-927 (the Table 4 model shape) with the
*           interaction form of :377-383. Design: section 2, step 2 of
*           docs/extension_asylum_status.md.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample_part.do -> $mydata/msuemer/sample_imputed_part
*           *** NOT sample_imputed. See THE TWO IMPUTED FILES below. ***
* Saves   : $mydata/msuemer/ext_e2_part
*           (mi estimation results; read back by this job's own mimrgns)
* Result  : results/comparisons/ext_asyl_mediators.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* ============ WHY PARTICIPATION IS THE SHARPEST TEST ============
*
* H2 says entitlement de-couples the individual from the local market: an
* approved refugee holding an Anspruch under 44 AufenthG gets a course place
* more or less regardless of how many the county offers, while a person still
* awaiting a decision can only enrol if local capacity happens to be spare.
* Local supply is then the BINDING constraint precisely where entitlement is
* absent -- so the interaction should be most visible at the moment of
* enrolment, before any of the attrition that separates enrolment from
* completion, certification and proficiency.
*
* The raw means already show the entitlement gradient it rests on. Measured
* 2026-08-25 (results/verification/ext_asylum_moderator.md): participation is
* 62.3% among approved against 34.1% pending and 40.7% rejected -- a 28 p.p.
* gap, the largest differential of any variable measured. That is the PREMISE
* (status governs access), not the hypothesis (supply matters differently by
* status). Report it first, and separately.
*
* It is also the least imputation-dependent mediator: about 39 incomplete
* observations against int_course_finished's 270. Since the largest deviation
* anywhere in the replication fell on the most heavily imputed mediator, that
* matters.
*
* ============ THE TWO IMPUTED FILES MUST NOT BE MIXED ============
*
* int_course_part is imputed ONLY in sample_imputed_part, the authors' second
* imputation (00014 Part B). It is absent from sample_imputed. Pointing this
* job at the wrong file would not fail cleanly -- SOEPremote does not halt on
* runtime errors, so it would carry on and return a listing built on nothing.
* Check the `use` line in the send block before sending.
*
* Equally, do not fold this model into ext_asyl_mediators_primary.do. The two
* files are different imputations of the same sample, and one job can hold
* only one mi setup.
*
* ---------------- THE STORED STATE IS NOT THE ANALYSIS STATE ----------------
* sample_imputed_part is saved in FLONG without a consistency pass -- and that
* is deliberate, because it matches the authors' own file (orig :340 converts
* to flong and saves with no convert back). mi enforces the invariant that
* imputed variables equal the observed data wherever the observed data exist,
* and it applies that invariant on the first mi command. So some values shift
* the first time this file is opened. Expect it; it is not damage.
*
* *** A REVISION, 2026-08-30. This job originally made that pass explicit as a
* second line of the preamble, so it would happen at a visible point in the
* listing rather than silently inside `mi query`. SOEPremote REJECTED the job:
*
*     "The command >update< is not allowed, sorry !
*      Updates are only possible for on side administrators."
*
* The scanner blocks the token on sight -- it is guarding against the Stata
* command that updates the installation itself, and cannot tell that prefixing
* it with `mi` makes it a completely different, purely local operation. It is
* NOT in Table 2 of the job-submission paper; it is a token the published list
* does not mention. preflight.py now carries it.
*
* Nothing is lost by removing it. Every mi command runs the consistency pass
* itself when it needs to -- this repo has already observed exactly that, in
* the 00014 run, where the authors' own inconsistency was reverted by the
* first mi command that touched the file. The pass simply happens inside
* `mi query` now instead of on a line of its own.
*
* The `mi convert flong` below is a no-op on an already-flong file, and is
* kept so this preamble stays line-for-line comparable with the other
* extension jobs. With the update line gone, the ONLY difference from their
* preamble is the retargeted `use`.
*
* ---------------- THE ASYLUM LABELS ARE CORRECTED HERE ----------------
* As in every extension job, three label lines differ from
* tab03_employment.do's preamble, none affecting any estimate:
*   2.asyl_req_stat "-- Rejected"     ->  "-- Approved"
*   3.asyl_req_stat "-- No decision"  ->  "-- Rejected"
*   refcat "...(Ref.: approved): "    ->  "...(Ref.: no decision): "
* The model uses ib1.asyl_req_stat and 00013_data_clean.do:1541 defines
* 1 "no decision", 2 "approved", 3 "rejected", so the reference is NO DECISION.
*
* ---------------- WHY mi test COMES BEFORE _mi_addstats ----------------
* _mi_addstats runs `mi est, post: mean ...` internally, which OVERWRITES
* e(). A test placed after it silently tests the wrong model.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited, as in the other extension jobs: config/cd/log/exit/matsize
* removed; #delimit converted; the _mi_addstats program drop removed and its
* internal drop swapped for soepdrop; esttab's `using` and `keep()` removed;
* the three label corrections; no transform(@*100 100), so the coefficient
* prints RAW at 4 d.p. -- multiply by 100 for percentage points.
* This job's own: the retargeted `use`, and nothing else. An explicit
* consistency pass was tried and had to be removed -- see the revision note
* above; that token is rejected by the scanner.
*
* ---------------- WHAT TO CHECK ----------------
*   *** THE FIRST THING TO READ: mi des must list int_course_part among the
*   IMPUTED variables with about 39 incomplete observations. If it shows ~270
*   the job is reading int_course_finished's imputation, i.e. the wrong file.
*   If int_course_part is absent entirely, impute_sample_part.do has not run.
*   mi query -> M = 20, 5,467 obs, style flong. It may also report values
*        being brought into line with m = 0 -- that is the consistency pass
*        described above, not damage. See impute_sample_part.do.
*   N 5467, groups 2730, M_mi 20 in the estimation.
*
*   *** THE AME IDENTITY -- free, and the same in every extension job:
*        AME(no decision) = b[z_ratio_courseoport]
*        AME(approved)    = b[z_ratio_courseoport]
*                         + b[2.asyl_req_stat#c.z_ratio_courseoport]
*        AME(rejected)    = b[z_ratio_courseoport]
*                         + b[3.asyl_req_stat#c.z_ratio_courseoport]
*
*   *** The joint `mi test` is the PRIMARY inference under the pre-committed
*   multiple-testing rule (design document, section 3e).
*
*   *** H2 predicts the AME is LARGEST for the no-decision group and smallest
*   for approved. H1 predicts the opposite ordering. Both are stated in
*   advance; whichever the data give, report it, including a null.
*
* > 1 imputed regression x 20 imputations with clustered SEs, plus a margins
* > sweep. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/ext_asyl_participation.do
*==============================================================================*

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/sample_imputed_part, clear
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


capture soepdrop m_e2part
eststo m_e2part: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e2_part, replace) esample(m_e2part): ///
    reg int_course_part $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e2part
mimrgns using $mydata/msuemer/ext_e2_part, esample(m_e2part) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

esttab m_e2part, ///
    title("COURSE SUPPLY x ASYLUM STATUS: course participation") ///
    order(z_ratio_courseoport ///
        2.asyl_req_stat#c.z_ratio_courseoport ///
        3.asyl_req_stat#c.z_ratio_courseoport ///
        stay_dur $keeporder_controls _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        2.asyl_req_stat#c.z_ratio_courseoport "x Approved" ///
        3.asyl_req_stat#c.z_ratio_courseoport "x Rejected" ///
        stay_dur "Duration of stay, in months (/12)" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    b(%9.4f) se(%9.4f) ///
    mtitles("Participation in an integration course")

display "EXT E2 participation ok"
