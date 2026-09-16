*==============================================================================*
* clean_asylum.do
*
* Purpose : Asylum application and decision dates, their consistency repair, and from them
*           restr_mobility_itt, whether a refugee was subject to the residency obligation.
* Source  : 00013_data_clean.do:1205-1607
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_confounders -> clean_confounders
* Saves   : $mydata/msuemer/clean_asylum  (18,342 x 298, verified 2026-08-13)
* Deviates: see the FORCED DEVIATIONS notes below
* Author  : Emre Suemer
*==============================================================================*
* ==========================================================================
* PORT OF 00013_data_clean.do, PART D (orig lines 1205-1607)
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
* Reads  $mydata/msuemer/clean_confounders
* Writes $mydata/msuemer/clean_asylum
*
* Do not send until 13C3's listing shows clean_confounders.dta saved.
*
* Asylum application and decision dates, and from them restr_mobility_itt --
* whether a refugee was subject to the residency obligation. This is the
* paper's second policy variable, the one that makes the allocation binding:
* without it the county assignment could be undone by moving.
*
* SENT AS ONE JOB (~230 send lines), against the 190-line budget the supply
* parts use. Justification: DIW's own ceiling is "etwa 200 bis 250", and
* 00013A1/A2 went through at 227/228 lines. Splitting here would be worse
* than it looks -- the asylum-date repair block below is a single long
* dependency chain (check -> inconsistentdates -> check2/check3), and a split
* mid-chain would have to carry six intermediate variables across jobs.
* Run check_clipboard.py before sending; it compares the composer against
* this file line by line, which is what makes a job this size safe.
*
* ---------------- FORCED DEVIATIONS, ALL MECHANICAL ----------------
* (1) keep/drop -> soepkeep/soepdrop (12 occurrences).
* (2) The `foreach var of varlist plj0677 plj0665 plj0668` loop (orig :1261)
*     is unrolled into three blocks, matching the Part A convention: macro
*     substitution and backticks remain untested against the scanner and
*     unrolling costs nothing analytically.
* (3) `drop check*` -> the four names spelled out, so a stray check-prefixed
*     variable could never be removed silently.
* (4) The duplicated `tabstat stay_durm ... by(year)` (orig :1533-1534, the
*     same line twice) is kept once.
* (5) Two variable LABELS are shortened to keep every line under 72 chars:
*     restr_mobility loses "; consider asylum application status, 6 months
*     before implement" and restr_mobility_itt loses ", intention to treat
*     design". Both are descriptive text no code reads. The full originals
*     are at 00013:1573 and :1600 if they are ever wanted for a codebook.
* (6) Diagnostic-only `tab`s on high-cardinality date variables are kept but
*     the two-way `tab request_asyl_date asyl_req_stat` is wrapped in
*     capture noisily: request_asyl_date is monthly over ~10 years, and the
*     local run already hit r(134) "too many values" on a comparable
*     two-way tabulate (see docs/lab_notebook.md, the kkz x year fix).
*
* ---------------- WHAT IS PRESERVED THAT LOOKS LIKE A BUG ----------------
* `asyl_req_stat` is only ever assigned 1, 2 or 3, but three lines test
* `== 4` (orig :1310, :1352, and the restr_mobility branch). Those branches
* can never fire. This is the authors' own code and is left exactly as is --
* "fixing" it would change the sample, not correct it. Expect the
* corresponding lines to report 0 changes.
*
* ---------------- CONFIDENTIALITY NOTE, READ BEFORE SENDING --------------
* This job contains ~30 lines of the form
*     replace request_asyl_date = ym(2015,8) if inlist(pid,37439102)
* i.e. explicit person identifiers, because the authors hand-corrected
* implausible asylum dates for those individuals. They are load-bearing:
* without them `inconsistentdates` flags real cases and the sample changes.
*
* Person IDs in submitted CODE are not the same as person-level OUTPUT, and
* SOEPremote screens output. But a job carrying 30 pids may still be pulled
* for manual review, which the documentation says can take up to 2 working
* days. If this one is slow to come back, that is the likely reason -- do
* not resend it, and do not assume it was rejected.
*
* ---------------- WHAT TO CHECK IN THE OUTPUT ----------------
*   count                          -> 18,342 throughout; this job drops no rows
*   tab asyl_req_stat, m           -> categories 1/2/3 only, none in 4
*   xtsum request_asyl_date        -> within sd 0 (it is time-constant by
*                                     construction after the helpvar chain)
*   tab restr_mobility_itt, m      -> THE headline number. Both 0 and 1 must
*                                     be well populated; if either is empty or
*                                     tiny, nuts1_first did not survive Part A
*                                     and the reform_date assignment silently
*                                     matched nothing.
*   tab diff_kkz, m                -> share who moved away from their assigned
*                                     county. Locally this was uncomputable.
*
* > As always: a failed assert or an error does NOT stop a SOEPremote job.
* > Read the listing before trusting the save.
*
* Pre-flight:
*   python3 remote/tools/preflight.py remote/00013D_data_clean_remote.do
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/clean_confounders, clear
count
xtset pid syear

