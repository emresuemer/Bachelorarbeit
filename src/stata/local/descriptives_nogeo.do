*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
*
*   descriptives_nogeo.do   (was 00025_descr_nogeo.do)
*   Individual-level descriptives on a sample defined WITHOUT the county requirement
*
*   NOT part of the original Kanas & Kosyakova (2022) replication package.
*   Written for this thesis (2026-07-18) as a substitute for 00022_descr_analyses_micro.do,
*   which cannot run because 00014_data_mi.do is blocked by the county-code redaction
*   in SOEP-Core v36 EU Edition. See docs/lab_notebook.md, "Issue to report to my supervisor".
*
*   ---------------------------------------------------------------------------
*   WHY THIS FILE EXISTS
*   ---------------------------------------------------------------------------
*   In our SOEP edition every geographic identifier below federal-state level is
*   redacted to the constant -7. Two consequences follow:
*
*   (1) 00022 cannot run at all: it loads 04_kos_imputed.dta, which 00014 never
*       produces (the imputation model's regional predictors are 100% missing).
*
*   (2) More subtly, the sample in 03_kos_coded_restricted.dta is CONTAMINATED.
*       In 00013_data_clean.do, kkz1st is missing for everyone (place_kkz > 0 is
*       never true), and the only statement that ever assigns it a value is
*           replace kkz1st = kkz_curr if chg_1staccom == 0        (line ~549)
*       which writes -7. So the restriction
*           keep if kkz1st_miss == 0                              (line ~1810)
*       intended as "keep refugees whose first county is known", in fact selects
*       "keep refugees who never moved from their first accommodation".
*       All 952 surviving rows have kkz1st == -7. That sample is a systematically
*       IMMOBILE subgroup, not the paper's sample, and its descriptives look
*       entirely plausible while being wrong. Do not report them.
*
*   This file therefore rebuilds the sample from 02_kos_coded_full.dta (the
*   pre-restriction file, 18,342 rows) applying every substantive restriction
*   from 00013 EXCEPT the county one, and reports individual-level descriptives.
*
*   ---------------------------------------------------------------------------
*   WHAT IS AND IS NOT COMPARABLE TO THE PAPER
*   ---------------------------------------------------------------------------
*   COMPARABLE IN METHOD: 00022 computes its descriptive tables after `mi extract 0`,
*   i.e. on the ORIGINAL, UNIMPUTED data. This file does complete-case descriptives
*   on the same underlying variables, so the estimator is equivalent - the absence
*   of multiple imputation is NOT a methodological difference for these tables.
*
*   NOT COMPARABLE: the sample differs (~3,030 persons here vs. 504 in the
*   contaminated file), so numbers will not match the published ones. Report these
*   as descriptives of a re-derived sample, not as a reproduction of the paper's
*   Table A1 / S7.
*
*   OMITTED ENTIRELY: every regional variable (z_ratio_courseoport, z_foreign_share,
*   z_density, z_unemplrate, z_consimmi, z_cdu, and all init_*). These are built from
*   the county merge and are 100% missing. They are deliberately excluded rather than
*   reported as empty rows.
*
*   RETAINED AND VALID: nuts1_first (federal state of first residence) is real data
*   (~95% non-missing, all 16 states). restr_mobility_itt - the residency-obligation
*   treatment indicator - is derived from nuts1_first, NOT from county, so it also
*   survives the redaction and is used below as a genuine sample restriction.
*
*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*

if "${config}"!="1" do config

capture log close
log using "$output/descriptives_nogeo_${date}.log", replace text


********************************************************************************
* 1) LOAD PRE-RESTRICTION DATA
********************************************************************************
* 02_kos_coded_full.dta is saved by 00013 BEFORE the sample-selection funnel and
* already carries every restriction flag we need (instrument, age1st, noasylappl,
* asylappl1st, inconsistentdates, restr_mobility_itt, weight_p).

use "$dataout/02_kos_coded_full.dta", clear

xtset pid syear

display _n "=== starting point ==="
xtsum pid


********************************************************************************
* 2) REBUILD THE ONE RESTRICTION VARIABLE NOT STORED IN THE FILE
********************************************************************************
* 00013 computes dur1styr (years between arrival and first interview) inside the
* funnel and drops it before saving, so it must be reconstructed here. Same
* definition as 00013 line ~1791: survey year of the person's first observation
* minus arrival year.

bysort pid (syear): gen syear1st = syear[1]
gen dur1styr = syear1st - arrival_yr
label var dur1styr "years between arrival and first interview"


