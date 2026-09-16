* ==========================================================================
* CONFIRM cty_supply.dta EXISTS ON THE DIW SERVER -- DOCUMENTATION,
* DO NOT SEND THIS HEADER
* ==========================================================================
* Send this LAST, as an independent proof. Job 13 reports its own save, but
* this job opens the file in a FRESH session, which is the only thing that
* actually demonstrates it persisted in $mydata between jobs and is readable
* by everything that comes after.
*
* Expected: 2807 observations, 14 variables, 401 per year for 2013-2019.
*
* Preflight before sending:
*   python3 remote/tools/preflight.py remote/jobs/*.do
* ==========================================================================

* SEND FROM HERE DOWN
use $mydata/msuemer/cty_supply, clear
count
isid kkz year
describe
tabulate year
summarize
display "cty_supply is present and readable"
