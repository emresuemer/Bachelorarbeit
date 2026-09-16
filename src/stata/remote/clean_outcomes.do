*==============================================================================*
* clean_outcomes.do
*
* Purpose : Panel setup, survey weights, the instrument, the outcome, and the German-
*           proficiency and integration-course mechanisms.
* Source  : 00013_data_clean.do:65-403
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : merge_soep -> soep_merged
* Saves   : $mydata/msuemer/clean_outcomes  (18,342 x 235, verified 2026-08-13)
* Deviates: see the FORCED DEVIATIONS notes below
* Author  : Emre Suemer
*==============================================================================*
* ==========================================================================
* PORT OF 00013_data_clean.do, PART A1 (orig lines 65-403)
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
* Part A had to be split. It is correct code -- it ran cleanly through ~90%
* of its length on 2026-08-03 and reproduced identical numbers twice -- but
* the emailed job body kept arriving TRUNCATED, at a different point each
* time (~line 340 twice, then ~line 190). Because SOEPremote executes
* whatever text arrives and then prints "end of do-file", a truncated job
* looks like a successful short job: it never reaches the final `save`, so
* nothing is written and the loss is silent.
*
* Splitting removes the variable. Each half is ~190 lines, and each ends
* with a save whose confirmation line is the proof the job completed.
*
* A1 (this file): orig 65-403. Panel setup, weights, instrument, sample,
*                 employment outcomes, wages, ISEI, language proficiency,
*                 courses, certificates. Saves clean_outcomes.
* A2:             orig 404-671. Contacts, arrival date, kkz1st/geography,
*                 place_bula, nuts1_first, regierungsbezirk, init_ost.
*                 Reads clean_outcomes, saves clean_geography.
*
* All deviations are as documented in 00013A_data_clean_remote.do (which
* this pair supersedes for sending; keep it as the single-file reference).
*
* MUST-SEE LINE IN THE RETURNED LISTING:
*     file /srv/cifs/lissy-users-data/msuemer/clean_outcomes.dta saved
* If that line is absent the job was truncated -- resend, do not proceed
* to A2.
*
* Compose a FRESH plain-text email. Paste the header once, then the block
* below once. No quoted text, no signature, no second copy.
*
* Pre-flight banned-token scan: clean.
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/soep_merged, clear

unique pid
summarize pid

gen minusyear = -syear
xtset pid syear
tabulate syear, m
bys pid (syear): gen n = _n
bys pid (syear): gen N = _N
xtdescribe, pattern(20)
tabulate N

gen intyear = piyear
lab var intyear "interview year"
gen intdate = ym(piyear, pmonin)
lab var intdate "interview date"
format %tm intdate

gen weight_p = .
replace weight_p = phrf
lab var weight_p "person weights"
tabulate syear, sum(weight_p)

tabulate instrument, m
label define instrument ///
	6 "[6] person und biografie [m3-m4;capi] (2016)" ///
	56 "[56] personenbiographie  (m3-m5 erstbefragte; capi; 2017)" ///
	57 "[57] personenbiographie  (m3-m4 wiederbefragte; capi; 2017)" ///
	95 "[95] personenbiographie  (m3-m4 erstbefragte; nicht gefluechtete; capi; 2017)" ///
	103 "[103] person [m3-m5 wiederbefragte nicht gefluechtete;capi] (2018)" ///
	105 "[105] person und biografie [m3-m5 erstbefragte nicht gefluechtete;capi] (2018)" ///
	106 "[106] person und biografie [m3-m5 wiederbefragte;capi] (2018)" ///
	107 "[107] person und biografie [m3-m5 erstbefragte;capi] (2018)" ///
	151 "[151] person [a-l1 n o p;capi] (2019)" ///
	154 "[154] person und biografie [m3-m5 wiederbefragte;capi] (2019)" ///
	155 "[155] person und biografie [m3-m5 erstbefragte;capi] (2019)" ///
	, replace
lab val instrument instrument

gen panel_quex_instr = 1 if inlist(instrument,57,106,154)
replace panel_quex_instr = 0 if syear == 2016
replace panel_quex_instr = 0 if inlist(instrument,56,107,155)
tabulate instrument

gen msample = psample
recode msample (17 = 3) (18 = 4) (19 = 5)
label variable msample "sample"

