*==============================================================================*
* impute_sample.do                          (was 00014A_data_mi_remote.do)
*
* Purpose : Chained multiple imputation (M = 20) on the analytic sample. This is
*           shared infrastructure, not one exhibit's: its output feeds the
*           descriptives (paper Table 2) and every regression (Tables 3-5).
* Source  : 00014_data_mi.do:60-225
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_sample.do -> $mydata/msuemer/sample_analytic
* Saves   : $mydata/msuemer/sample_imputed  (5,467 obs, M = 20, 12 imputed vars)
* Result  : results/comparisons/tab02_descriptives.md records the figures its
*           consumer returns; this job itself returns diagnostics only.
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-13
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* THIS IS THE STEP THAT WAS HARD-BLOCKED LOCALLY: it failed at
* `mi impute chained ... pmm` with "no observations" (r(2000)) because every
* z_* regional predictor was degenerate -- 0 non-missing of 952. All twelve
* are now real, built from cty_supply.
*
* ---------------- THE pid LOOP IS REPLACED, NOT PORTED ----------------
* orig :218-231 post-processes the imputations so that time-invariant
* variables stay time-invariant, using
*
*     qui: levelsof pid, local(timeinv)
*     foreach i of local timeinv {
*         foreach j of varlist _*work0 _*total_years_edu0 ... {
*             qui: sum `j' if pid==`i'
*             qui: replace `j'=round(r(mean),1) if pid==`i'
*
* Loops and backtick substitution are confirmed safe on SOEPremote
* (18_loop_probe.do, 2026-08-07), so that is no longer the reason. The reason
* that remains: it is 2,730 pids x 100 variables (5 variables x M = 20) =
* 273,000 sum + replace pairs, which risks the batch runner's patience for no
* analytical gain.
*
* Replaced with the same computation done set-wise, in flong form. In wide
* form the M copies are separate columns (_1_work0 ... _20_work0), which is
* what forces a loop; in flong they are one column indexed by _mi_m, so a
* single bysort does all 20 at once:
*
*     bysort _mi_m pid: egen z1 = mean(work0)
*     replace work0 = round(z1) if _mi_m > 0
*
* `if _mi_m > 0` is load-bearing: m = 0 is the ORIGINAL data with its real
* missing values, which the wide-form `_*work0` wildcard never touches
* either (there is no _0_ copy in wide style). Without the condition this
* would overwrite the observed data.
*
* `mi convert` is documented as lossless and the file is converted back to
* wide before saving, so the stored format matches the original exactly.
* Note orig :340 does `mi convert flong` for the V2 file anyway.
*
* ---------------- FORCED DEVIATIONS ----------------
* (1) do config / cd / log using / capture log close / exit REMOVED.
* (2) #delimit globals -> the append form used in clean_sample.
* (3) `set matsize 500` REMOVED -- matsize is obsolete from Stata 16 and the
*     server is MP 19.5. It cannot affect results.
* (4) drop -> soepdrop.
*
* ---------------- PRESERVED THAT LOOKS WRONG ----------------
* paid_work and fptime_work appear in BOTH $regularDV and $regularIdV, so
* the impute command lists each twice. That is the authors' own code and it
* evidently ran for them; left as is.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
*   count                            -> 5,467 in, 5,467 out
*   summarize $regularDV $regularIdV -> EVERY regular variable must show
*        Obs = 5,467. mi impute requires complete predictors; a short count
*        here is the most likely cause of a failure below, and is worth
*        reading before anything else.
*   the imputation report            -> 20 imputations, 12 variables
*   mi describe                      -> M = 20, 5,467 obs
*   the "N real changes made" lines after each replace -> this is the
*        evidence the post-processing worked; xtsum cannot be used here
*        because the data are mi set (see the r(119) note below).
*   trauma_exp and contacts_germ are the worst-covered inputs (about 1,975
*        and 1,757 incomplete). int_course_part has far fewer incomplete
*        observations than int_course_finished, which is the whole point of
*        the reviewer variant in 00014B.
*
* ---------------- TWO OUTPUT LINES THAT LOOK LIKE ERRORS ----------------
* (a) `xtset pid syear` on mi-set data fails with r(119) ("Use mi xtset").
*     The original never hits this because it never re-xtsets after mi set.
*     Removed; a plain summarize is used instead. Diagnostic only.
* (b) `mi convert wide` reports "N values of imputed variable X in m>0
*     updated to match values in m=0". That is NOT damage: mi enforces the
*     invariant that imputed variables equal the observed data wherever the
*     observed data exist. The authors' own loop violates the same invariant
*     (it overwrites every row of a pid, observed or not), so their saved
*     file carries the inconsistency until the first mi command runs
*     mi update and reverts exactly the same cells. Net values are identical;
*     ours are simply already consistent on disk.
*
* > This job is expensive -- it draws 20 imputations. If it comes back slowly,
* > that is the imputation, not a problem. Do not resend it without checking
* > for a reply first.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/impute_sample.do
*==============================================================================*

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/sample_analytic, clear
count

egen z_foreign_share = std(init_foreign_share)
egen z_unemplrate = std(init_reg_unemplrate)
egen z_density = std(init_reg_density)
egen z_tax = std(init_tax)
egen z_gdp_resid = std(init_gdp_per_resident)
egen z_refu = std(init_refugee)
egen z_hospital_bet2012 = std(init_hospital_bet2012)
egen z_land = std(init_land_cons)
egen z_vac_hous = std(init_vac_hous)
egen z_consimmi = std(init_concern_immigration)
egen z_afd = std(init_afd_votes)
egen z_cdu = std(init_cdu_csu_votes)

global regularDV paid_work fptime_work

global regularIdV syear stay_dur msample female age1st
global regularIdV $regularIdV immigroup_nat asyl_req_stat
global regularIdV $regularIdV z_foreign_share z_density z_unemplrate
global regularIdV $regularIdV z_ratio_courseoport z_tax z_gdp_resid
global regularIdV $regularIdV z_refu z_hospital_bet2012
global regularIdV $regularIdV z_land z_vac_hous
global regularIdV $regularIdV z_consimmi z_afd z_cdu
global regularIdV $regularIdV regierungsbezirk nuts1_first
global regularIdV $regularIdV paid_work fptime_work

global imputedDV german_additive int_course_finished
global imputedDV $imputedDV germ_cert_any contacts_germ time_germ

global imputedIdV work0 total_years_edu0 h_child arriv_fam trauma_exp

global weight weight_p

global imputedHelpv family0 german_interview

summarize $regularDV $regularIdV
summarize $imputedDV $imputedIdV $imputedHelpv

capture stset, clear
xtset pid syear
xtdescribe

capture mi unset
mi set wide
mi set M = 20

mi register regular $regularDV
mi register regular $regularIdV
mi register imputed $imputedDV
mi register imputed $imputedIdV $imputedHelpv

mi impute chained (pmm, knn(1)) $imputedDV $imputedIdV $imputedHelpv ///
    = $regularDV $regularIdV [pweight=$weight], ///
    rseed(12345) replace report dots

mi describe

mi convert flong, clear

bysort _mi_m pid: egen double z1 = mean(work0)
replace work0 = round(z1) if _mi_m > 0
soepdrop z1

bysort _mi_m pid: egen double z2 = mean(total_years_edu0)
replace total_years_edu0 = round(z2) if _mi_m > 0
soepdrop z2

bysort _mi_m pid: egen double z3 = mean(family0)
replace family0 = round(z3) if _mi_m > 0
soepdrop z3

bysort _mi_m pid: egen double z4 = mean(arriv_fam)
replace arriv_fam = round(z4) if _mi_m > 0
soepdrop z4

bysort _mi_m pid: egen double z5 = mean(trauma_exp)
replace trauma_exp = round(z5) if _mi_m > 0
soepdrop z5

summarize work0 total_years_edu0 family0 arriv_fam trauma_exp

mi convert wide, clear
mi describe
count

label data "Kanas and Kosyakova, 2022, remote port"
save $mydata/msuemer/sample_imputed, replace
display "14A ok"
