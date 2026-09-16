* ==========================================================================
* PORT OF THE SOEP-DERIVED BLOCK OF 00011_data_macro.do -- DOCUMENTATION,
* DO NOT SEND THIS HEADER
* ==========================================================================
* Original: 00011_data_macro.do lines 2480-2551 (author Yuliya Kosyakova),
* left untouched. This is a parallel file, per project convention.
*
* WHY THIS EXISTS AT ALL. The project notes assumed 00011 needs no SOEP
* microdata and therefore stays local. That is true of 55 of its 57 output
* columns, but NOT of two:
*
*   concern_immigration  = county-year share of natives with great concerns
*                          about immigration  (from pl.dta plj0046)
*   volunt               = county-year share doing weekly voluntary work
*                          (from pl.dta pli0096_h)
*
* Both are built by collapsing SOEP person data BY kkz, so on the local EU
* edition (kkz == -7 everywhere) they come out 100% missing -- confirmed:
* both columns of savedata/macro_data.dta are entirely missing. They cannot
* be embedded via input because there is nothing to embed.
*
* This matters: concern_immigration becomes init_concern_immigration ->
* z_consimmi, which is a control in EVERY main specification of
* 00023_mult_analyses.do (:65, :227, :408) and in 00022 (:151). Without this
* job the replication is short one published control variable.
*
* volunt is carried for fidelity only -- init_volunt appears in 00013's
* $vars but is read by nothing downstream.
*
* ---------------- FORCED DEVIATIONS, ALL MECHANICAL ----------------
* (1) $SOEPv36 -> $soep36, $dataout -> $mydata/msuemer.
* (2) keep/drop -> soepkeep/soepdrop.
* (3) keepusing() -> banned (contains keep). Replaced with the authors' own
*     preserve / restricted-use / save-temp / merge idiom, exactly as in
*     00012_data_merge_remote.do.
* (4) The hl.dta and hpathl.dta merges (orig :2486-2491) are OMITTED. They
*     fetch hlf0147, hlf0136 and hhrf, none of which is referenced anywhere
*     in this block, and both use `keep if _merge != 2`, which drops no
*     master rows. So omitting them cannot change either output. Verified by
*     reading the block through to its two saves.
* (5) duplicates drop (orig :2528, :2547) -> banned (contains drop) and
*     redundant: collapse already returns one row per by-group. The
*     authors' own `isid kkz year` immediately after is kept and is the
*     real guard.
* (6) The *100 rescaling (orig :2691, :2698) happens in 13_supply_assemble,
*     which is where the original applies it too.
*
* EXPECTED OUTPUT. Roughly 400 counties x 7 years in each saved file, i.e.
* on the order of 2,500-2,800 rows, means in [0,1] before the *100. A count
* far below that means the regionl merge failed.
*
* Preflight before sending:
*   python3 remote/tools/preflight.py remote/jobs/*.do
*
* ==========================================================================

* SEND FROM HERE DOWN

use pid hid syear plj0046 pli0096_h using $soep36/pl, clear
soepkeep if syear >= 2013
count

preserve
use pid syear migback phrf using $soep36/ppathl, clear
save $mydata/msuemer/tmp_ppathl, replace
restore

merge 1:1 pid syear using $mydata/msuemer/tmp_ppathl
soepkeep if _merge != 2
soepdrop _merge

preserve
use hid syear kkz using $soep36/regionl, clear
save $mydata/msuemer/tmp_regionl_w, replace
restore

merge m:1 hid syear using $mydata/msuemer/tmp_regionl_w
soepkeep if _merge == 3
soepdrop _merge
count

recode kkz (11100 11200 = 11000)
recode kkz (3156 3152 3159 = 3152)
recode kkz (9561 9571 = 9561)

preserve
tabulate migback
soepkeep if migback == 1
gen concern_immigration = 1 if inlist(plj0046,1)
replace concern_immigration = 0 if inlist(plj0046,2,3)
tabulate concern_immigration plj0046, m
collapse (mean) concern_immigration [pweight=phrf], by(kkz syear)
rename syear year
isid kkz year
count
summarize concern_immigration
save $mydata/msuemer/soep_xeno, replace
restore

gen volunt = pli0096_h <= 2 if pli0096_h > 0 & pli0096_h < .
tabulate volunt pli0096_h, m
bysort pid (syear): carryforward volunt, replace
collapse (mean) volunt [pweight=phrf], by(kkz syear)
rename syear year
isid kkz year
count
summarize volunt
save $mydata/msuemer/soep_volunt, replace
display "12 soepvars ok"
