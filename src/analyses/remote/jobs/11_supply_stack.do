* ======================================================================
* STACK THE TRANSMITTED SUPPLY PARTS -- GENERATED, DO NOT EDIT BY HAND
* Regenerate with: python3 remote/tools/make_supply_jobs.py
* DOCUMENTATION -- DO NOT SEND THIS HEADER
* ======================================================================
* Send after all 18 parts have returned, and only once every one of them
* has shown its own count and check line matching jobs/EXPECTED.txt.
* A part that truncated in transit still reports `end of do-file`, so the
* absence of a complaint here proves nothing on its own.
*
* Produces $mydata/msuemer/supply_all.dta, the input to
* 13_supply_assemble.do. Must report exactly 2807 observations.
* ======================================================================

* SEND FROM HERE DOWN
use $mydata/msuemer/supply_p1, clear
append using $mydata/msuemer/supply_p2
append using $mydata/msuemer/supply_p3
append using $mydata/msuemer/supply_p4
append using $mydata/msuemer/supply_p5
append using $mydata/msuemer/supply_p6
append using $mydata/msuemer/supply_p7
append using $mydata/msuemer/supply_p8
append using $mydata/msuemer/supply_p9
append using $mydata/msuemer/supply_p10
append using $mydata/msuemer/supply_p11
append using $mydata/msuemer/supply_p12
append using $mydata/msuemer/supply_p13
append using $mydata/msuemer/supply_p14
append using $mydata/msuemer/supply_p15
append using $mydata/msuemer/supply_p16
append using $mydata/msuemer/supply_p17
append using $mydata/msuemer/supply_p18
isid kkz year
count
tabulate year
save $mydata/msuemer/supply_all, replace
display "stack ok"
