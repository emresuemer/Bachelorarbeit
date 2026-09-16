*==============================================================================*
* clean_geography.do
*
* Purpose : The contacts block, then the geography construction: kkz1st, nuts1_first,
*           regierungsbezirk, init_ost. kkz1st is the county of first allocation.
* Source  : 00013_data_clean.do:404-671
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : clean_outcomes -> clean_outcomes
* Saves   : $mydata/msuemer/clean_geography  (18,342 x 252, verified 2026-08-13)
* Deviates: see the FORCED DEVIATIONS notes below
* Author  : Emre Suemer
*==============================================================================*
* ==========================================================================
* PORT OF 00013_data_clean.do, PART A2 (orig lines 404-671)
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
* Second half of the split described in 00013A1_data_clean_remote.do.
* Reads clean_outcomes (written by A1) and carries on from the contacts
* block through the geography construction.
*
* DO NOT SEND THIS UNTIL A1'S LISTING SHOWS:
*     file /srv/cifs/lissy-users-data/msuemer/clean_outcomes.dta saved
* Without that file this job's first line fails and every command after it
* errors -- and because runtime errors do not halt a SOEPremote job, it
* would return a long, useless listing rather than an obvious failure.
*
* `xtset pid syear` is re-declared at the top. Stata does store the xtset
* declaration in the saved .dta, so this is belt-and-braces -- but xtsum
* appears twice below and the local pipeline already needed xtset refreshes
* after large data changes (see docs/lab_notebook.md), so it is cheap insurance.
*
* Variables this job inherits from A1 and does not recreate: minusyear, n,
* N, panel_quex_instr, intdate, intyear. All are saved in clean_outcomes.
*
* WHAT TO CHECK IN THE OUTPUT (the payoff of the whole port):
*   count                              -> 18,342 (no rows dropped)
*   count if kkz1st > 0 & kkz1st < .   -> 16,186 expected
*   count if ktag1 == 1                -> 354 distinct counties expected
*   xtsum kkz1st                       -> n = 7,191 persons, min 1001
* Those figures already returned twice from the unsplit job, so a mismatch
* means something went wrong in the split, not in the data.
*
* Pre-flight banned-token scan: clean.
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/clean_outcomes, clear
xtset pid syear
recode plj0569 plm0512 plm0513 plm0567 (-10/-1 = .)
clonevar time_germ=plj0569
clonevar time_contact_gfr=plm0567
clonevar time_contact_gnb=plm0512
clonevar time_contact_gjb=plm0513

gen weekly_germ = time_germ <= 3 if time_germ < .
lab var weekly_germ "weekly contacts with germans or more often"

gen monthly_time_germ = time_germ <= 4 if time_germ <.
lab var monthly_time_germ "monthly contacts with germans or more often"

alpha time_germ time_contact_gfr time_contact_gnb time_contact_gjb, i s
label def time_ 0 "never" 5 "daily", replace

recode time_germ 1=5 2=4 3=3 4=2 5=1 6=0, gen(time_germ_reserv)
lab val time_germ_reserv time_
recode time_contact_gfr 1=5 2=4 3=3 4=2 5=1 6=0, gen(time_contact_gfr_reserv)
lab val time_contact_gfr_reserv time_
recode time_contact_gnb 1=5 2=4 3=3 4=2 5=1 6=0, gen(time_contact_gnb_reserv)
lab val time_contact_gnb_reserv time_
recode time_contact_gjb 1=5 2=4 3=3 4=2 5=1 6=0, gen(time_contact_gjb_reserv)
lab val time_contact_gjb_reserv time_

tab1 time_germ_reserv time_contact_gfr_reserv time_contact_gnb_reserv time_contact_gjb_reserv, mis
egen contacts_germ = rowmean(time_germ_reserv time_contact_gfr_reserv time_contact_gnb_reserv time_contact_gjb_reserv)
egen contacts_germ_miss = rowmiss(time_germ_reserv time_contact_gfr_reserv time_contact_gnb_reserv time_contact_gjb_reserv)
tabulate contacts_germ, m
replace contacts_germ = . if contacts_germ_miss != 0
tabulate contacts_germ, m
summarize contacts_germ, detail
replace contacts_germ = (contacts_germ-r(mean))/ r(sd)
summarize contacts_germ, detail
tabulate contacts_germ, mis
label variable contacts_germ "contacts with germans, non-applicable (-) - applicable (+)"

