*==============================================================================*
* ext_asyl_threeway.do
*
* Purpose : EXTENSION step E4 -- EXPLORATORY ONLY. County course supply
*           interacted with BOTH duration of stay and asylum status, on
*           employment and on German language proficiency. Tests whether the
*           paper's headline secondary finding (the supply effect declines
*           with duration of stay) is concentrated where the time horizon is
*           fixed early by a legal decision.
* Source  : 00023_mult_analyses.do:201-343 and :753-927 for the model shape.
*           Design: section 2, step 4 of docs/extension_asylum_status.md.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/ext_e4_empl  employment
*                           ext_e4_germ  German language proficiency
* Result  : results/comparisons/ext_asyl_employment.md, appendix (its
*           primary DV is employment, so it is filed with the E1 result)
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* ============ SEND THIS LAST, AND ONLY IF ROUND-TRIPS ARE SPARE ============
*
* *** THIS IS ALMOST CERTAINLY UNDERPOWERED AND MUST NOT CARRY AN ARGUMENT.
* The design document's own verdict: "run it, report it as exploratory, do not
* build an argument on it." A two-way interaction at the employment stage
* already needs a difference of about 4 p.p. to be detectable (subgroup SEs
* run 1.6 to 2.1 times the pooled 1.19, which is why S6 reports 1.90 and
* 2.48). Splitting each of those cells again by a continuous duration term
* leaves nothing. Expect wide intervals and report them as such.
*
* It is included because the theory does make a prediction and a
* pre-registered null is worth more than a silence: Esser's horizon argument
* implies the decline of the supply effect over duration of stay should be
* concentrated among those whose horizon was fixed early -- i.e. decided
* cases -- rather than among those still waiting.
*
* german_additive is included alongside paid_work because the mediator stage
* is where E2 has any power at all; if the three-way shows anything anywhere,
* that is where.
*
* ---------------- WHY $controls_noa EXISTS ----------------
* The factorial ib1.asyl_req_stat##c.z_ratio_courseoport##c.stay_dur supplies
* the asylum main effect itself. $controls_fv also carries ib1.asyl_req_stat,
* so using it here would specify the same term twice; Stata would drop one as
* collinear and print "(omitted)" rows that make the table harder to read.
*
* $controls_noa is therefore $controls_fv with its single asylum line left
* out -- seven lines instead of eight, identical otherwise. Written out in
* full rather than derived, so that a change to the control set upstream
* shows up as a visible difference rather than silently propagating.
*
* THE MODERATOR IS STILL IN THE MODEL. It enters through the factorial, not
* through the controls. Do not read $controls_noa as dropping a control.
*
* ---------------- TERM ORDER IS WRITTEN, NOT LEFT TO STATA ----------------
* The factorial is written ib1.asyl_req_stat##c.z_ratio_courseoport##c.stay_dur
* -- factor FIRST -- so the resulting coefficient names are predictable:
*   2.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur
* Stata canonicalises interaction names with factors ahead of continuous
* terms, so writing them in that order is what makes the `mi test` and the
* esttab order() below address the terms that actually exist.
*
* If the names still do not match, `mi test` errors and SOEPremote CONTINUES
* (it does not halt on runtime errors), so the coefficient tables still come
* back and the joint test can be redone from them. The loss is bounded.
*
* ---------------- THE ASYLUM LABELS ARE CORRECTED HERE ----------------
* As in every extension job, three label lines differ from
* tab03_employment.do's preamble, none affecting any estimate:
*   2.asyl_req_stat "-- Rejected"     ->  "-- Approved"
*   3.asyl_req_stat "-- No decision"  ->  "-- Rejected"
*   refcat "...(Ref.: approved): "    ->  "...(Ref.: no decision): "
* Reference category is NO DECISION (00013_data_clean.do:1541).
*
* ---------------- WHY mi test COMES BEFORE _mi_addstats ----------------
* _mi_addstats runs `mi est, post: mean ...` internally, which OVERWRITES
* e(). A test placed after it silently tests the wrong model.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited, as in the other extension jobs: config/cd/log/exit/matsize
* removed; #delimit converted; the _mi_addstats program drop removed and its
* internal drop swapped for soepdrop; esttab's `using` and `keep()` removed;
* the three label corrections.
* This job's own:
* (a) $controls_noa, above.
* (b) NO transform(@*100 100): the two dependent variables sit on different
*     scales (employment is 0/1, proficiency is a scale), so coefficients
*     print RAW at 4 d.p. Multiply the employment column by 100 for
*     percentage points.
* (c) No mimrgns. A three-way AME surface would need margins over duration
*     WITHIN status group, which is a large sweep for a specification this
*     underpowered. Read the interaction terms directly, and if the result is
*     interesting enough to plot, do it as a follow-up job.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des -> M = 20, 5,467 obs before mi convert flong.
*   N 5467, groups 2730, M_mi 20 in both columns.
*   the two-way c.z_ratio_courseoport#c.stay_dur term -> for the REFERENCE
*        group (no decision). The paper's pooled equivalents are Table 3's
*        0.89 (1.78) for employment and Table 4's -0.0870* for proficiency;
*        these are not the same quantity, so do not report them as a
*        reproduction. They are a plausibility anchor only.
*   the two three-way terms -> the exploratory result. Expect wide SEs.
*   *** Report the joint mi test p-value, not the two terms separately, and
*        say in the text that the specification is underpowered BEFORE
*        quoting any number from it.
*
* > 2 imputed regressions x 20 imputations with clustered SEs. Slow, and of
* > lower priority than E1 and E2 -- send those first.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/ext_asyl_threeway.do
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

