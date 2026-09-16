*==============================================================================*
* clean_county_merge.do
*
* Purpose : Merges the county course-supply panel on kkz1st x year. THE STEP THE WHOLE
*           PROJECT WAS BLOCKED ON; locally it fails on 18,342 of 18,342 rows.
* Source  : 00013_data_clean.do:685-791
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_geography -> clean_geography
*           supply_assemble -> cty_supply  (2,807 x 16, 401 per year)
* Saves   : $mydata/msuemer/clean_county  (18,342 x 266, verified 2026-08-13)
* Deviates: see the FORCED DEVIATIONS notes below
* Author  : Emre Suemer
*==============================================================================*
* ==========================================================================
* PORT OF 00013_data_clean.do, PART B (orig lines 685-791)
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
* The two macro-data merges: attaches the county-year language-course supply
* and the regional confounders to each refugee, keyed on the county they were
* first allocated to (kkz1st) in the year before arrival.
*
* THIS IS THE STEP THE WHOLE PROJECT WAS BLOCKED ON. Locally it fails 100%
* (18,342 of 18,342 "master only") because the EU edition redacts kkz to -7,
* so init_course_opport -- the paper's treatment -- could never be built. It
* is now buildable: kkz1st is real on $soep36 (16,186 person-years, 354
* counties, verified by Part A2) and cty_supply.dta is on the server (2,807
* county-years, verified by jobs 11/13/14).
*
* DO NOT SEND UNTIL A2'S LISTING SHOWS:
*     file /srv/cifs/lissy-users-data/msuemer/clean_geography.dta saved
* and job 14 has confirmed cty_supply.dta reads back at 2,807 observations.
* A missing input does not halt a SOEPremote job -- it would return a long
* listing of errors that still ends in "end of do-file".
*
* ---------------- FORCED DEVIATIONS, ALL MECHANICAL ----------------
* (1) $dataout/macro_data.dta -> $mydata/msuemer/cty_supply. The remote file
*     is deliberately not named macro_data: that tokenises to a standalone
*     `macro`, which the scanner bans.
* (2) keep/drop -> soepkeep/soepdrop.
* (3) ONE merge instead of two. The original merges the same file twice on
*     the same key: first with keepusing() for the course block, then again
*     for the confounders, dropping the course columns the second time round
*     (orig :690, :746, :756). keepusing() is banned (it contains `keep`),
*     and with only the transmitted columns present there is nothing for the
*     second pass to add. One merge is exactly equivalent here.
* (4) codebook dropped (orig :702-710). Every variable it described --
*     eligible, nparticipants, courses_startet, course_opport2 -- is one of
*     the untransmitted columns below, so the calls would error anyway.
* (5) The 43-variable `ren (...) init_=` (orig :782-788) becomes explicit
*     renames of the 14 columns that exist. Same result, and it fails loudly
*     rather than silently if a column is missing.
*
* ---------------- THE 30 COLUMNS THAT ARE NOT TRANSMITTED ----------------
* macro_data has 43 columns the original renames to init_*; cty_supply
* carries 14 of them. Absent: reg_area reg_pop gdp gdp_per_employed ref_wait
* ref_approved ref_reject SYR AFG IRQ spd_votes koenigst_key al_vac
* al_vac_exp al_vac_spec al_vac_skill al_vac_unskill vac_exp vac_spec
* vac_skill vac_unskill hospital_bet unemp_for emp_for_nat shb2sh rentprice
* av_age ref_share_bev ref_share_for vac_hous2012, plus the course-block
* extras graduates eligible nparticipants courses_startet courses_finished
* course_opport2.
*
* Re-verified 2026-08-07 by grepping init_<name> across 00014, 00022, 00023
* and 00024: NONE of the 30 is read by any of them. They appear only in
* 00013's own $vars list, which Part E must be trimmed to match -- that is
* the single place this decision shows up, and it is Part E's problem, not
* this job's.
*
* ---------------- THE COUNTY RECODE ----------------
* `recode kkz (3159 = 3152) (11100 11200 = 11000)` is the original's, kept
* verbatim. It composes with the recodes A2 already applied to kkz1st
* (3156 -> 3159; 5313/5354 -> 5334; 13005/13057/13061 -> 13073; 11100/11200
* -> 11000). Checked against savedata/macro_data.dta: 3152, 11000, 5334 and
* 13073 are present there and 3156, 3159, 11100, 11200, 5313, 5354, 13005
* are not, so after this line every SOEP county code exists on the macro
* side. 9561/9571 are both present and are NOT recoded here -- that pairing
* belongs to job 12's SOEP-derived columns and was already handled, and
* undone, inside 13_supply_assemble.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
*   count                                      -> 18,342, unchanged. This
*        job drops no rows: soepkeep if _merge != 2 removes only using-only
*        county-years, never a person.
*   the two "eligible for merge" / "matched" counts -> MUST BE EQUAL. That
*        pair is the real test, and it is what the assert enforces.
*   assert _merge == 3 ...                     -> must produce NO output.
*   count if init_course_opport < .            -> equals the matched count.
*   summarize init_course_opport               -> mean near .05, max 1,
*        matching cty_supply's own distribution (job 14: mean .0499).
*
* > A FAILED assert DOES NOT STOP THE JOB. SOEPremote prints runtime errors
* > and carries on, so this job would still reach its save and still print
* > "13B ok". Read the listing for "assertion is false" before treating the
* > saved file as good -- exactly the trap that let a missing supply part
* > through jobs 11, 13 and 14 on 2026-08-07.
*
* Expect init_course_opport to be missing for a substantial minority even
* when kkz1st is known: the merge year is arrival_yr - 1, and cty_supply
* starts at 2013, so anyone who arrived in 2013 or earlier cannot match.
* Those rows are removed later by Part E's sample restriction (the original
* comments this at :693, "restricted to arrivals between 2014-2019"), so a
* gap here is expected and is not a merge failure. The assert is scoped to
* year >= 2013 precisely for this reason.
*
* ---------------- WHY IT IS SAFE TO END BY DROPPING _merge, kkz, year ----
* The original leaves _merge and kkz in memory and drops only `year` (orig
* :790). Checked across orig :792-2057: bare `kkz` is never referenced again
* (0 hits), and the next merge, Melitz-Toubal at :1005, opens with its own
* `capture drop _merge`. So clearing all three here changes nothing and
* leaves the dataset tidier for Part C. `year` is regenerated immediately as
* `gen year = syear` at :793, which is Part C's first line.
*
* Pre-flight before sending:
*   python3 remote/tools/preflight.py remote/00013B_data_clean_remote.do
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/clean_geography, clear
count