********************************************************************************
* 3) SAMPLE FUNNEL - all substantive restrictions from 00013 EXCEPT the county one
********************************************************************************
* Each step prints persons (n) and person-years (N) so the attrition table can be
* reported in the thesis. Order follows 00013 for comparability.

tempname funnel
capture postclose `funnel'
postfile `funnel' str40 step long persons long personyears using "$output/descriptives_nogeo_funnel.dta", replace

* --- step 0: starting point
quietly xtsum pid
post `funnel' ("0. start (02_kos_coded_full)") (r(n)) (r(N))

* --- step 1: drop respondents who answered the NON-refugee questionnaire
drop if inlist(instrument,95,103,105,151)
display _n "=== after: drop non-refugee questionnaire ==="
xtsum pid
post `funnel' ("1. refugee questionnaire only") (r(n)) (r(N))

* --- step 2: first interview within the first two years of residence
keep if dur1styr <= 2
display _n "=== after: first interview within 2 years of arrival ==="
xtsum pid
post `funnel' ("2. interview within 2y of arrival") (r(n)) (r(N))

* --- step 3: working age at first interview
keep if age1st >= 18 & age1st <= 64
display _n "=== after: aged 18-64 at first interview ==="
xtsum pid
post `funnel' ("3. aged 18-64") (r(n)) (r(N))

* --- step 4: origin country known
keep if immigroup_nat < .
display _n "=== after: origin country non-missing ==="
xtsum pid
post `funnel' ("4. origin known") (r(n)) (r(N))

* --- step 5: actually applied for asylum
keep if noasylappl != 1
display _n "=== after: has asylum application ==="
xtsum pid
post `funnel' ("5. has asylum application") (r(n)) (r(N))

* --- step 6: first asylum request only
keep if asylappl1st == 1
display _n "=== after: first asylum request only ==="
xtsum pid
post `funnel' ("6. first asylum request only") (r(n)) (r(N))

* --- step 7: internally consistent arrival/application/decision dates
keep if inconsistentdates != 1
display _n "=== after: consistent dates ==="
xtsum pid
post `funnel' ("7. consistent dates") (r(n)) (r(N))

* --- step 8: subject to the residency-obligation policy
*     NOTE: valid despite the redaction - built from nuts1_first (federal state).
keep if restr_mobility_itt == 1
display _n "=== after: subject to residency obligation ==="
xtsum pid
post `funnel' ("8. residency obligation") (r(n)) (r(N))

* --- step 9: usable survey weights
drop if weight_p <= 0 | weight_p >= .
display _n "=== after: valid weights (FINAL SAMPLE) ==="
xtsum pid
post `funnel' ("9. valid weights (FINAL)") (r(n)) (r(N))

* --- DELIBERATELY NOT APPLIED -------------------------------------------------
*     keep if kkz1st_miss == 0
*     This is the contaminated restriction. See header. Applying it would cut the
*     sample to 952 rows / 504 persons consisting only of refugees who never moved.
*     Reported below for documentation, but NOT imposed.
count if kkz1st_miss == 0
display "^^ rows that the ORIGINAL (contaminated) county restriction would have kept"
* ------------------------------------------------------------------------------

