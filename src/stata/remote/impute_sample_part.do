*==============================================================================*
* impute_sample_part.do                     (was 00014B_data_mi_remote.do)
*
* Purpose : The authors' SECOND chained imputation (M = 20), built for a
*           reviewer's question about PARTICIPATION in an integration course
*           rather than completion of one. Shared infrastructure like
*           impute_sample.do, but it feeds exactly one consumer: the
*           extension's ext_asyl_participation.do.
* Source  : 00014_data_mi.do:240-355
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_sample.do -> $mydata/msuemer/sample_analytic
* Saves   : $mydata/msuemer/sample_imputed_part
*           (5,467 obs, M = 20, 8 imputed vars, stored FLONG)
* Result  : no exhibit of its own; its consumer's numbers land in
*           results/comparisons/ext_asyl_mediators.md
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-30
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* WHY THIS IS BEING RUN NOW
*
* It is the last unmigrated job of the port (see docs/lab_notebook.md), and it was
* never re-run on the 2026-08-13 cold rebuild -- so sample_imputed_part does
* NOT exist on the server under that name. The extension needs it: the
* rationing hypothesis H2 is about whether county supply converts into actual
* ENROLMENT differently by legal entitlement, and int_course_part is the only
* variable that measures enrolment. It is also far better covered than the
* completion variable -- about 39 incomplete observations against 270 -- so it
* is the least imputation-dependent of the five mediators.
*
* ---------------- HOW IT DIFFERS FROM impute_sample.do ----------------
* In exactly two ways, both in the imputation model, neither anywhere else:
*   $imputedDV     german_additive int_course_part
*                  (instead of german_additive int_course_finished
*                   germ_cert_any contacts_germ time_germ)
*   $imputedHelpv  family0        (loses german_interview)
* The regular predictors, the weight, the seed, the flong post-processing and
* the five time-invariant repairs are all identical.
*
* ---------------- EVERY GLOBAL IS RESTATED ----------------
* orig :240 onward silently reuses $regularDV, $regularIdV, $imputedIdV and
* $weight from the first half of the file, because for the authors it is one
* Stata session. GLOBALS DO NOT SURVIVE BETWEEN SOEPREMOTE JOBS, so all four
* are restated in the send block. Removing them would leave mi impute with
* empty macros and it would fail in a way that is easy to misread as a data
* problem.
*
* ---------------- FORCED DEVIATIONS ----------------
* Inherited from impute_sample.do, unchanged:
* (1) do config / cd / log using / capture log close / exit REMOVED.
* (2) #delimit globals -> the append form used throughout the port.
* (3) `set matsize 500` REMOVED -- obsolete from Stata 16; the server is
*     MP 19.5, so it cannot affect results.
* (4) drop -> soepdrop.
* (5) The pid loop at orig :218-231 is replaced by the set-wise flong form,
*     as in impute_sample.do. See that file's header for the full argument:
*     in wide form the M copies are separate columns, which is what forces a
*     loop; in flong they are one column indexed by _mi_m, so one bysort does
*     all 20 at once. `if _mi_m > 0` is load-bearing -- m = 0 is the ORIGINAL
*     data with its real missing values.
* This job's own:
* (6) None. The send block is byte-identical to the pre-migration file; only
*     this header changed.
*
* ---------------- IT IS SAVED FLONG, DELIBERATELY ----------------
* Unlike impute_sample.do there is no `mi convert wide` before the save,
* because orig :340 does not do one either. So the stored state is not the
* analysis state: mi has not run mi update, and values will shift on first
* use. That is the authors' own file shape and is preserved.
*
* CONSEQUENCE FOR THE CONSUMER: the first mi command in
* ext_asyl_participation.do runs that consistency pass, so some values shift
* when the file is first opened there. It cannot be made explicit -- the
* obvious command for it is blocked by SOEPremote's scanner (see that file's
* header, revision 2026-08-30), and it is unnecessary anyway, because every mi
* command performs the pass itself when it needs to.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
*   count                            -> 5,467 in, 5,467 out
*   summarize $regularDV $regularIdV -> EVERY regular variable must show
*        Obs = 5,467. mi impute requires complete predictors, so a short
*        count here is the likeliest cause of a failure below and is worth
*        reading before anything else.
*   the imputation report            -> 20 imputations, 8 variables
*   mi describe                      -> M = 20, 5,467 obs, and int_course_part
*        listed among the imputed variables with about 39 incomplete
*        observations. That figure is the whole reason this file exists;
*        if it comes back near 270 the wrong variable is being imputed.
*   the "N real changes made" lines after each replace -> evidence the
*        post-processing worked. xtsum cannot be used here (see below).
*   the `... .dta saved` line -> the ONLY completion signal that matters.
*        A truncated job looks exactly like a short one that succeeded.
*
* ---------------- ONE OUTPUT LINE THAT LOOKS LIKE AN ERROR ----------------
* `xtset pid syear` runs BEFORE `mi set`, so it is fine here. It is only
* after mi set that it fails with r(119) ("Use mi xtset") -- which is why
* impute_sample.do has no xtsum in its post-processing block.
*
* > This job draws 20 imputations and is expensive. If it comes back slowly
* > that is the imputation, not a problem. Do not resend without checking
* > for a reply first.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py \
*       src/stata/remote/impute_sample_part.do
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

global imputedDV german_additive int_course_part

global imputedIdV work0 total_years_edu0 h_child arriv_fam trauma_exp

global weight weight_p

global imputedHelpv family0

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

mi describe
count

label data "Kanas and Kosyakova, 2022, remote port"
save $mydata/msuemer/sample_imputed_part, replace
display "14B ok"