gen plj0677_orig = plj0677
mvdecode plj0677, mv(-10/-1)
bysort pid (syear): carryforward plj0677, replace

gen plj0665_orig = plj0665
mvdecode plj0665, mv(-10/-1)
bysort pid (syear): carryforward plj0665, replace

gen plj0668_orig = plj0668
mvdecode plj0668, mv(-10/-1)
bysort pid (syear): carryforward plj0668, replace

bysort pid (minusyear): carryforward plj0665 plj0668, replace

gen asylappl1st = 1 if plj0668 == 1
replace asylappl1st = 1 if plj0665 == 1
bysort pid (syear): egen helpvar = max(asylappl1st)
replace asylappl1st = helpvar
recode asylappl1st . = 0
lab var asylappl1st "First asylum application"
replace asylappl1st = 0 if inlist(pid,38108601)
soepdrop helpvar

gen noasylappl = 1 if plj0665 == 1
bysort pid (syear): egen helpvar = max(noasylappl)
replace noasylappl = helpvar
recode noasylappl . = 0
lab var noasylappl "No asylum application"
soepdrop helpvar

label define asyl_req_stat 2 "approved" 3 "rejected" ///
    1 "no decision", replace
gen asyl_req_stat = .
lab val asyl_req_stat asyl_req_stat
lab var asyl_req_stat "status of asylum application"
replace asyl_req_stat = 2 if inlist(plj0677,1,2,3)
replace asyl_req_stat = 3 if inlist(plj0677,4,5)
replace asyl_req_stat = 1 if inlist(plj0674,2)
tabulate asyl_req_stat, m

gen request_asyl_yr = plj0666 if plj0666 > 0
replace request_asyl_yr = plm0531i01 ///
    if plm0531i01 > 0 & request_asyl_yr >= .
replace request_asyl_yr = plj0669 ///
    if plj0669 > 0 & request_asyl_yr >= .
lab var request_asyl_yr "request asylum: year"

gen request_asyl_mth = plj0667 if plj0667 > 0
replace request_asyl_mth = plm0531i02 ///
    if plm0531i02 > 0 & request_asyl_mth >= .
replace request_asyl_mth = plj0670 ///
    if plj0670 > 0 & request_asyl_mth >= .
lab var request_asyl_mth "request asylum: month"

gen request_asyl_date = ym(request_asyl_yr,request_asyl_mth)
lab var request_asyl_date "date of request of Asylum"
format request_asyl_date %tm
tabulate request_asyl_date, m
bysort pid (syear): carryforward request_asyl_date, replace
bysort pid (minusyear): carryforward request_asyl_date, replace
replace request_asyl_date = arrival_date if asyl_req_stat == 4

gen help_date = ym(plj0663,plj0664) if plj0663 > 0 & plj0664 > 0
replace request_asyl_date = help_date if request_asyl_date >= .
replace request_asyl_yr = plj0663 ///
    if request_asyl_yr >= . & plj0663 > 0 & request_asyl_date < .
replace request_asyl_mth = plj0664 ///
    if request_asyl_mth >= . & plj0664 > 0 & request_asyl_date < .
bysort pid (syear): carryforward request_asyl_date, replace
bysort pid (minusyear): carryforward request_asyl_date, replace