postclose `funnel'

* funnel table for the thesis
preserve
	use "$output/descriptives_nogeo_funnel.dta", clear
	list, noobs sep(0) abbrev(40)
	export delimited using "$output/descriptives_nogeo_funnel.csv", replace
restore

xtdescribe


********************************************************************************
* 4) DERIVED OUTCOME VARIABLES (definitions copied verbatim from 00022)
********************************************************************************

* composite "good German" indicator - 00022 lines 65-67
gen good_german = 1 if speak_german >= 3 & read_german >= 3 & write_german >= 3 & german_additive < .
recode good_german .= 0 if german_additive < .
label var good_german "good German in speaking, reading and writing"

* contact frequency indicators - 00022 lines 76-78
gen daily_contact = time_germ == 5 if time_germ < .
gen never_contact = time_germ == 0 if time_germ < .
label var daily_contact "daily contact with Germans"
label var never_contact "never contact with Germans"


********************************************************************************
* 5) OUTCOMES BY SURVEY YEAR (weighted) - mirrors 00022 lines 63-80
********************************************************************************

display _n(2) "{hline 78}"
display "OUTCOMES BY SURVEY YEAR (weighted by weight_p)"
display "{hline 78}"

tab syear [aweight = weight_p], sum(paid_work)
tab syear [aweight = weight_p], sum(german_additive)
tab syear [aweight = weight_p], sum(good_german)
tab syear [aweight = weight_p], sum(int_course_finished)
tab syear [aweight = weight_p], sum(germ_cert_any)
tab syear [aweight = weight_p], sum(time_germ)
tab syear [aweight = weight_p], sum(daily_contact)
tab syear [aweight = weight_p], sum(never_contact)

* scale reliability (Cronbach's alpha) - 00022 lines 65 and 83
display _n "=== reliability: German language scale ==="
alpha speak_german read_german write_german, i

display _n "=== reliability: contact-with-Germans scale ==="
alpha time_germ time_contact_gfr time_contact_gnb time_contact_gjb, i


********************************************************************************
* 6) CORRELATION MATRIX  (analogue of the paper's Table S7)
********************************************************************************

display _n(2) "{hline 78}"
display "CORRELATIONS AMONG OUTCOMES / MEDIATORS"
display "{hline 78}"

pwcorr paid_work german_additive int_course_finished germ_cert_any time_germ, sig star(0.05)
pwcorr paid_work german_additive int_course_finished germ_cert_any time_germ [aweight = weight_p], sig star(0.05)


********************************************************************************
* 7) DESCRIPTIVE STATISTICS TABLE  (analogue of the paper's Table A1)
********************************************************************************
* Regional variables from the paper's Table A1 are OMITTED (see header):
*   z_ratio_courseoport z_foreign_share z_density z_unemplrate z_consimmi z_cdu

* dummy sets, as in 00022 lines 117-120
capture drop asyl_req_stat?
capture drop immigroup?
capture drop immigroup??
capture drop msample?
capture drop syear?
tab asyl_req_stat, gen(asyl_req_stat)
tab immigroup_nat, gen(immigroup)
tab msample, gen(msample)
tab syear, gen(syear)

#delimit
	global vars_nogeo
		paid_work
		german_additive
		good_german
		int_course_finished
		germ_cert_any
		time_germ
		daily_contact
		never_contact
		stay_dur
		total_years_edu0
		work0
		female
		h_child
		partner
		arriv_fam
		family0
		age1st
		trauma_exp
	;
#delimit cr

display _n(2) "{hline 78}"
display "DESCRIPTIVE STATISTICS - individual level (regional vars omitted)"
display "{hline 78}"

* on-screen / in-log version
summarize $vars_nogeo
summarize $vars_nogeo [aweight = weight_p]

* Excel export, same layout as 00022's Table A1 (mean sd n min max)
capture noisily {
	putexcel set "$output/descriptives_nogeo_table_a1.xlsx", sheet(descriptives) replace

	local nvars : word count $vars_nogeo
	matrix temp = J(`nvars',5,.)
	matrix colname temp = mean sd n min max
	matrix rowname temp = $vars_nogeo

	local i = 1
	foreach var of varlist $vars_nogeo {
		quietly summarize `var'
		matrix temp[`i',1] = r(mean)
		matrix temp[`i',2] = r(sd)
		matrix temp[`i',3] = r(N)
		matrix temp[`i',4] = r(min)
		matrix temp[`i',5] = r(max)
		local i = `i' + 1
	}

	putexcel A1 = "Table A1 (no-geography version) - re-derived sample, county restriction not applied"
	putexcel A2 = matrix(temp), names nformat(number_d2)
	putexcel close
}


********************************************************************************
* 8) FEDERAL-STATE COMPOSITION  (the geography that DID survive)
********************************************************************************
* Included because it is the basis of any state-level fallback design, and because
* it documents that state-level geography is intact while county-level is not.

display _n(2) "{hline 78}"
display "FEDERAL STATE OF FIRST RESIDENCE (nuts1_first) - available, unlike county"
display "{hline 78}"

tab nuts1_first, m
tab nuts1_first [aweight = weight_p]

* cross-check: county is entirely redacted in this same sample
display _n "=== county (kkz1st) in the same sample - all -7, for contrast ==="
tab kkz1st, m


********************************************************************************
* 9) SUMMARY
********************************************************************************

display _n(2) "{hline 78}"
display "SUMMARY"
display "{hline 78}"
display "Sample: rebuilt from 02_kos_coded_full.dta WITHOUT the county restriction."
display "Expected final size: ~6,045 person-years / ~3,030 persons"
display "  (vs. 952 / 504 in 03_kos_coded_restricted.dta, which is contaminated)."
display ""
display "Outputs written to \$output:"
display "  descriptives_nogeo_\${date}.log   full log"
display "  descriptives_nogeo_funnel.dta / .csv          sample attrition table"
display "  descriptives_nogeo_table_a1.xlsx        descriptive statistics"
display ""
display "NOT reported here (100% missing due to county redaction):"
display "  z_ratio_courseoport z_foreign_share z_density z_unemplrate z_consimmi z_cdu"
display "  and all init_* regional variables."
display "{hline 78}"

log close
