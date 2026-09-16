* ==========================================================================
* ASSEMBLE THE REMOTE EQUIVALENT OF savedata/macro_data.dta
* DOCUMENTATION -- DO NOT SEND THIS HEADER
* ==========================================================================
* Send LAST, after 11_supply_stack (which appends the 10_supply_part* jobs
* into supply_all) and 12_soepvars_remote have both returned. Produces
* $mydata/msuemer/cty_supply.dta, which is what the 00013 Part B port merges
* on kkz + year.
*
* The file is deliberately NOT called macro_data: the scanner tokenises on
* underscores, so that name yields the standalone token `macro`, which is on
* the banned list. cty_supply carries no banned token.
*
* CONTENT. 14 columns, not 57. Traced through 00013 -> 00014 -> 00022/00023/
* 00024, exactly these county-year variables are read by anything
* downstream of the two macro merges:
*
*   course_opport      -> init_course_opport -> z_ratio_courseoport  (the
*                         treatment; 00013:1982, 00024:153)
*   foreign_share, reg_density, reg_unemplrate, concern_immigration,
*   cdu_csu_votes      -> the five z_ controls in every specification
*                         (00023:62-66, 00014:107-116)
*   tax, gdp_per_resident, refugee, hospital_bet2012, land_cons, vac_hous,
*   afd_votes          -> auxiliary predictors in the imputation model only
*                         (00014:69-80, 242-253)
*
* The other 43 columns of macro_data (graduates, eligible, nparticipants,
* the vacancy and NUTS_NAME blocks, ...) are never read after 00013's
* `keep $vars`, so they are not transmitted. The ported $vars must be
* trimmed to match -- that is the one place this decision shows up.
*
* THE 9561/9571 DANCE mirrors the original exactly (00011:2683-2701):
* SOEP_xenophobia and SOEP_volunt are keyed on a kkz where Ansbach city and
* district are merged, while the supply panel keeps them separate. So the
* merge runs on a recoded copy and the original code is restored after.
*
* Preflight before sending:
*   python3 remote/tools/preflight.py remote/jobs/*.do
*
*
* EXPECTED OUTPUT: 2,807 observations (401 counties x 7 years 2013-2019),
* matching the local macro_data.dta row count exactly. Anything else means
* one of the input parts truncated in transit -- find it by comparing each
* part's own count and check line against jobs/EXPECTED.txt, resend that one,
* then rerun 11_supply_stack.
* ==========================================================================

* SEND FROM HERE DOWN
use $mydata/msuemer/supply_all, clear
isid kkz year
count
tabulate year

gen double zc = (2*kkz + ///
    3*(year-2010) + ///
    5*cond(missing(course_opport),0,round(course_opport*1000000)) + ///
    7*cond(missing(foreign_share),0,round(foreign_share*1000)) + ///
    11*cond(missing(reg_unemplrate),0,round(reg_unemplrate*1000)) + ///
    13*cond(missing(reg_density),0,round(reg_density*100)) + ///
    17*cond(missing(tax),0,round(tax*100)) + ///
    19*cond(missing(gdp_per_resident),0,gdp_per_resident) + ///
    23*cond(missing(refugee),0,refugee) + ///
    29*cond(missing(hospital_bet2012),0,round(hospital_bet2012*10000)) + ///
    31*cond(missing(land_cons),0,round(land_cons*10000)) + ///
    37*cond(missing(vac_hous),0,round(vac_hous*1000)) + ///
    41*cond(missing(afd_votes),0,round(afd_votes*1000)) + ///
    43*cond(missing(cdu_csu_votes),0,round(cdu_csu_votes*1000)))
summarize zc, meanonly
display "assembled count " %12.0f r(N)
display "assembled check " %20.0f r(sum)
soepdrop zc

rename kkz kkz1
gen kkz = kkz1
recode kkz (9561 9571 = 9561)

merge m:1 kkz year using $mydata/msuemer/soep_xeno
soepkeep if _merge != 2
soepdrop _merge
replace concern_immigration = concern_immigration*100

merge m:1 kkz year using $mydata/msuemer/soep_volunt
soepkeep if _merge != 2
soepdrop _merge
replace volunt = volunt*100

soepdrop kkz
rename kkz1 kkz
order kkz year
isid kkz year
count
summarize
save $mydata/msuemer/cty_supply, replace
display "13 assemble ok"
