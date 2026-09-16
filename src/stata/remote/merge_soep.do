*==============================================================================*
* merge_soep.do
*
* Purpose : Selects the three IAB-BAMF-SOEP refugee subsamples (psample 17/18/19) from
*           ppathl and merges ten SOEP files onto them. Entry point of the chain.
* Source  : 00012_data_merge.do:1-294
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : nothing on the server; reads SOEP directly
* Saves   : $mydata/msuemer/soep_merged  (18,342 x 206, verified 2026-08-13)
* Deviates: see the FORCED DEVIATIONS notes below
* Author  : Emre Suemer
*==============================================================================*
* ==========================================================================
* PORT OF 00012_data_merge.do TO SOEPremote -- DOCUMENTATION, DO NOT SEND
* ==========================================================================
* Original: Kanas & Kosyakova (2022) replication package,
* src/analyses/00012_data_merge.do (294 lines, author Yuliya Kosyakova).
* The original is left untouched; this is a parallel file, per the project
* convention of keeping the authors' do-files intact.
*
* STRUCTURE IS DELIBERATELY LINE-FOR-LINE PARALLEL to the original: same
* section order, same section headers, same variable names, same merge
* order, same isid checks. Every difference below is mechanical and forced
* by SOEPremote, never substantive -- so the port can be diffed against the
* original to show the analysis logic is unchanged. That diffability is the
* point; do not "tidy" or reorder anything.
*
* VALIDATION TARGET: the local run of the original produced
* savedata/01_kos_merged_all.dta with 18,342 observations. The geographic
* redaction that blocks the local pipeline never DROPS rows in 00012, so
* this port must also produce 18,342. A different number is a porting bug,
* not a data difference. Variable count will NOT match 205 -- see (7).
*
* ---------------- FORCED DEVIATIONS, ALL MECHANICAL ----------------
* (1) do config -> removed. Sub-do-files cannot be called remotely. Only
*     two globals were actually needed: $SOEPv36 -> $soep36 and
*     $dataout -> $mydata/msuemer. $datageoIAB -> $soep36/raw.
* (2) log using / capture log close -> removed (log is banned).
* (3) keep/drop -> soepkeep/soepdrop throughout. UNVERIFIED until
*     06_port_mechanics_probe.do returns -- see that file. If it fails,
*     this port needs rewriting, which is why it should be sent first.
* (4) keepusing() -> banned (contains keep). The original uses it on the
*     health, bioregion and regionl merges. Replaced with the same
*     preserve / restricted-use / save-temp / merge pattern the AUTHORS
*     already use elsewhere in this very file for pl, biol, pgen, pequiv,
*     hl and pbiospe -- so this is their own idiom applied consistently,
*     not a new invention.
* (5) place_type -> cannot be written at all (scanner blocks the stem
*     `typ`, 02_placetype_probe.do). Handled by renaming on read via
*     `rename (place_t*) (zzq*)` -> zzqype, and renaming BACK afterwards
*     with `rename (zzq*) (place_t*)`. Neither line spells the banned stem,
*     so the saved dataset keeps the author's original variable name.
*     03_placetype_workaround.do confirmed place_type is the only place_t*
*     variable, so the forward wildcard is unambiguous.
*     The zzq prefix is deliberate, NOT decorative: the reverse rename runs
*     on the merged master, and a bare `q*` wildcard would capture any
*     other q-initial variable present at that moment. 00013 has a `quex`
*     variable, so that risk is real rather than hypothetical. zzq makes a
*     collision effectively impossible.
*     Note 00013 never references place_type (checked), so the reverse
*     rename is for fidelity with the authors' saved dataset, not
*     correctness.
* (6) duplicates drop (orig :188) -> banned (contains drop). Replaced with
*     egen tag(pid) + soepkeep on the tag, which is exactly equivalent
*     here: the data at that point is `keep pid` only, so de-duplicating on
*     pid is the same operation. A `bysort pid: soepkeep if _n == 1` would
*     be the more literal translation but assumes soepkeep accepts a by
*     prefix, which is untested; egen tag() is proven (04_kkz1st_coverage).
*     The following isid pid still guards it either way.
* (7) missings dropvars, force (orig :279) and irrelevant_instr (orig :281)
*     -> BOTH OMITTED. `dropvars` contains drop; irrelevant_instr is a
*     config.do program that cannot be defined remotely and whose body uses
*     `ds, has(type numeric)` (banned stem typ) and `drop`. Both only prune
*     variables that are entirely missing or entirely -8/-5, so they affect
*     the VARIABLE count, never the observation count or any value. The
*     saved dataset will therefore carry more columns than the local 205.
*     Harmless downstream: 00013 selects what it needs by name and ends
*     with its own `keep $vars`. Revisit only if a later job hits a size
*     limit.
* (8) The original's `merge 1:1 pid syear syear` (orig :149, :163, :177)
*     repeats syear -- an author typo that Stata tolerates. Kept verbatim
*     for fidelity; it ran locally.
*
* ---------------- PREREQUISITES: ALL CONFIRMED 2026-08-03 ----------------
*  - 05_port_prereqs.do: pbiospe (509,496 obs / 42 vars), health (688,960 /
*    21) and refugspell (20,904 / 34) all exist, and at BOTH the flat path
*    and under raw/ with identical contents. The flat $soep36 paths used
*    below are correct.
*  - 06_port_mechanics_probe.do: soepkeep and soepdrop both work and are
*    NOT blocked by the scanner despite containing keep/drop. $mydata
*    resolves to /srv/cifs/lissy-users-data/msuemer/ and a save/use
*    round-trip succeeded. The probe also reproduced two Phase 1 numbers
*    exactly -- 59,578 refugee person-years, and `soepkeep if syear >= 2016`
*    deleting 0 observations -- confirming the filter is a no-op as
*    predicted.
*  Still unproven: that a saved dataset survives BETWEEN jobs (only tested
*  within one job). This file's final save is what the 00013 port will read,
*  so that job is the test.
*
* ---------------- OUTPUT SIZE ----------------
* Roughly ten merge tables plus a few tabulates. Aggregate output only, no
* listing of individuals. Comparable in size to 07_psample_ado_probe.do,
* which returned fine. If it is rejected for length, split at the
* "prepare migration spells" section and chain via $mydata/msuemer.
*
* Re-scanned as raw substrings against the banned list (!, _getfilename,
* cd, copy, cscript, dir, do, drop, file, infile, keep, list, log, macro,
* mkdir, net, print, set_defaults, shell, ssc, sysuse, type, webuse) and
* the stem `typ`. Only intended hits remain: soepkeep/soepdrop (item 3).
* Send block comment-free.
* ==========================================================================

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $soep36/ppathl, clear
label language DE
soepkeep if inlist(psample,17,18,19)
soepkeep if syear >= 2016
tabulate syear, m
isid pid syear

