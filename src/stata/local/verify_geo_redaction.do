*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
* Diagnostic: verify which geographic identifiers are available in the
* SOEP-Core v36 EU Edition regional files.
*
* Not part of the original replication package - written for this thesis to
* document the data-access limitation blocking the county-level replication.
* Produces a log that can be attached to correspondence.
*
* Expected result: every sub-state identifier is constant at -7
* ("Nur in weniger eingeschraenkter Edition"), i.e. mean = -7, sd = 0,
* 1 unique value. Only bula / nuts1 (federal state) carry real values.
*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*

if "${config}"!="1" do config

capture log close
log using "$output/verify_geo_redaction_${date}.log", replace text


********************************************************************************
* 1) regionl.dta - current place of residence, household-year level
********************************************************************************

use "$datageoIAB/regionl.dta", clear

count
display "^^ total household-year observations in regionl.dta"

* unique values / mean / sd / min / max for each geo identifier
codebook bula nuts1 nuts2 nuts3 regbez kkz kkz_rek kkz_rek90 gkz plz ///
	ror96 bik ggk gtyp, compact

summarize bula nuts1 nuts2 nuts3 regbez kkz kkz_rek kkz_rek90 gkz plz ///
	ror96 bik ggk gtyp

* built-in county-level indicators (also redacted)
codebook kr_uemprate kr_emprate kr_foreigner kr_popdens kr_area ///
	kr_population kr_hhinc kr_gdp_pem kr_gdp_pc kr_utmost kr_utmnord, compact

* the two identifiers that DO survive, for contrast
tab bula, m
tab nuts1, m

* county availability by survey year - shows the redaction is not year-specific
gen byte kkz_ok = (kkz > 0) if kkz < .
tabulate syear kkz_ok, m row


********************************************************************************
* 2) bioregion.dta - first / longest place of residence, person-year level
********************************************************************************

use "$datageoIAB/bioregion.dta", clear

count
display "^^ total person-year observations in bioregion.dta"

* first-residence geography + coordinates
codebook place_bula place_kkz place_gkz laenge breite, compact
summarize place_bula place_kkz place_gkz laenge breite

* residence history: state level survives, county/municipality level does not
codebook bula_1 bula_2 bula_3 kkz_1 kkz_2 kkz_3 gkz_1 gkz_2 gkz_3, compact

tab place_bula, m


********************************************************************************
* 3) Summary
********************************************************************************

display _n(2) "{hline 78}"
display "SUMMARY"
display "{hline 78}"
display "Redacted (constant -7, sd = 0, 1 unique value):"
display "  regionl.dta   : kkz kkz_rek kkz_rek90 gkz regbez nuts2 nuts3 plz"
display "                  ror96 bik ggk gtyp  + all kr_* indicators"
display "  bioregion.dta : place_kkz place_gkz  kkz_1-kkz_19  gkz_1-gkz_19"
display "                  laenge breite"
display ""
display "Available (real values):"
display "  regionl.dta   : bula  nuts1                    (federal state)"
display "  bioregion.dta : place_bula  bula_1-bula_19     (federal state + history)"
display "{hline 78}"

log close
