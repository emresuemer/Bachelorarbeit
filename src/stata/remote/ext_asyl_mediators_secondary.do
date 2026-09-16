*==============================================================================*
* ext_asyl_mediators_secondary.do
*
* Purpose : EXTENSION step E2, second half. County course supply interacted
*           with asylum status on the two remaining intermediary outcomes:
*           obtainment of a language certificate (certified attainment) and
*           contact frequency with Germans (the PLACEBO). Paper Table 4
*           Panels C and D, moderated.
* Source  : 00023_mult_analyses.do:753-927 (the Table 4 models), with the
*           interaction form of :377-383. Design: section 2, step 2 of
*           docs/extension_asylum_status.md.
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/ext_e2_cert  language certificate obtained
*                           ext_e2_cont  contact frequency with Germans
*           (mi estimation results; read back by this job's own mimrgns)
* Result  : results/comparisons/ext_asyl_mediators.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* THE COMPANION OF ext_asyl_mediators_primary.do. Read that file's header for
* the full argument -- why the mediator stage is the contribution, what H1 and
* H2 predict, why the moderator must stay categorical, and the AME identity.
* Only what is specific to these two outcomes is repeated here.
*
* The split is by ROLE, not by size: proficiency and course completion are the
* hypothesis tests, these two are corroboration and a placebo. Two models per
* job also means a failure names the outcome that failed.
*
* ---------------- contacts_germ IS A PLACEBO, TREAT IT AS ONE ----------------
* The paper finds county supply has NO effect on contact with Germans (Table 4
* Panel D, -0.0191 main effect, -0.0084 interaction, neither significant). A
* significant MODERATION here would therefore be a warning sign, not a
* finding: it would suggest the interaction is picking up something other than
* differential access to courses.
*
* Two further reasons to discount it. contacts_germ is observed for only 67.9%
* of person-years, and its group means were indistinguishable in the
* descriptive job (results/verification/ext_asylum_moderator.md). And note the
* variable is contacts_germ, NOT the time_germ used as mediator 4 in Table 5 --
* the authors' own inconsistency, preserved.
*
* germ_cert_any is the strongest of the four in the paper: its duration
* interaction is -2.36**, the largest and most significant in Table 4. If any
* mediator can carry a detectable moderation at this sample size it is this
* one. It is also the outcome furthest downstream of enrolment, so a null here
* alongside a result on participation would itself be informative about where
* in the chain legal status bites.
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
* not a replication job.
*
* ---------------- WHY mi test COMES BEFORE _mi_addstats ----------------
* _mi_addstats runs `mi est, post: mean ...` internally, which OVERWRITES
* e(). A test placed after it silently tests the wrong model. mimrgns reads
* the .ster file and is unaffected.
*
* ---------------- FORCED DEVIATIONS ----------------
* Identical to ext_asyl_mediators_primary.do -- see that file. In short:
* config/cd/log/exit/matsize removed; #delimit converted; the _mi_addstats
* program drop removed and its internal drop swapped for soepdrop; esttab's
* `using` and `keep()` removed; the three label corrections; and NO
* transform(@*100 100), so coefficients print RAW at 4 d.p. as in Table 4.
* Multiply the certificate column by 100 for percentage points; contact
* frequency is a scale and stays raw.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des  -> M = 20, 5,467 obs before mi convert flong.
*   both mi estimate tables print in full, with dots for 20 imputations.
*   N 5467, groups 2730, M_mi 20 in both columns.
*
*   *** DO NOT compare the supply coefficient against Table 4's main effects
*   (-0.0145 certificate, -0.0191 contact). With the interaction in the model
*   that coefficient is the effect FOR THE REFERENCE GROUP -- persons with no
*   decision -- not the pooled average.
*
*   *** THE AME IDENTITY -- free, and the same in every extension job:
*        AME(no decision) = b[z_ratio_courseoport]
*        AME(approved)    = b[z_ratio_courseoport]
*                         + b[2.asyl_req_stat#c.z_ratio_courseoport]
*        AME(rejected)    = b[z_ratio_courseoport]
*                         + b[3.asyl_req_stat#c.z_ratio_courseoport]
*   A mismatch means the interaction is mis-specified.
*
*   *** The joint `mi test` per outcome is the PRIMARY inference under the
*   pre-committed multiple-testing rule (design document, section 3e).
*   Individual contrasts are descriptive.
*
* > If mimrgns rejects over(), the AMEs still follow from the coefficients.
*
* > 2 imputed regressions x 20 imputations with clustered SEs, plus two
* > margins sweeps. Slow. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/ext_asyl_mediators_secondary.do
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


capture soepdrop m_e2cert
eststo m_e2cert: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e2_cert, replace) esample(m_e2cert): ///
    reg germ_cert_any $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e2cert
mimrgns using $mydata/msuemer/ext_e2_cert, esample(m_e2cert) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

capture soepdrop m_e2cont
eststo m_e2cont: mi estimate, post dots ///
    saving($mydata/msuemer/ext_e2_cont, replace) esample(m_e2cont): ///
    reg contacts_germ $controls_fv ///
    c.stay_dur c.z_ratio_courseoport ///
    c.z_ratio_courseoport#ib1.asyl_req_stat ///
    [pweight=weight_p], vce(cluster pid)
mi test 2.asyl_req_stat#c.z_ratio_courseoport ///
    3.asyl_req_stat#c.z_ratio_courseoport
_mi_addstats m_e2cont
mimrgns using $mydata/msuemer/ext_e2_cont, esample(m_e2cont) ///
    dydx(z_ratio_courseoport) over(asyl_req_stat) cmdmargins

esttab m_e2cert m_e2cont, ///
    title("COURSE SUPPLY x ASYLUM STATUS: certificate and contact") ///
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
    mtitles("Language certificate obtainment" ///
        "Contact frequency with Germans")

display "EXT E2 secondary ok"
