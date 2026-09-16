*==============================================================================*
* clean_sample.do                          (was 00013E_data_clean_remote.do)
*
* Purpose : Paper Table 1: the 11-step sample-selection funnel. Trims to the
*           analysis variables, then applies each exclusion in turn. The funnel
*           IS the exhibit: it produces the analytic N compared to the paper.
* Source  : 00013_data_clean.do:1613-2057
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_asylum -> clean_asylum   (confirm its ".dta saved" line first)
* Saves   : $mydata/msuemer/sample_full        (18,342, with sample_select)
*           $mydata/msuemer/sample_analytic  (5,467 x 81)
* Result  : results/comparisons/tab01_sample_funnel.md
* Deviates: $vars trimmed 119 -> 84; putexcel/list/matrix drop removed;
*           see FORCED DEVIATIONS below for all eight, with reasons
* Author  : Emre Suemer  ·  2026-08-07
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
*
* The last piece of 00013: trim to the analysis variables, then run the
* sample-selection funnel. THE FUNNEL OUTPUT IS THE POINT OF THIS JOB -- it
* produces the analytic N that gets compared against the published paper, and
* it is the number the whole port has been working towards.
*
* ---------------- $vars IS TRIMMED, AND THIS IS WHERE THAT LANDS ----------
* The original $vars names 119 variables; 35 of them are county columns that
* were never transmitted (Phase 3 sends 14 of macro_data's 43). `keep` errors
* on a name that does not exist, and a runtime error does NOT halt a
* SOEPremote job -- it would carry on and save a wrong file. So the list below
* is trimmed to 84.
*
* Removed: init_eligible, init_nparticipants, init_courses_startet,
* init_courses_finished, init_course_opport2, init_gdp,
* init_gdp_per_employed, init_shb2sh, the five init_al_vac*, the four
* init_vac_{exp,spec,skill,unskill}, init_reg_area, init_reg_pop,
* init_av_age, init_hospital_bet, init_rentprice, init_vac_hous2012,
* init_ref_{wait,approved,reject}, init_SYR, init_AFG, init_IRQ,
* init_koenigst_key, init_ref_share_{bev,for}, init_unemp_for,
* init_emp_for_nat, init_spd_votes.
*
* Verified 2026-08-07 by grepping init_<name> across 00014, 00022, 00023 and
* 00024: none of the 35 is read by any of them. Also verified that every one
* of the 84 kept names is created by 00012 or by Parts A-D of this port.
*
* Consequence: `order ... after(init_course_opport2)` becomes
* after(init_course_opport), since the -2 variant no longer exists.
*
* ---------------- FORCED DEVIATIONS ----------------
* (1) keep/drop -> soepkeep/soepdrop.
* (2) #delimit blocks -> $vars built by appending to itself over several
*     lines. #delimit has never been proven against the scanner; this form
*     needs nothing new.
* (3) ALL putexcel REMOVED. It writes Table_1_$date.xlsx, and SOEPremote
*     returns a text listing only -- no file can come back, so the table
*     would be written into a directory we can never read. Every step keeps
*     its `xtsum pid` (which prints n and N) and gains a `display` naming the
*     step, so the funnel is reconstructable from the listing. Transcribe it
*     locally into results/ -- that is the citable artifact.
* (4) `list pid syear instrument if helpvar == 1` (orig :1762) REMOVED.
*     `list` is banned outright, and this one prints person-level rows, which
*     is exactly what the confidentiality screening exists to stop. It is a
*     comment-check on two named individuals; nothing downstream reads it.
* (5) `assert `Ns' == `Nf'` (orig :1725) REBUILT. `Ns` is set at orig :75,
*     i.e. in Part A1, and a local cannot cross jobs. It asserts that 00013
*     has not changed the row count, and that count is known and confirmed
*     four times over: 18,342. So the assert is written against the literal.
* (6) `matrix drop _all` (orig :2016) REMOVED -- it contains `drop`, and it
*     only clears matrices we never create.
* (7) putexcel close / capture log close / exit REMOVED.
* (8) The final `drop ... _merge ... _merge` (orig :2010) names _merge twice;
*     written once here.
*
* ---------------- WHY minusyear IS REGENERATED, NOT A BUG ----------------
* orig :81 and :1752 both `gen minusyear = -syear`, which would collide --
* except minusyear, n and N are not in $vars, so the keep above removes all
* three and :1752 legitimately recreates them. Same for n and N.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
* The funnel, in order, each preceded by its STEP line. Locally the
* equivalent chain ended at a CONTAMINATED 952 obs / 504 persons, because
* kkz1st was -7 for everyone (see the trap in docs/lab_notebook.md). The step that
* exposes it is "1st district is missing":
*
*   STEP 1 original data              -> 18,342 person-years
*   STEP 4 1st district is missing    -> locally this collapsed to 952.
*                                        Remotely it must NOT. Part B gave
*                                        14,505 rows with init_course_opport,
*                                        so expect the same order of
*                                        magnitude here.
*   STEP 10 zero/missing weights      -> the analytic sample.
*
* Compare the final N against the paper. A number near 952 means something
* upstream regressed; a number in the thousands is the replication working.
*
* > A failed assert does NOT stop a SOEPremote job. Read the listing.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/clean_sample.do
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/clean_asylum, clear
count
xtset pid syear

gen kkz1st_miss = kkz1st >= .
gen stay_dur = stay_durm/12
lab var stay_dur "Duration of stay, in years"

gen _____OUTCOMES_____ = .
gen _____REGIONAL_____ = .
gen _____CONTROLS_____ = .
gen _____SAMPLE_REST_____ = .

global vars pid syear weight_p intyear msample
global vars $vars _____OUTCOMES_____ paid_work fptime_work activity
global vars $vars ln_earnings labgro isei german_additive
global vars $vars speak_german read_german write_german
global vars $vars int_course_part int_course_finished int_course_curr
global vars $vars germ_cert germ_cert_any weekly_germ contacts_germ
global vars $vars _____REGIONAL_____ kkz1st diff_kkz regierungsbezirk
global vars $vars nuts1_first init_ost
global vars $vars init_course_opport init_reg_unemplrate
global vars $vars init_gdp_per_resident init_tax init_reg_density
global vars $vars init_hospital_bet2012 init_land_cons init_vac_hous
global vars $vars init_foreign_share init_refugee
global vars $vars init_afd_votes init_cdu_csu_votes
global vars $vars init_concern_immigration init_volunt
global vars $vars _____CONTROLS_____ female partner h_child
global vars $vars age1st age_arriv arrival_yr arrival_date
global vars $vars stay_duryr stay_durm stay_dur
global vars $vars citizenship_iso_num_tc immigroup_nat citiz_tc3
global vars $vars ln_ling_proximity ling_proximity
global vars $vars arriv_fam support0 friends0 family0
global vars $vars total_years_edu0 work0 asyl_req_stat
global vars $vars priv_accom healthy time_germ
global vars $vars time_contact_gfr time_contact_gnb time_contact_gjb
global vars $vars german0_additive german_interview health0 trauma_exp
global vars $vars _____SAMPLE_REST_____ instrument intdate kkz1st_miss
global vars $vars asylappl1st noasylappl inconsistentdates
global vars $vars restr_mobility_itt

soepkeep $vars
order $vars
describe, short

summarize pid
assert r(N) == 18342
save $mydata/msuemer/sample_full, replace

display "STEP 1 original data"
xtset pid syear
xtsum pid

bysort pid (syear): gen n = _n
bysort pid (syear): gen N = _N
gen minusyear = -syear

unique pid if inlist(instrument,95,103,105,151)
gen helpvar = 1 if inlist(instrument,95,103,105,151)
bysort pid (syear): carryforward helpvar, replace
bysort pid (minusyear): carryforward helpvar, replace
sort pid syear
soepdrop if inlist(instrument,95,103,105,151)
display "STEP 2 responded to the non-refugee questionnaire"
xtset pid syear
xtsum pid
soepdrop helpvar instrument

tabulate arrival_yr, m
gen intdate1st = intdate if n == 1
bysort pid (syear): carryforward intdate1st, replace
bysort pid (minusyear): carryforward intdate1st, replace
gen dur1st = intdate1st - arrival_date
gen syear1st = syear if n == 1
bysort pid (syear): carryforward syear1st, replace
bysort pid (minusyear): carryforward syear1st, replace
gen dur1styr = syear1st - arrival_yr
unique pid if dur1st <= 24
unique pid if dur1styr <= 2
soepkeep if dur1styr <= 2
display "STEP 3 initial interview within first two years"
xtset pid syear
xtsum pid
soepdrop intdate1st dur1st syear1st dur1styr intdate

soepkeep if kkz1st_miss == 0
display "STEP 4 1st district is missing"
xtset pid syear
xtsum pid
soepdrop kkz1st_miss

soepkeep if age1st >= 18 & age1st <= 64
display "STEP 5 aged under 18 or over 64 at first interview"
xtset pid syear
xtsum pid

soepkeep if immigroup_nat < .
display "STEP 6 missing on origin, stateless retained"
xtset pid syear
xtsum pid

soepkeep if noasylappl != 1
display "STEP 7 without asylum request"
xtset pid syear
xtsum pid
soepdrop noasylappl

soepkeep if asylappl1st == 1
display "STEP 8 more than one asylum request"
xtset pid syear
xtsum pid
soepdrop asylappl1st

soepkeep if inconsistentdates != 1
display "STEP 9 inconsistent application arrival decision dates"
xtset pid syear
xtsum pid
soepdrop inconsistentdates

soepkeep if restr_mobility_itt == 1
display "STEP 10 free to move or information missing"
xtset pid syear
xtsum pid

unique pid if weight_p <= 0 | weight_p >= .
soepdrop if weight_p <= 0 | weight_p >= .
display "STEP 11 zero or missing weights"
xtset pid syear
xtsum pid

soepdrop restr_mobility_itt _____SAMPLE_REST_____
soepdrop N n minusyear

bysort pid (syear): gen n = _n
bysort pid (syear): gen N = _N
unique pid
xtdescribe, patterns(20)
tabulate N
unique pid if N == 4
unique pid if N == 3
unique pid if N == 2
unique pid if N == 1
soepdrop N n

gen earning_sample = ln_earnings < .
gen isei_sample = isei < .
lab variable earning_sample "sample for earnings analyses"
lab variable isei_sample "sample for isei analyses"
replace isei = 0 if paid_work == 0
replace ln_earnings = 0 if paid_work == 0
order earning_sample isei_sample, after(msample)

gen ln_ratio_courseoport = ln(init_course_opport+0.000001)
label variable ln_ratio_courseoport "initial course opport, logarithm"
egen z_ratio_courseoport = std(init_course_opport)
label variable z_ratio_courseoport "initial course opport, std"
order ln_ratio_courseoport z_ratio_courseoport, ///
    after(init_course_opport)

gen init_ln_reg_density = ln(init_reg_density+0.000001)
label variable init_ln_reg_density "population density, logarithm"
order init_ln_reg_density, after(init_reg_density)

count
summarize z_ratio_courseoport init_course_opport
describe, short
save $mydata/msuemer/sample_analytic, replace
display "03 restricted saved"

use $mydata/msuemer/sample_full, clear
merge 1:1 pid syear using $mydata/msuemer/sample_analytic
gen sample_select = _merge == 3
lab var sample_select "Observations in the analytical sample"
soepdrop _merge earning_sample isei_sample
soepdrop ln_ratio_courseoport z_ratio_courseoport
tabulate sample_select, m
count
save $mydata/msuemer/sample_full, replace
display "13E ok"