global controls_noa ib1.immigroup_nat i.nuts1_first i.syear
global controls_noa $controls_noa i.msample i.work0
global controls_noa $controls_noa c.total_years_edu0
global controls_noa $controls_noa i.female i.h_child i.arriv_fam
global controls_noa $controls_noa i.family0 i.trauma_exp c.age1st
global controls_noa $controls_noa c.z_foreign_share c.z_density
global controls_noa $controls_noa c.z_unemplrate c.z_consimmi c.z_cdu

capture soepdrop m_e4w
eststo m_e4w: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e4_empl, replace) esample(m_e4w): ///
    reg paid_work $controls_noa ///
    ib1.asyl_req_stat##c.z_ratio_courseoport##c.stay_dur ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
    3.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur
_mi_addstats m_e4w

capture soepdrop m_e4g
eststo m_e4g: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e4_germ, replace) esample(m_e4g): ///
    reg german_additive $controls_noa ///
    ib1.asyl_req_stat##c.z_ratio_courseoport##c.stay_dur ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
    3.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur
_mi_addstats m_e4g

esttab m_e4w m_e4g, ///
    title("COURSE SUPPLY x DURATION x ASYLUM STATUS: exploratory") ///
    order(z_ratio_courseoport stay_dur ///
        c.z_ratio_courseoport#c.stay_dur ///
        2.asyl_req_stat#c.z_ratio_courseoport ///
        3.asyl_req_stat#c.z_ratio_courseoport ///
        2.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
        3.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
        $keeporder_controls _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        stay_dur "Duration of stay, in months (/12)" ///
        c.z_ratio_courseoport#c.stay_dur "x Duration" ///
        2.asyl_req_stat#c.z_ratio_courseoport "x Approved" ///
        3.asyl_req_stat#c.z_ratio_courseoport "x Rejected" ///
        2.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
            "x Approved x duration" ///
        3.asyl_req_stat#c.z_ratio_courseoport#c.stay_dur ///
            "x Rejected x duration" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    b(%9.4f) se(%9.4f) ///
    mtitles("Employment" "German language proficiency")

display "EXT E4 ok"
