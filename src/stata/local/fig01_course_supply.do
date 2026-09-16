*==============================================================================*
* fig01_course_supply.do
*
* Purpose : Paper Figure 1, Panels A and B: county %-change 2015-2016 in
*           started integration courses (A) and in issued course vouchers (B).
*           Also exports the per-county values for the Python choropleth.
* Source  : 00021_descr_analyses_macro.do:60-189
*           Kept line-for-line parallel so the two can be diffed. Additions are
*           marked *** NEW *** and never alter a value the original computes.
* Runs    : local Stata 18; no SOEP microdata, so not a SOEPremote job
* In      : savedata/maps_courses.dta, savedata/maps1_coor.dta   (both from 00011)
* Out     : build/tables/fig01_county_values.csv                 -> Python map
*           results/figures/fig01_panel_{a,b}.{png,pdf}            (needs spmap)
* Deviates: adds corrected recode bins alongside the authors' (see section 2)
* Author  : Emre Suemer  ·  2026-08-12
*==============================================================================*

version 17.0
clear all
set more off

*--- paths: self-contained, does NOT need config.do or a particular cd ----------*
if "$repo" == "" ///
    global repo "/Users/emresuemer/Desktop/Bachelorarbeit-SS26/labour-market-integration"

* $indata is the only path that moves when savedata/ becomes build/stata/.
global indata "$repo/src/analyses/savedata"
global figout "$repo/results/figures"
global tabout "$repo/build/tables"
global logout "$repo/build/logs"

capture mkdir "$repo/build"
capture mkdir "$figout"
capture mkdir "$tabout"
capture mkdir "$logout"

capture log close _all
log using "$logout/fig01_course_supply.log", replace text


********************************************************************************
* 1. Panel A / B variables: identical to 00021_descr_analyses_macro.do:62-126
********************************************************************************

use "$indata/maps_courses.dta", clear

	* started integration courses between 2015-2016

	gen courses_2015 = courses_startet if year==2015
	bysort kkz (year): egen courses_2015_max = max(courses_2015)
	replace courses_2015 = courses_2015_max
	drop courses_2015_max
	label var courses_2015 "Courses started 2015"

	gen courses_2016 = courses_startet if year==2016
	bysort kkz (year): egen courses_2016_max = max(courses_2016)
	replace courses_2016 = courses_2016_max
	drop courses_2016_max
	label var courses_2016 "Courses started 2016"

	* issued vouchers for integration courses between 2015-2016

	gen eligible_2015 = eligible if year==2015
	bysort kkz (year): egen eligible_2015_max = max(eligible_2015)
	replace eligible_2015 = eligible_2015_max
	drop eligible_2015_max
	label var eligible_2015 "New course admissions in 2015"

	gen eligible_2016 = eligible if year==2016
	bysort kkz (year): egen eligible_2016_max = max(eligible_2016)
	replace eligible_2016 = eligible_2016_max
	drop eligible_2016_max
	label var eligible_2016 "New course admissions 2016"

	keep if year == 2016

	gen courses_change = round((courses_2016-courses_2015)/courses_2015*100)
	replace courses_change = 0 if courses_2016 == 0 & courses_2015 == 0
	list kkz_name courses_2015 courses_2016 if courses_change >= .
	* increase from 0 to 1 -> 100% increase
	* increase from 0 to 2 -> 200% increase
	replace courses_change = 100 if courses_2015 == 0 & courses_2016 == 1
	replace courses_change = 200 if courses_2015 == 0 & courses_2016 == 2
	assert courses_change < .

	gen eligible_change = round((eligible_2016-eligible_2015)/eligible_2015*100)
	assert eligible_change < .

	lab def change_aggr 1 "+50% or less" 2 "50%-100%" 3 "100%-150%" ///
		4 "150%-200%" 5 "200%-300%" 6 "300% and more", replace

	recode courses_change (301/max = 6) (201/300 = 5) (151/200 = 4) ///
		(101/150 = 3) (51/100 = 2) (min/50 = 5), gen(courses_change_aggr)
	lab val courses_change_aggr change_aggr
	label var courses_change "%-change courses started 2015-2016"

	recode eligible_change (301/max = 6) (201/300 = 5) (151/200 = 4) ///
		(101/150 = 3) (51/100 = 2) (min/50 = 5), gen(eligible_change_aggr)
	lab val eligible_change_aggr change_aggr
	label var eligible_change_aggr "%-change voucher issued 2015-2016"

	tab eligible_change_aggr if year==2016, m
	count if eligible_change_aggr >= 5 & eligible_change_aggr < . & year==2016
	* the increase in vouchers issued more than doubled in 165 counties
	* check an increase in started courses in those counties
	tab courses_change_aggr if eligible_change_aggr >= 5 & eligible_change_aggr < . & year==2016, m
	count if courses_change_aggr >= 5 & courses_change_aggr < . & eligible_change_aggr >= 5 & eligible_change_aggr & year==2016
	* the increase in supply of language courses in the affected counties more than doubled only in 73 counties