recode time_germ  1=5 2=4 3=3 4=2 5=1 6=0
lab val time_germ time_

g arrival_yr=imyear if imyear>0
g arrival_mth=immon if immon>0
lab var arrival_yr "arrival year"
lab var arrival_mth "arrival month"
g arrival_date=ym(arrival_yr,arrival_mth)
lab var arrival_date "date of arrival"
format arrival_date %tm
bys pid (syear): carryforward arrival_*, replace
bys pid (minusyear): carryforward arrival_*, replace

count if place_kkz > 0 & place_kkz < .
tabulate syear if place_kkz > 0 & place_kkz < ., m
gen test = 1 if place_kkz <. & place_kkz >0
tabulate lr3235 syear, m
replace test = 1 if lr3235 == 1
bys pid: egen maxtest = max(test)
tabulate maxtest syear,m
bys syear: tab maxtest panel_quex_instr,m col
soepdrop maxtest test

gen gkz_curr = gkz
label var gkz_curr "current municipality"

gen kkz_curr = kkz
label var kkz_curr "current county"

gen gkz1st = place_gkz if place_gkz > 0
label var gkz1st "1st/longest municipality"

gen kkz1st = place_kkz if place_kkz > 0
label var kkz1st "1st/longest county"

replace kkz_curr = 11000 if ( inlist(kkz_curr, 11100, 11200) )
replace kkz1st = 11000 if ( inlist(kkz1st, 11100, 11200) )
replace gkz_curr = 11000000 if ( inlist(gkz_curr, 11100000, 11200000) )
replace gkz1st = 11000000 if ( inlist(gkz1st, 11100000, 11200000) )

recode kkz_curr kkz1st (3156 = 3159)
recode kkz_curr kkz1st (5313 5354 = 5334)
recode kkz_curr kkz1st (13005 13057 13061 = 13073)

tabulate lr3235 syear, m
gen chg_1staccom = 1 if inlist(lr3235,2,3,4,5,6)
replace chg_1staccom = 0 if inlist(lr3235,1)
label var chg_1staccom "changed from 1st accommodation in Germany"
tabulate lr3485 lr3486  if syear == 2019,m

replace chg_1staccom = 1 if inlist(lr3485,1) & panel_quex_instr == 0
replace chg_1staccom = 0 if inlist(lr3485,2,3) & panel_quex_instr == 0
tabulate chg_1staccom if syear == 2019, m
replace chg_1staccom = 1 if inlist(lr3486,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3487,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3488,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3489,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3490,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3491,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3492,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3493,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3494,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3495,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3496,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3497,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3498,1) & panel_quex_instr == 0
replace chg_1staccom = 1 if inlist(lr3499,1) & panel_quex_instr == 0

tabulate n chg_1staccom , m
tabulate chg_1staccom syear, m

tabulate kkz1st syear if chg_1staccom == 0, m

replace kkz1st = kkz_curr if chg_1staccom == 0
replace gkz1st = gkz_curr if chg_1staccom == 0

bys pid (syear): carryforward kkz1st gkz1st, replace
bys pid (minusyear): carryforward kkz1st gkz1st, replace
sort pid syear

xtsum kkz1st gkz1st
count
summarize kkz1st gkz1st

count if kkz1st > 0 & kkz1st < .
egen ktag1 = tag(kkz1st) if kkz1st > 0 & kkz1st < .
count if ktag1 == 1
soepdrop ktag1

soepdrop place_kkz kkz gkz gkzname place_gkz