soepdrop n
bysort pid (syear): gen n = _n
capture soepdrop helpvar
gen helpvar = request_asyl_date if n == 1
bysort pid (syear): carryforward helpvar, replace
replace helpvar = request_asyl_date if helpvar >= . & n == 2
bysort pid (syear): carryforward helpvar, replace
bysort pid (minusyear): carryforward helpvar, replace
replace helpvar = request_asyl_date if helpvar >= . & n == 3
bysort pid (syear): carryforward helpvar, replace
bysort pid (minusyear): carryforward helpvar, replace
replace helpvar = request_asyl_date if helpvar >= . & n == 4
bysort pid (syear): carryforward helpvar, replace
bysort pid (minusyear): carryforward helpvar, replace
replace request_asyl_date = helpvar
soepdrop n N request_asyl_yr request_asyl_mth help_date helpvar
xtsum request_asyl_date

gen result_asyl_mth = plj0676 if plj0676 > 0
label var result_asyl_mth "result asylum: month"
gen result_asyl_yr = plj0675 if plj0675 > 0
label var result_asyl_yr "result asylum: year"
gen result_asyl_date = ym(result_asyl_yr, result_asyl_mth)
lab var result_asyl_date "date of result request for asylum"
format result_asyl_date %tm
replace result_asyl_date = arrival_date if asyl_req_stat == 4
bysort pid (syear): carryforward result_asyl_date, replace
soepdrop result_asyl_yr result_asyl_mth

bysort pid (syear): egen helpvar = first(result_asyl_date)
gen helpvar2 = asyl_req_stat if helpvar == result_asyl_date
bysort pid (syear): carryforward helpvar2, replace
xtsum helpvar helpvar2
replace result_asyl_date = helpvar
soepdrop helpvar
replace asyl_req_stat = helpvar2
soepdrop helpvar2

gen check = result_asyl_date - request_asyl_date
replace check = . if check >= 0
replace check = . if asylappl1st != 1
replace check = . if noasylappl == 1
tabulate check

replace result_asyl_date = request_asyl_date if check == -1
replace result_asyl_date = request_asyl_date if inlist(pid,36190701)
replace result_asyl_date = request_asyl_date if inlist(pid,36435101)
replace result_asyl_date = ym(2015,11) if inlist(pid,36581204)
replace request_asyl_date = arrival_date if inlist(pid,36782302)
replace result_asyl_date = ym(2015,12) if inlist(pid,36792902)
replace result_asyl_date = ym(2017,6) if inlist(pid,39223802)
replace request_asyl_date = ym(2015,8) if inlist(pid,37439102)
replace request_asyl_date = ym(2015,6) if inlist(pid,38315102)
replace request_asyl_date = ym(2015,12) if inlist(pid,37321403)
replace request_asyl_date = arrival_date if inlist(cid,3887995)
replace result_asyl_date = request_asyl_date if inlist(pid,37409701)
replace result_asyl_date = ym(2016,2) if inlist(pid,38160103)
replace result_asyl_date = ym(2016,1) if inlist(pid,36887104)
replace result_asyl_date = ym(2017,3) if inlist(pid,38806502)
replace result_asyl_date = ym(2017,3) if inlist(pid,39131801)
replace result_asyl_date = ym(2016,3) if inlist(pid,36889801)
replace request_asyl_date = ym(2016,1) if inlist(pid,38229001)
replace result_asyl_date = ym(2016,10) if inlist(pid,38329501)
replace result_asyl_date = ym(2016,6) if inlist(pid,38531901)
replace request_asyl_date = ym(2016,7) if inlist(pid,38664502)
replace request_asyl_date = ym(2015,9) if inlist(pid,38156301)
replace request_asyl_date = ym(2015,10) if inlist(pid,37208202)
replace request_asyl_date = ym(2015,6) if inlist(pid,38418105)
replace request_asyl_date = ym(2015,11) if inlist(pid,38725501)
replace request_asyl_date = result_asyl_date if inlist(pid,39168401)
replace request_asyl_date = result_asyl_date if inlist(pid,39223901)
replace request_asyl_date = result_asyl_date if inlist(pid,39224801)
replace request_asyl_date = result_asyl_date if inlist(pid,36788401)
replace result_asyl_date = request_asyl_date if inlist(pid,37838501)
replace result_asyl_date = request_asyl_date if inlist(pid,38220201)
replace result_asyl_date = request_asyl_date if inlist(pid,38871101)
replace result_asyl_date = request_asyl_date if inlist(pid,37816601)
replace request_asyl_date = ym(2015,1) if inlist(pid,38380602)
replace request_asyl_date = ym(2014,8) if inlist(pid,38500701)
soepdrop check