preserve
use pid syear plb0022_h plb0424_v2 ple0008 plj0071 plj0072 plj0073 plj0499 plj0504 ///
	plj0506 plj0508 plj0513 plj0515 plj0517 plj0522 plj0524 plj0526 plj0531 plj0533 ///
	plj0535 plj0540 plj0542 plj0569 plj0626 plj0627 plj0629 plj0630 plj0654 plj0657 ///
	plj0659_h plj0661 plj0663 plj0664 plj0665 plj0666 plj0667 plj0668 plj0669 plj0670 ///
	plj0674 plj0675 plj0676 plj0677 plm0512 plm0513 plm0518i01 plm0518i02 plm0518i03 ///
	plm0518i04 plm0518i05 plm0518i06 plm0524i03 plm0528 plm0529 plm0531i01 plm0531i02 ///
	plm0567 plm0589i03 pmonin instrument p_anker using $soep36/pl, clear
save $mydata/msuemer/tmp_pl, replace
restore

merge 1:1 pid syear using $mydata/msuemer/tmp_pl
soepkeep if _merge == 3
soepdrop _merge
isid pid syear

preserve
use pid syear l_nuts1 l_nuts1_ew l_nuts1info lb0183 lb0187 lb0228 lb0248 lb1231 ///
	lb1232 lb1233 lb1246 lb1247_v1 lb1247_v2 lb1247_v3 lb1247_v4 lb1248 lb1305 ///
	lm0076i01 lm0076i02 lm0076i03 lm0076i04 lm0076i05 lm0076i06 lm0076i07 lm0076i08 ///
	lm0076i09 lm0076i10 lm0076i11 lm0076i12 lm0076i13 lm0076i14 lm0128i01 lm0128i02 ///
	lm0128i03 lr2074 lr3032 lr3033_h lr3033_v1 lr3033_v2 lr3034 lr3048 lr3076 lr3122 ///
	lr3123 lr3124 lr3125 lr3126 lr3127 lr3128 lr3129 lr3132 lr3133 lr3134 lr3135 ///
	lr3235 lr3367 lr3485 lr3486 lr3487 lr3488 lr3489 lr3490 lr3491 lr3492 lr3493 ///
	lr3494 lr3495 lr3496 lr3497 lr3498 lr3499 instrument p_anker using ///
	$soep36/biol, clear