ren place_bula place_bula_prev
gen place_bula = 1 if kkz1st >=1000 & kkz1st < 2000
replace place_bula = 2 if kkz1st >=2000 & kkz1st < 3000
replace place_bula = 3 if kkz1st >=3000 & kkz1st < 4000
replace place_bula = 4 if kkz1st >=4000 & kkz1st < 5000
replace place_bula = 5 if kkz1st >=5000 & kkz1st < 6000
replace place_bula = 6 if kkz1st >=6000 & kkz1st < 7000
replace place_bula = 7 if kkz1st >=7000 & kkz1st < 8000
replace place_bula = 8 if kkz1st >=8000 & kkz1st < 9000
replace place_bula = 9 if kkz1st >=9000 & kkz1st < 10000
replace place_bula = 10 if kkz1st >=10000 & kkz1st < 11000
replace place_bula = 11 if kkz1st >=11000 & kkz1st < 12000
replace place_bula = 12 if kkz1st >=12000 & kkz1st < 13000
replace place_bula = 13 if kkz1st >=13000 & kkz1st < 14000
replace place_bula = 14 if kkz1st >=14000 & kkz1st < 15000
replace place_bula = 15 if kkz1st >=15000 & kkz1st < 16000
replace place_bula = 16 if kkz1st >=16000 & kkz1st < 17000

lab def bula ///
	01 "Schleswig-Holstein" ///
	02 "Hamburg" ///
	03 "Lower Saxony" ///
	04 "Bremen" ///
	05 "North Rhine-Westphalia" ///
	06 "Hesse" ///
	07 "Rhineland-Palatinate" ///
	08 "Baden-Wuerttemberg" ///
	09 "Bavaria" ///
	10 "Saarland" ///
	11 "Berlin" ///
	12 "Brandenburg" ///
	13 "Mecklenburg-Western Pomerania" ///
	14 "Saxony" ///
	15 "Saxony-Anhalt" ///
	16 "Thuringia" ///
	, replace
numlabel bula, add
lab val place_bula bula
lab var bula "federal state:y,bula"

gen nuts1_curr = nuts1
label var nuts1_curr "current federal state"
lab val nuts1_curr nuts1

gen nuts1_first = .
lab val nuts1_first nuts1
label var nuts1_first "1st federal state"
replace nuts1_first = 1 if place_bula == 8
replace nuts1_first = 2 if place_bula == 9
replace nuts1_first = 3 if place_bula == 11
replace nuts1_first = 4 if place_bula == 12
replace nuts1_first = 5 if place_bula == 4
replace nuts1_first = 6 if place_bula == 2
replace nuts1_first = 7 if place_bula == 6
replace nuts1_first = 8 if place_bula == 13
replace nuts1_first = 9 if place_bula == 3
replace nuts1_first = 10 if place_bula == 5
replace nuts1_first = 11 if place_bula == 7
replace nuts1_first = 12 if place_bula == 10
replace nuts1_first = 13 if place_bula == 14
replace nuts1_first = 14 if place_bula == 15
replace nuts1_first = 15 if place_bula == 1
replace nuts1_first = 16 if place_bula == 16

replace nuts1_first = lr2074 if nuts1_first >= . & lr2074 >0
tabulate nuts1_first syear

replace nuts1_first = nuts1_curr if chg_1staccom == 0

bys pid (syear): carryforward nuts1_first, replace
bys pid (minusyear): carryforward nuts1_first, replace
sort pid syear

tabulate lr3367 syear if nuts1_first == ., m
replace nuts1_first = lr3367 if nuts1_first >= . & lr3367 >0
bys pid (syear): carryforward nuts1_first, replace
bys pid (minusyear): carryforward nuts1_first, replace
sort pid syear

xtsum nuts1_first kkz1st gkz1st
count
summarize kkz1st gkz1st nuts1_first

soepdrop l_nuts1info l_nuts1 l_nuts1_ew nuts1

count if kkz1st < .
tostring kkz1st, gen(kkz1st_str)
generate str regierungsbezirk = substr(kkz1st_str, 1, strlen(kkz1st_str) - 2)
destring regierungsbezirk, replace
tabulate regierungsbezirk ,m
lab var regierungsbezirk "regional mid-level local government"

recode nuts1_first (4 8 13 14 16 = 1) (nonmiss = 0) , gen(init_ost)
lab var init_ost "eastern germany (1.county /arriv.yr.)"

count
describe, short
save $mydata/msuemer/clean_geography, replace