gen year = arrival_yr - 1
capture soepdrop kkz
gen kkz = kkz1st
recode kkz (3159 = 3152) (11100 11200 = 11000)

label var year "year before arrival"
label var kkz "1st county, merge key"

tabulate year, m
count if kkz > 0 & kkz < .
count if kkz > 0 & kkz < . & year >= 2013 & year < .

merge m:1 kkz year using $mydata/msuemer/cty_supply
soepkeep if _merge != 2

tabulate year if _merge != 3, m
capture noisily tabulate kkz year ///
    if _merge != 3 & year >= 2013 & year < ., m
assert _merge == 3 if year >= 2013 & year < . & kkz > 0 & kkz < .
count if _merge == 3

summarize course_opport foreign_share reg_unemplrate reg_density
summarize tax gdp_per_resident refugee hospital_bet2012
summarize land_cons vac_hous afd_votes cdu_csu_votes
summarize concern_immigration volunt

soepdrop _merge kkz year

rename (course_opport foreign_share) ///
    (init_course_opport init_foreign_share)
rename (reg_unemplrate reg_density) ///
    (init_reg_unemplrate init_reg_density)
rename (tax gdp_per_resident) ///
    (init_tax init_gdp_per_resident)
rename (refugee hospital_bet2012) ///
    (init_refugee init_hospital_bet2012)
rename (land_cons vac_hous) ///
    (init_land_cons init_vac_hous)
rename (afd_votes cdu_csu_votes) ///
    (init_afd_votes init_cdu_csu_votes)
rename (concern_immigration volunt) ///
    (init_concern_immigration init_volunt)

count
count if init_course_opport < .
summarize init_course_opport init_concern_immigration
xtset pid syear
xtsum init_course_opport
describe, short
save $mydata/msuemer/clean_county, replace
display "13B ok"
