*==============================================================================*
* ext_asyl_mediators_primary.do
*
* Purpose : EXTENSION step E2, first half -- THE NOVEL PART OF THE THESIS.
*           County course supply interacted with asylum status on the two
*           primary intermediary outcomes: German language proficiency
*           (Esser's L(2) itself) and completion of an integration course
*           (the Zugang mechanism). Paper Table 4 Panels A and B, moderated.
* Source  : 00023_mult_analyses.do:753-927 (the Table 4 models), with the
*           interaction form of :377-383. Design: section 2, step 2 of
*           docs/extension_asylum_status.md.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/ext_e2_germ  German language proficiency
*                           ext_e2_crs   completion of an integration course
*           (mi estimation results; read back by this job's own mimrgns)
* Result  : results/comparisons/ext_asyl_mediators.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* ============ WHY THIS STAGE IS THE CONTRIBUTION ============
*
* The paper ALREADY estimates supply x asylum status on EMPLOYMENT --
* Supplementary Table S6, Model 1.1.9, reproduced by this extension's own
* ext_asyl_employment.do. So E1 is a re-run of a published null.
*
* S6 interacts NOTHING with Table 4. That is the gap:
*
*   moderator on employment        the RETURNS to language   S6 1.1.9, done
*   moderator on the mediators     ACCESS to the treatment   never estimated
*
* And it is the stage the theory is actually about. Esser (2006, Kap. 3)
* objects to exactly the linear-additive specification the paper uses:
* Motivation, Zugang, Effizienz and Kosten are not substitutes but
* multiplicatively linked (Gl. 3.5), so absent access cannot be offset by
* high motivation. His argument is about L(2) -- language acquisition -- not
* about employment, which sits four links downstream.
*
* Two further reasons this stage has better prospects than E1. It is one
* causal link instead of four, so less attenuation. And Table 4's supply
* effects are large relative to their SEs where the paper's own duration
* interaction bites (proficiency -0.087*, certificate -2.36**), which is
* direct evidence that this outcome stage can detect moderation at this
* sample size. The employment stage demonstrably cannot.
*
* ---------------- THE TWO HYPOTHESES PREDICT DIFFERENT SHAPES ----------------
*   H1 (motivation)  monotone: rejected < no decision < approved. Security of
*                    status lengthens the horizon over which German pays off.
*   H2 (rationing)   a PEAK at "no decision". Entitlement under 44 AufenthG
*                    de-couples approved refugees from the local market -- they
*                    get a place whatever the county offers -- so local supply
*                    binds precisely where entitlement is absent.
*
* This is why the moderator stays categorical (ib1.asyl_req_stat). An ordinal
* or binary "security" scale can represent H1 but is mechanically incapable of
* showing H2, and H2 is what the paper's own S6 point estimates weakly suggest
* (-1.30 and -2.58, both negative, with the main effect largest for the
* pending group).
*
* ---------------- REPORT THE RAW GRADIENT FIRST ----------------
* Measured 2026-08-25, results/verification/ext_asylum_moderator.md:
* integration-course PARTICIPATION is 62.3% among approved against 34.1%
* pending and 40.7% rejected -- a 28 p.p. gap, the largest differential of any
* variable measured, and exactly the 44 AufenthG pattern the premise rests on.
* The same ordering runs, attenuated, through completion (38.4 / 19.4 / 28.2).
*
* That is a MAIN EFFECT, not the interaction: it establishes that legal status
* governs access to the treatment (the premise), not that supply matters
* differently by status (the hypothesis). Report it before these models, and
* note the caveat -- rejected applicants have been in Germany longest (2.80 vs
* 2.12 years), so the ordering is not a pure legal-access ranking.
*
* ---------------- THE ASYLUM LABELS ARE CORRECTED HERE ----------------
* The preamble is tab03_employment.do's, byte-identical apart from EXACTLY
* THREE lines, all label text, none affecting any estimate:
*   2.asyl_req_stat "-- Rejected"     ->  "-- Approved"
*   3.asyl_req_stat "-- No decision"  ->  "-- Rejected"
*   refcat "...(Ref.: approved): "    ->  "...(Ref.: no decision): "
* The model uses ib1.asyl_req_stat and 00013_data_clean.do:1541 defines
* 1 "no decision", 2 "approved", 3 "rejected", so the omitted reference is NO
* DECISION. Replication jobs preserve the authors' error deliberately; this is
* not a replication job, and shipping it into our own table would be a pure
* transcription hazard.
*
* ---------------- WHY mi test COMES BEFORE _mi_addstats ----------------
* _mi_addstats runs `mi est, post: mean ...` internally, which OVERWRITES
* e(). A test placed after it silently tests the wrong model. mimrgns is
* unaffected -- it reads the .ster file rather than e().
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited from tab03_employment.do and tab04_intermediate_outcomes.do:
* (1) do config / cd / log using / exit / set matsize REMOVED.
* (2) #delimit -> the global-append form used throughout the port.
* (3) `capt program drop _mi_addstats` REMOVED; `capture drop e_*` ->
*     soepdrop inside it.
* (4) esttab's `using "$output/..." , scsv replace` REMOVED -- no file can
*     come back from SOEPremote.
* (5) esttab's `keep(...)` REMOVED -- the OPTION NAME carries the banned
*     token. `order()` plus `indicate()`, `nobaselevels`, `varwidth(34)`.
* This job's own:
* (6) The three label corrections above.
* (7) NO transform(@*100 100), following Table 4's job: the dependent
*     variables sit on different scales, so coefficients print RAW at 4 d.p.
*     Multiply the course-completion column by 100 for percentage points.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des  -> M = 20, 5,467 obs before mi convert flong.
*   both mi estimate tables print in full, with dots for 20 imputations.
*   N 5467, groups 2730, M_mi 20 in both columns.
*
*   *** DO NOT compare the supply coefficient against Table 4's main effect
*   (0.0071 proficiency, 0.0068 completion). Once the interaction is in the
*   model that coefficient is the effect FOR THE REFERENCE GROUP -- persons
*   with no decision -- not the pooled average. The comparable quantity is
*   the person-weighted average of the three AMEs.
*
*   *** THE AME IDENTITY -- a free correctness check, do not skip it.
*   The model is linear and the moderator categorical, so each mimrgns AME
*   must equal a sum of two numbers printed in the same listing:
*        AME(no decision) = b[z_ratio_courseoport]
*        AME(approved)    = b[z_ratio_courseoport]
*                         + b[2.asyl_req_stat#c.z_ratio_courseoport]
*        AME(rejected)    = b[z_ratio_courseoport]
*                         + b[3.asyl_req_stat#c.z_ratio_courseoport]
*   A mismatch means the interaction is mis-specified. Same trick that
*   validated Figure 2 Panel A (0.232 against its own 0.2325).
*
*   *** THE PRE-COMMITTED INFERENCE RULE. Five mediators x two contrasts is
*   ten interaction tests. The joint `mi test` per outcome is the PRIMARY
*   inference; individual contrasts are descriptive. This rule is stated in
*   section 3e of the design document and was fixed BEFORE any result was
*   seen -- keep it that way.
*
*   int_course_finished is the most heavily imputed mediator (270 incomplete
*   against 4 / 12 / 18 for the others), so it is where Monte Carlo variation
*   should concentrate. It carried the largest deviation anywhere in the
*   replication (0.33 p.p.). Read its subgroup estimates with that in mind.
*
* > If mimrgns rejects over(), nothing is lost -- the AMEs follow from the
* > coefficients via the identity above. Do not pre-emptively work around it.
*
* > 2 imputed regressions x 20 imputations with clustered SEs, plus two
* > margins sweeps. Slow. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/ext_asyl_mediators_primary.do
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


capture soepdrop m_e2germ
eststo m_e2germ: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e2_germ, replace) esample(m_e2germ): ///
    reg german_additive $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e2germ
mimrgns using $mydata/msuemer/ext_e2_germ, esample(m_e2germ) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

capture soepdrop m_e2crs
eststo m_e2crs: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e2_crs, replace) esample(m_e2crs): ///
    reg int_course_finished $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e2crs
mimrgns using $mydata/msuemer/ext_e2_crs, esample(m_e2crs) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

esttab m_e2germ m_e2crs, ///
    title("COURSE SUPPLY x ASYLUM STATUS: language acquisition") ///
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
    mtitles("German language proficiency" ///
        "Completion of an integration course")

display "EXT E2 primary ok"