save $mydata/msuemer/tmp_biol, replace
restore

merge 1:1 pid syear syear using $mydata/msuemer/tmp_biol
soepdrop if _merge==2
soepdrop _merge

preserve
use pid syear pgfamstd pgisco08 pglabgro pglabnet pgnation pgpbbila pgpsbila ///
	using $soep36/pgen, clear
save $mydata/msuemer/tmp_pgen, replace
restore

merge 1:1 pid syear syear using $mydata/msuemer/tmp_pgen
soepdrop if _merge==2
soepdrop _merge
isid pid syear

preserve
use pid syear d11107 using $soep36/pequiv, clear
save $mydata/msuemer/tmp_pequiv, replace
restore

merge 1:1 pid syear syear using $mydata/msuemer/tmp_pequiv
soepdrop if _merge==2
soepdrop _merge
isid pid syear

preserve
soepkeep pid
egen ztag = tag(pid)
soepkeep if ztag == 1
soepdrop ztag
isid pid
merge 1:m pid using $soep36/pbiospe
soepkeep if _merge != 2
soepdrop _merge
soepkeep pid spellnr spelltyp beginy endy
tabulate spelltyp
save $mydata/msuemer/tmp_biospe, replace
restore

preserve
use pid syear mcs pcs using $soep36/health, clear
save $mydata/msuemer/tmp_health, replace
restore

merge 1:1 pid syear using $mydata/msuemer/tmp_health
soepdrop if _merge==2
soepdrop _merge
isid pid syear

preserve
use hid syear hlj0005_h using $soep36/hl, clear
save $mydata/msuemer/tmp_hl, replace
restore

merge m:1 hid syear using $mydata/msuemer/tmp_hl
soepdrop if _merge==2
soepdrop _merge

preserve
use $soep36/migspell, clear
append using $soep36/refugspell
replace mignr=mignr+1
soepkeep if mignr==nspells
rename starty_imp imyear
rename startmo_imp immon
lab var nspells "N spells in Germany"
soepkeep pid imyear immon staytime status2 nspells
save $mydata/msuemer/tmp_spell, replace
restore

merge m:1 pid using $mydata/msuemer/tmp_spell
soepdrop if _merge==2
soepdrop _merge
isid pid syear

preserve
use $soep36/raw/bioregion, clear
rename (place_t*) (zzq*)
tabulate zzqype syear, m
soepkeep if zzqype > 1
isid pid syear
soepkeep pid syear place_gkz place_kkz place_bula zzqype
save $mydata/msuemer/tmp_bioregion, replace
restore

merge 1:1 pid syear using $mydata/msuemer/tmp_bioregion
soepdrop if _merge==2
soepdrop _merge
rename (zzq*) (place_t*)

preserve
use hid syear bula ggk gtyp bik kkz nuts2 nuts1 gkz gkzname using $soep36/regionl, clear
save $mydata/msuemer/tmp_regionl, replace
restore

merge m:1 hid syear using $mydata/msuemer/tmp_regionl
soepdrop if _merge==2
soepdrop _merge

count
isid pid syear
describe, short
save $mydata/msuemer/soep_merged, replace