********************************************************************************
*** NEW *** 2. The authors' recode has an off-by-one; keep both, report both
********************************************************************************
* The last rule of both recodes reads (min/50 = 5), but category 5 is labelled
* "200%-300%" and "+50% or less" is category 1. Stata's recode takes the first
* matching rule, so counties with growth <= 50% land in the same bin as counties
* with 200-300% growth. Consequence: the "165 counties" and "73 counties" quoted
* in the comments above -- and in the published text of the paper, p. 11 -- are
* inflated. Figure 1 itself is NOT affected: spmap classifies the continuous
* variables via clbreaks() and never reads the _aggr versions.
* Corrected versions below, under different names, so nothing above changes.

	recode courses_change (301/max = 6) (201/300 = 5) (151/200 = 4) ///
		(101/150 = 3) (51/100 = 2) (min/50 = 1), gen(courses_change_bin)
	lab val courses_change_bin change_aggr
	label var courses_change_bin "%-change courses started 2015-2016 (corrected bins)"

	recode eligible_change (301/max = 6) (201/300 = 5) (151/200 = 4) ///
		(101/150 = 3) (51/100 = 2) (min/50 = 1), gen(eligible_change_bin)
	lab val eligible_change_bin change_aggr
	label var eligible_change_bin "%-change vouchers issued 2015-2016 (corrected bins)"

	di as txt _n "{hline 78}"
	di as txt "CORRECTED bin counts (authors' figures in parentheses)"
	di as txt "{hline 78}"
	tab eligible_change_bin, m
	count if eligible_change_bin >= 5 & eligible_change_bin < .
	di as res "  ^ vouchers more than doubled in `r(N)' counties   (paper text: 165)"
	count if courses_change_bin >= 5 & courses_change_bin < . & ///
	         eligible_change_bin >= 5 & eligible_change_bin < .
	di as res "  ^ ...of which course supply also more than doubled in `r(N)'   (paper text: 73)"
	di as txt "{hline 78}"


********************************************************************************
*** NEW *** 3. Print every county, and export the values for the Python map
********************************************************************************

	format courses_change eligible_change %6.0f
	sort kkz

	di as txt _n "{hline 78}"
	di as txt "FIGURE 1 -- per-county values, all 401 Kreise"
	di as txt "  ARS   = official regional key, joins to the vg2500 shapefile"
	di as txt "  PanelA= courses_change, PanelB = eligible_change (percent)"
	di as txt "{hline 78}"
	list kkz ARS kkz_name courses_change eligible_change, noobs clean

	count
	local n_cty = r(N)
	di as res "Counties written: `n_cty'  (expected 401)"
	assert `n_cty' == 401

	* Checksums -- compare against results/verification/fig01_expected.md, which is
	* computed from the same .dta by an independent Python path. Reported, NOT
	* asserted: on a mismatch you want the CSV written so you can inspect it.
	* NB the reference must use Stata's rounding rule (half away from zero);
	* numpy.round is half-to-even and disagrees on four counties.
	summarize courses_change
	local ck_a = r(sum)
	summarize eligible_change
	local ck_b = r(sum)
	di as res _n "checksum Panel A sum(courses_change)  = `ck_a'   (expected 54803)"
	if `ck_a' != 54803 di as err "  ^ MISMATCH -- do not use these values"
	di as res    "checksum Panel B sum(eligible_change) = `ck_b'   (expected 76035)"
	if `ck_b' != 76035 di as err "  ^ MISMATCH -- do not use these values"
	if `ck_a' == 54803 & `ck_b' == 76035 di as res "both checksums OK"

	preserve
		keep  id kkz ARS GEN kkz_name NUTS_NAME x_c y_c ///
		      courses_2015 courses_2016 courses_change courses_change_aggr courses_change_bin ///
		      eligible_2015 eligible_2016 eligible_change eligible_change_aggr eligible_change_bin
		order id kkz ARS GEN kkz_name NUTS_NAME x_c y_c ///
		      courses_2015 courses_2016 courses_change courses_change_aggr courses_change_bin ///
		      eligible_2015 eligible_2016 eligible_change eligible_change_aggr eligible_change_bin
		* nolabel: write the numeric codes of the *_aggr / *_bin variables rather
		* than their value labels, so the CSV is machine-readable and diffs
		* exactly against the Python reference. The labels are in the codebook at
		* results/verification/fig01_expected.md.
		export delimited using "$tabout/fig01_county_values.csv", replace nolabel
		di as res "wrote $tabout/fig01_county_values.csv"
	restore