gen anker_person = 1 if p_anker == 1
bys pid (syear): carryforward anker_person, replace
bys pid (minusyear): carryforward anker_person, replace

gen paid_work = .
replace paid_work = 1 if inlist(plb0022_h,1,2,3,4,10)
replace paid_work = 0 if inlist(plb0022_h,5,7,9)
replace paid_work = 0 if pglabgro == 0
label var paid_work "employed in paid work"
tabulate paid_work syear, m

capture soepdrop fptime_work
gen fptime_work = plb0022_h <= 2 if plb0022_h <. & plb0022_h >0
label var fptime_work "full-/parttime employment"
tabulate fptime_work syear, m

gen lfs_status_3cat = .
lab def lfs_status_3cat ///
	1 "employed in paid work" ///
	2 "seeking work (last 4 weeks)" ///
	3 "not seeking work" ///
	, replace
lab val lfs_status_3cat lfs_status_3cat
recode lfs_status_3cat . = 1 if paid_work == 1
recode lfs_status_3cat . = 2 if plb0424_v2 == 1
recode lfs_status_3cat . = 3 if plb0424_v2 == 2
recode lfs_status_3cat . = 3 if paid_work == 0
tabulate lfs_status_3cat syear, m
label var lfs_status_3cat "LFS, 3 cat."
tabulate lfs_status_3cat, m

gen activity = lfs_status_3cat <= 2 if lfs_status_3cat <.
label var activity "labout force participation (employed and unemployed)"
tabulate activity syear, m

ren pglabgro labgro
ren pglabnet labnet
recode labgro labnet (-10/-1 =.)
label variable labnet "cct. (netto) monthly wages in euro"
label variable labgro "act. (brutto) monthly wages in euro"
tabulate syear , sum(labgro)
tabulate syear , sum(labnet)

gen ln_earnings = ln(labgro)
label variable ln_earnings "ln of act. (brutto) monthly wages in euro"

ren pgisco08 isco08
recode isco08  (-2 -1 = .)
iscogen isei = isei(isco08)
label var isei "job current: isei scale (international socio-economic index)"
tabulate syear , sum(isei)
tabulate isco08 if isei>=.,m

label def language 4 "very good" 0 "not at all"

g speak_german = plj0071
lab var speak_german "german language: speaking"
tabulate speak_german

g write_german = plj0072
lab var write_german "german language: writing"
tabulate write_german

g read_german = plj0073
lab var read_german "german language: reading"
tabulate read_german

g german_interview = lb1305
lab var german_interview "german language: interview"
tabulate german_interview

recode speak_german (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)
lab val speak_german language
recode write_german (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)
lab val write_german language
recode read_german (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)
lab val read_german language
recode german_interview (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)
lab val german_interview language

alpha speak_german read_german write_german german_interview
pca speak_german read_german write_german german_interview

gen german_additive = speak_german + read_german + write_german
lab var german_additive "german langauge profficiency"

gen int_course_part = 1 if plj0654 == 1
label var int_course_part "participated in an integration course"
bys pid (syear): carryforward int_course_part, replace
recode int_course_part (. = 0) if plj0654 == 2
recode int_course_part (. = 0) if plm0518i05 == 1 & syear == 2019
recode int_course_part (. = 0) if inlist(plm0518i05,-2) & syear == 2019
tabulate int_course_part syear, m

gen int_course_finished = 1 if plj0657 >0 & plj0657 < . & plj0659_h != 1
label var int_course_finished "finished an integration course"
bys pid (syear): carryforward int_course_finished, replace
recode  int_course_finished . = 0 if int_course_part == 0
recode  int_course_finished . = 0 if plj0659_h == 1
tabulate int_course_finished syear, m

gen int_course_curr = 1 if plj0659_h == 1
label var int_course_curr "cuurently in an integration course"
recode  int_course_curr . = 0 if int_course_part == 0
recode  int_course_curr . = 0 if int_course_part == 1
tabulate int_course_curr syear, m

lab def lang_cert ///
	0 "no course attended" 1 "course without certificate" ///
	2 "course with A1/A2" 3 "course with  B1/B2" ///
	4 "course with C1/C2" ///
	, replace