gen check = result_asyl_date - request_asyl_date
replace check = . if check >= 0
replace check = . if asylappl1st != 1
replace check = . if noasylappl == 1
gen check1m = intdate - result_asyl_date
tabulate check1m if check < ., m
bysort pid (syear): egen inconsistentdates = max(check)
recode inconsistentdates (-1000/-1 = 1)
tabulate check inconsistentdates, m

gen check2 = result_asyl_date - arrival_date
replace check2 = . if check >= 0
replace check2 = . if asylappl1st != 1
replace check2 = . if noasylappl == 1
replace check2 = . if inconsistentdates == 1
tabulate check2, m

gen check3 = request_asyl_date - arrival_date
replace check3 = . if check >= 0
replace check3 = . if asylappl1st != 1
replace check3 = . if noasylappl == 1
replace check3 = . if inconsistentdates == 1
tabulate check3, m
soepdrop check check1m check2 check3

capture noisily tabulate request_asyl_date asyl_req_stat ///
    if inconsistentdates != 1 & asylappl1st != 1 & noasylappl != 1, m

gen time_sinceapproval = intdate - result_asyl_date
tabstat stay_durm, statistics(mean min max) by(year)

gen reform_date = .
replace reform_date = ym(2016,9) if inlist(nuts1_first,6)
replace reform_date = ym(2016,9) if inlist(nuts1_first,5)
replace reform_date = ym(2016,9) if inlist(nuts1_first,1)
replace reform_date = ym(2016,9) if inlist(nuts1_first,2)
replace reform_date = ym(2016,9) if inlist(nuts1_first,3)
replace reform_date = ym(2016,11) if inlist(nuts1_first,10)
replace reform_date = ym(2016,11) if inlist(nuts1_first,12)
replace reform_date = ym(2017,2) if inlist(nuts1_first,14)
replace reform_date = ym(2017,10) if inlist(nuts1_first,7)
replace reform_date = ym(2018,4) if inlist(nuts1_first,13)
format %tm reform_date
label def restr_mobility 0 "free to move" ///
    1 "residency obligation", replace
tabulate nuts1_first reform_date

capture soepdrop helpvar*
gen restrictive_fs = 1 if nuts1_first >= 1 & reform_date < .
gen restr_mobility = .
label val restr_mobility restr_mobility
label var restr_mobility "face restricted mobility"
replace restr_mobility = 1 if inlist(asyl_req_stat,1,3)
replace restr_mobility = 0 if inlist(asyl_req_stat,4)
replace restr_mobility = 0 if asyl_req_stat == 2 ///
    & time_sinceapproval >= 36 & time_sinceapproval < .
recode restr_mobility . = 1 if asyl_req_stat == 2 ///
    & inlist(nuts1_first,12,10) ///
    & result_asyl_date >= reform_date & result_asyl_date < .
recode restr_mobility . = 0 if asyl_req_stat == 2 ///
    & inlist(nuts1_first,12,10) ///
    & result_asyl_date < reform_date & result_asyl_date < .
replace restrictive_fs = . if inlist(nuts1_first,12,10)
recode restr_mobility . = 1 if asyl_req_stat == 2 ///
    & restrictive_fs == 1 ///
    & result_asyl_date >= (reform_date - 6) & result_asyl_date < .
recode restr_mobility . = 0 if asyl_req_stat == 2 ///
    & restrictive_fs == 1 ///
    & result_asyl_date < (reform_date - 6) & result_asyl_date < .
recode restr_mobility . = 0 if asyl_req_stat == 2 ///
    & inlist(nuts1_first,4,8,9,11,14,15,16)
tabulate restr_mobility, m

rename restr_mobility restr_mobility_itt
label var restr_mobility_itt "subject to restrictive residential policy"
tabulate restr_mobility_itt asyl_req_stat, m
tabulate restr_mobility_itt, m

egen diff_kkz = diff(kkz_curr kkz1st) if kkz_curr < . & kkz1st < .
tabulate diff_kkz, m
lab var diff_kkz "Current county differ from initially assigned"

count
describe, short
save $mydata/msuemer/clean_asylum, replace
display "13D ok"
