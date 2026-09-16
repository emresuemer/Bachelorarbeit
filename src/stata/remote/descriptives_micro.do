*==============================================================================*
* descriptives_micro.do                     (was 00022_descr_micro_remote.do)
*
* Purpose : Individual-level descriptives on the analytic sample. Produces the
*           paper's Table 2 (its main deliverable), plus the two Cronbach
*           alphas, the correlation matrix of paper Table S7, and the weighted
*           by-year trends quoted in the Measures section.
* Source  : 00022_descr_analyses_micro.do (whole file)
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : nothing -- this job returns numbers only
* Result  : results/comparisons/tab02_descriptives.md (transcript + comparison)
*           results/tables/tab02_descriptives.tex (thesis table)
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-13
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* NAMING: named for what it does, not for the exhibit. The repo convention
* reserves an exhibit prefix (table02_*) for files whose ONLY output is that
* exhibit; this one also returns Table S7 and the Measures-section statistics.
*
* NOTE ON UNIMPUTED DATA: `mi extract 0` keeps m = 0, so every descriptive
* below is complete-case on the ORIGINAL data. That is the authors' choice,
* not a porting artifact -- the imputations are not used here at all.
* Consequence worth knowing: Table 2 does NOT depend on the imputation draw,
* so it is reproducible across runs even though `mi impute chained` is
* stochastic. It depends only on the analytic sample.
*
* ---------------- FORCED DEVIATIONS ----------------
* (1) do config / cd / log using / capture log close / exit / set matsize
*     REMOVED.
* (2) #delimit -> the global-append form used in clean_sample.
* (3) `asdoc ... save($output/Table_S7.doc)` REMOVED. It writes a Word file
*     that cannot come back from SOEPremote. No loss: the two `pwcorr` lines
*     immediately above it print the same correlations, unweighted and
*     weighted. The only thing lost is asdoc's Bonferroni adjustment, so the
*     `sig` p-values returned here are unadjusted -- adjust locally if the
*     thesis reproduces Table S7 verbatim. (Note the original passes
*     star(0.5), which is almost certainly a typo for star(0.05); the plain
*     pwcorr lines use star(0.05).)
* (4) THE WHOLE putexcel/matrix Table A1 MACHINERY IS REPLACED. It builds a
*     40x5 matrix and writes Table_A1.xlsx -- which the paper prints as its
*     Table 2. Three separate blockers: the .xlsx cannot be retrieved,
*     `matrix list` contains the banned token `list`, and `matrix drop _all`
*     contains `drop`. Replaced by a loop that displays the same five
*     statistics per variable as plain text, in the same variable order, plus
*     each variable's label. Transcribe locally into results/ -- that is the
*     citable artifact, exactly as was done for the sample funnel.
* (5) `matrix list temp` on the freshly-created J(40,5,.) matrix printed 200
*     missing values and nothing else; removed as pointless as well as
*     banned.
*
* ---------------- LOOPS ARE ALLOWED ----------------
* `18_loop_probe.do` returned all four PROBE lines on 2026-08-07, so
* `local`, `foreach`, `foreach ... of varlist`, `forvalues` and backtick
* substitution are confirmed safe. The loops below are therefore the
* authors' own, not unrolled, which keeps this file directly comparable
* with the original.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
*   count                     -> 5,467 before mi extract, 5,467 after
*   xtdescribe                -> n = 2,730
*   the four alpha values     -> the German scale and the contact scale.
*        The paper states 0.937 for the German scale (Measures section).
*   TABLE A1 lines            -> 40 variables, five statistics each. These
*        ARE the paper's Table 2; transcribe all forty.
*   A1LAB lines               -> the authors' own variable labels. Read the
*        three asyl_req_stat labels carefully: the published Table 2 rotates
*        them by one (see the comparison write-up).
*   the by-year sum() tables  -> employment and German proficiency trends,
*        directly comparable with the paper's descriptive section.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/descriptives_micro.do
*==============================================================================*

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/sample_imputed, clear
mi xtset pid syear
count

mi extract 0
count
xtdescribe

tabulate syear [aweight = weight_p], sum(paid_work)

alpha speak_german read_german write_german, i
tabulate syear [aweight = weight_p], sum(german_additive)

gen good_german = 1 if speak_german >= 3 & read_german >= 3 ///
    & write_german >= 3 & german_additive < .
recode good_german .= 0 if german_additive < .
tabulate syear [aweight = weight_p], sum(good_german)

tabulate syear [aweight = weight_p], sum(int_course_finished)
tabulate syear [aweight = weight_p], sum(germ_cert_any)
tabulate syear [aweight = weight_p], sum(time_germ)

gen daily_contact = time_germ == 5 if time_germ < .
gen never_contact = time_germ == 0 if time_germ < .
tabulate syear [aweight = weight_p], sum(daily_contact)
tabulate syear [aweight = weight_p], sum(never_contact)

alpha time_germ time_contact_gfr time_contact_gnb ///
    time_contact_gjb, i

pwcorr paid_work german_additive int_course_finished ///
    germ_cert_any time_germ, sig star(0.05)
pwcorr paid_work german_additive int_course_finished ///
    germ_cert_any time_germ [aweight = weight_p], sig star(0.05)

summarize init_course_opport, detail

tabulate asyl_req_stat, gen(asyl_req_stat)
tabulate immigroup_nat, gen(immigroup)
tabulate msample, gen(msample)
tabulate syear, gen(syear)

global vars1 paid_work german_additive int_course_finished
global vars1 $vars1 germ_cert_any time_germ z_ratio_courseoport
global vars1 $vars1 stay_dur total_years_edu0 work0 female h_child
global vars1 $vars1 arriv_fam family0 age1st trauma_exp
global vars1 $vars1 asyl_req_stat1 asyl_req_stat2 asyl_req_stat3
global vars1 $vars1 z_foreign_share z_density z_unemplrate
global vars1 $vars1 z_consimmi z_cdu
global vars1 $vars1 msample1 msample2 msample3
global vars1 $vars1 immigroup1 immigroup2 immigroup3 immigroup4
global vars1 $vars1 immigroup5 immigroup6 immigroup7 immigroup8
global vars1 $vars1 immigroup9 immigroup10
global vars1 $vars1 syear1 syear2 syear3 syear4

display "TABLE A1 variable mean sd n min max"
foreach var of varlist $vars1 {
    quietly summarize `var'
    display "A1 `var' " %10.4f r(mean) " " %10.4f r(sd) ///
        " " %8.0f r(N) " " %10.4f r(min) " " %10.4f r(max)
}

display "TABLE A1 labels"
foreach var of varlist $vars1 {
    local lab : variable label `var'
    display "A1LAB `var' : `lab'"
}

display "22 ok"