gen lang_cert = .
lab var lang_cert "language certificate"
lab val lang_cert lang_cert

recode lang_cert . = 4 if inlist(plj0506,5,6) | inlist(plj0515,5,6) | inlist(plj0524,5,6) ///
	| inlist(plj0542,5,6) | inlist(plm0529,5,6) | inlist(plj0533,5,6)
bys pid (syear): carryforward lang_cert, replace
recode lang_cert . = 3 if inlist(plj0506,3,4) | inlist(plj0515,3,4) | inlist(plj0524,3,4) ///
	| inlist(plj0542,3,4) | inlist(plm0529,3,4) | inlist(plj0533,3,4) | inlist(plj0661,3)
bys pid (syear): carryforward lang_cert, replace
recode lang_cert . = 2 if inlist(plj0506,1,2) | inlist(plj0515,1,2) | inlist(plj0524,1,2) ///
	| inlist(plj0542,1,2) | inlist(plm0529,1,2) | inlist(plj0533,1,2) | inlist(plj0661,1,2)
recode lang_cert . = 1 if inlist(plj0506,7,8) | inlist(plj0515,7,8) | inlist(plj0524,7,8) ///
	| inlist(plj0542,7,8) | inlist(plm0529,7,8) | inlist(plj0533,7,8) | inlist(plj0661,4,5)
bys pid (syear): carryforward lang_cert, replace
recode lang_cert . = 1 if plj0504 == 1 | plj0504 == 1 | plj0540 == 1 | ///
	plj0513 == 1 | plj0522 == 1 | plj0531 == 1 | plm0524i03 == 1 | ///
	plm0589i03 == 1

gen esf_bamf_part = 1 if plj0499 == 1
label var esf_bamf_part "ESF-BAMF-course: participation"
bys pid (syear): carryforward esf_bamf_part, replace
recode esf_bamf_part (. = 0) if plj0499 == 2
recode esf_bamf_part (. = 0) if plm0518i05 == 1
recode esf_bamf_part (. = 0) if inlist(plm0518i05,-2)
tabulate esf_bamf_part syear, m

gen deu_sonst_part = 1 if plj0535 == 1
label var deu_sonst_part "other germa cozrse: participation"
bys pid (syear): carryforward deu_sonst_part, replace
recode deu_sonst_part (. = 0) if plj0535 == 2
recode deu_sonst_part (. = 0) if plm0518i05 == 1
recode deu_sonst_part (. = 0) if inlist(plm0518i05,-2)
tabulate deu_sonst_part syear, m

gen de_ba_part = 1 if plj0517 == 1 | plj0526 == 1 | plm0518i01 == 1 | plm0518i02 == 1 | ///
	plm0518i03 == 1 | plm0518i04 == 1 | plj0508 == 1 | plm0528 == 1 | plm0518i06 == 1
label var de_ba_part "BA- course/Progr: participation"
bys pid (syear): carryforward de_ba_part, replace
recode de_ba_part (. = 0) if plj0517 == 2 | plj0526 == 2 | plm0518i01 == 2 | plm0518i02 == 2 | ///
	plm0518i03 == 2 | plm0518i04 == 2 | plj0508 == 2 | plm0528 == 2 | plm0518i06 == 2
recode de_ba_part (. = 0) if plm0518i05 == 1
recode de_ba_part (. = 0) if inlist(plm0518i05,-2)
tabulate de_ba_part syear, m

recode lang_cert . = 1 if int_course_part == 1 | esf_bamf_part == 1 | deu_sonst_part == 1 | de_ba_part == 1
recode lang_cert . = 0 if int_course_part == 0 & esf_bamf_part == 0 & deu_sonst_part == 0 & de_ba_part == 0
tabulate lang_cert syear, m

capture soepdrop germ_cert
recode lang_cert ///
	(2 = 1 "a - elementary use of language") ///
	(3 4 = 2 "b1/c2 - independent language use") ///
	(0 1 = 0 "other/ no certificate/not finished") ///
	, gen(germ_cert)
tabulate germ_cert syear, m col
lab var germ_cert "german certificate level"

gen germ_cert_any = germ_cert > 0 if germ_cert < .
lab var germ_cert_any "german certificate"

count
describe, short
save $mydata/msuemer/clean_outcomes, replace