********************************************************************************
* 4. The original spmap choropleths: 00021:132-189, unchanged except paths
*    OPT-IN, and OFF by default. spmap renders 61,222 polygon coordinates and on
*    2026-08-12 sat for >13 minutes without producing a file or advancing the log,
*    while everything above it finished in seconds. The Python map is the primary
*    route anyway. To attempt it:   global fig01_drawmaps 1
*    Everything the analysis produces is already written above this point, so
*    interrupting here loses nothing.
********************************************************************************

if "$fig01_drawmaps" != "1" {
	di as txt _n "Section 4 (spmap choropleths) skipped -- opt in with:"
	di as txt    "    global fig01_drawmaps 1"
	di as res _n "fig01_course_supply.do -- done."
	log close
	exit
}

capture which spmap
if _rc {
	di as err "spmap not installed -- ssc install spmap"
	di as res _n "fig01_course_supply.do -- done."
	log close
	exit
}

* From here the file is at top level: no braces wrap the line-continuation
* blocks below, which removes any interaction between /// and an if{} block.

//------------------------------------------------------------------------------
* Panel A
	* percentage changes in the number of started integration courses, 2015-2016
//------------------------------------------------------------------------------
preserve
	format courses_change %6.0f

	* Line continuations replace the original delimiter block, which is not
	* reliable inside an if{} guard. Every spmap option is preserved verbatim.
	spmap courses_change using "$indata/maps1_coor.dta" if year==2016, ///
		name(fig01_panel_a, replace) ///
		id(id) legtitle("%-change") ///
		clmethod(custom) clbreaks(-100 50 100 150 200 300 1600) ///
		title("Panel A: integration courses started", size(medium)) ///
		fcolor(Blues) ///
		legend(order( ///
			7 "300% and more" ///
			6 "200%-300%" ///
			5 "150%-200%" ///
			4 "100%-150%" ///
			3 "50%-100%" ///
			2 "50% to below 0" ///
			1 "No data" ///
			)) ///
		legend(pos(6) row(2) ring(2) size(*1) symx(*.75) symy(*.75) forcesize)

	graph export "$figout/fig01_panel_a.png", as(png) height(1500) replace
	graph export "$figout/fig01_panel_a.pdf", as(pdf) replace
restore

//------------------------------------------------------------------------------
* Panel B:
	* the number of vouchers issued for participation in the integration course, 2015-2016
//------------------------------------------------------------------------------

preserve
	format eligible_change %6.0f

	spmap eligible_change using "$indata/maps1_coor.dta" if year==2016, ///
		name(fig01_panel_b, replace) ///
		id(id) legtitle("%-change") ///
		clmethod(custom) clbreaks(-100 50 100 150 200 300 1600) ///
		title("Panel B: new issued vouchers", size(medium)) ///
		fcolor(Blues) ///
		legend(order( ///
			7 "300% and more" ///
			6 "200%-300%" ///
			5 "150%-200%" ///
			4 "100%-150%" ///
			3 "50%-100%" ///
			2 "50% to below 0" ///
			1 "No data" ///
			)) ///
		legend(pos(6) row(2) ring(2) size(*1) symx(*.75) symy(*.75) forcesize)

	graph export "$figout/fig01_panel_b.png", as(png) height(1500) replace
	graph export "$figout/fig01_panel_b.pdf", as(pdf) replace
restore

di as res _n "fig01_course_supply.do -- done."
log close

********************************************************************************
* Why this is NOT a SOEPremote job
*   Figure 1 contains no SOEP microdata. maps_courses.dta is built by 00011 from
*   public BAMF county course statistics and the vg2500 shapefile, both of which
*   live in this repository. DIW's server has no copy, so running it there would
*   mean re-transmitting 401 counties by inline `input` first, and SOEPremote
*   returns plain text only -- no image could come back. There is nothing to gain
*   in consistency and two round-trip days to lose.
********************************************************************************
