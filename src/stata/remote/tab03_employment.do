*==============================================================================*
* tab03_employment.do                       (was 00023A_analyses_remote.do)
*
* Purpose : The paper's headline result -- county supply of integration courses
*           and refugees' employment probability. Two LPMs: the total effect,
*           and the same interacted with duration of stay. Produces paper
*           Table 3 and nothing else, hence the exhibit prefix.
* Source  : 00023_mult_analyses.do:201-343
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : impute_sample.do -> $mydata/msuemer/sample_imputed
* Saves   : $mydata/msuemer/tab03_total, tab03_interact
*           (mi estimation results; see WRITE-ONLY below)
* Result  : results/comparisons/tab03_employment.md
*           results/tables/tab03_employment.tex
* Deviates: see FORCED DEVIATIONS below
* Author  : Emre Suemer, 2026-08-13
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
*
* Target: the paper reports 2.97* (1.19) for the supply coefficient. The
* 2026-08-08 run returned 2.98* (1.19). Note the do-file's inline comment at
* orig :287 claims the effect is "significant at 1%"; the published table
* reports * (p<0.05), and p = 0.013 agrees with the paper, not the comment.
*
* ---------------- THE SAVED FILES ARE WRITE-ONLY ----------------
* The predecessor of this file claimed Part E reads m_001p/m_002p back via
* `mimrgns using`. IT DOES NOT -- checked across every ported job: Part B uses
* its own m_001p_i* series and Parts E1-E3 re-estimate and save m_0022e,
* m_0032e and m_0042e. Nothing in the port ever reads these two files.
*
* They are still saved (the authors save them, and `mi estimate, saving()` is
* what makes a later mimrgns possible at all), but renamed from m_001p/m_002p
* to tab03_total/tab03_interact for one reason: the 2026-08-07 run left files
* under the old names on the server. Writing to fresh names means this job
* cannot be confused with that one, and a partial failure leaves nothing
* behind to be mistaken for a result. Same principle as the sample_* renames.
*
* ---------------- WHY 00023 IS CHUNKED BY TABLE, NOT BY LINE ----------------
* `eststo` stores estimates in MEMORY. Memory does not survive between
* SOEPremote jobs, so a table's models and its `esttab` MUST be in the same
* job. The chunking therefore follows the eight `esttab` calls, not the
* 190-line budget:
*
*   A  201-343   m_001p m_002p                      -> paper Table 3 (this)
*   B  343-562   m_001p_i1..i13 (loop)              -> Table S6
*   C  562-753   m_0011p..m_0016p                   -> paper Table 5
*   D  753-927   m_0021p..m_0052p                   -> paper Table 4
*   E  927-1055  mimrgns x3                         -> Figures 2a-c
*   F  1055-1228 m_001r m_001c m_001f m_001l        -> Tables S8, S9
*   G  1228-1344 m_0061p m_0062p m_0071p m_0072p    -> Table S11
*   H  1344-1556 m_0017..m_0022                     -> Table S10
*
* ---------------- FORCED DEVIATIONS ----------------
* (1) do config / cd / log using / exit / set matsize REMOVED. $controls_fv
*     is defined inside 00023 itself (orig :213), NOT in config.do, so no
*     config globals are needed here. $dataout -> $mydata/msuemer.
* (2) #delimit -> the global-append form used in clean_sample.
* (3) `capt program drop _mi_addstats` REMOVED -- `drop` is banned and the
*     program is defined exactly once per job, so nothing needs clearing.
*     Inside the program, `capture drop e_*` -> `capture soepdrop e_*`.
* (4) esttab's `using "$output/Table_2", scsv replace` REMOVED. The .csv
*     cannot come back; the table prints to the listing instead and is
*     transcribed locally, as with the sample funnel.
* (5) **esttab's `keep(...)` REMOVED -- the OPTION NAME contains the banned
*     token `keep`.** `order(...)` is retained and does the same job for
*     readability, and `indicate(...)` in $table_opt collapses the four sets
*     of fixed-effect dummies into YES rows, so the printed table stays
*     close to the paper's layout. The cost is a few extra coefficient rows.
*     `nobaselevels` suppresses the spurious `0.work0 ... 0.00 (.)` rows this
*     creates, and `varwidth(34)` stops the five county labels truncating to
*     an indistinguishable "Cou..".
* (6) `saving($output/m_001p)` -> `saving($mydata/msuemer/tab03_total)`; see
*     THE SAVED FILES ARE WRITE-ONLY above.
* (7) Two coefficient LABELS shortened to keep lines under 72 characters
*     (the interaction row and the CDU/CSU row). Descriptive text only.
*
* ---------------- LOOPS AND BACKTICKS ARE USED ----------------
* Confirmed safe by 18_loop_probe.do, so `_mi_addstats` is the authors' own
* program verbatim apart from the soepdrop swaps -- including its
* `mi xeq:`, backticks and `foreach`.
*
* ---------------- WHAT TO CHECK ----------------
*   mi query / mi des      -> M = 20, 5,467 obs before flong
*   both `mi estimate` tables print in full, with dots for 20 imputations
*   esttab                 -> compare against the paper's TABLE 3:
*        z_ratio_courseoport in m_001p should be ~2.97 percentage points
*        (transform(@*100 100) is applied), starred *.
*        N = 5467, groups = 2730, M_mi = 20, R2a ~ 0.2130.
*   the interaction in m_002p should be small and insignificant -- the
*        paper's claim that the effect is stable over duration of stay.
*
* ---------------- READ THE ASYLUM LABELS SCEPTICALLY ----------------
* $coeflabels calls 2.asyl_req_stat "-- Rejected" and 3.asyl_req_stat
* "-- No decision", and $table_opt's refcat says the reference is "approved".
* ALL THREE ARE WRONG, and they are the authors' own: the model uses
* ib1.asyl_req_stat and 00013_data_clean.do:1541 defines 1 "no decision",
* 2 "approved", 3 "rejected". So the omitted reference is NO DECISION, and
* the two printed rows are approved and rejected respectively. Preserved
* verbatim rather than silently corrected, because the point of the port is
* to reproduce the authors' output; the correction belongs in the write-up.
*
* > This job runs 2 x 20 imputed regressions with clustered SEs. Expect it
* > to be slow. Check for a reply before resending.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/tab03_employment.do
*==============================================================================*

* ============ SEND FROM HERE DOWN (below your auth header) ============
use $mydata/msuemer/sample_imputed, clear
mi query
mi des, detail
mi convert flong, clear

global controls_fv ib1.immigroup_nat i.nuts1_first i.syear
global controls_fv $controls_fv i.msample i.work0
global controls_fv $controls_fv c.total_years_edu0
global controls_fv $controls_fv i.female i.h_child i.arriv_fam
global controls_fv $controls_fv i.family0 i.trauma_exp c.age1st
global controls_fv $controls_fv ib1.asyl_req_stat
global controls_fv $controls_fv c.z_foreign_share c.z_density
global controls_fv $controls_fv c.z_unemplrate c.z_consimmi c.z_cdu

global keeporder_controls total_years_edu0 1.work0 1.female
global keeporder_controls $keeporder_controls 1.h_child 1.arriv_fam
global keeporder_controls $keeporder_controls 1.family0 age1st
global keeporder_controls $keeporder_controls 1.trauma_exp
global keeporder_controls $keeporder_controls 2.asyl_req_stat
global keeporder_controls $keeporder_controls 3.asyl_req_stat
global keeporder_controls $keeporder_controls z_foreign_share
global keeporder_controls $keeporder_controls z_density
global keeporder_controls $keeporder_controls z_unemplrate
global keeporder_controls $keeporder_controls z_consimmi z_cdu

global coeflabels total_years_edu0 "Premigration years of education"
global coeflabels $coeflabels ///
    1.work0 "With premigration work experience"
global coeflabels $coeflabels 1.female "Female"
global coeflabels $coeflabels 1.h_child "Children below 16 in household"
global coeflabels $coeflabels ///
    1.arriv_fam "Arrival to Germany with family"
global coeflabels $coeflabels 1.family0 "Premigration family support"
global coeflabels $coeflabels age1st "Age at the first interview"
global coeflabels $coeflabels 1.trauma_exp "With trauma experiences"
global coeflabels $coeflabels 2.asyl_req_stat "-- Rejected"
global coeflabels $coeflabels 3.asyl_req_stat "-- No decision"
global coeflabels $coeflabels ///
    z_foreign_share "County share foreigners, std."
global coeflabels $coeflabels ///
    z_density "County population density, std."
global coeflabels $coeflabels ///
    z_unemplrate "County unemployment rate, std."
global coeflabels $coeflabels ///
    z_consimmi "County concerns immigration, std."
global coeflabels $coeflabels z_cdu "County share CDU/CSU voters, std."

global table_opt collabels(none) constant not wide
global table_opt $table_opt starlevels(+ 0.1 * 0.05 ** 0.01)
global table_opt $table_opt compress nogaps nodepvars
global table_opt $table_opt refcat(2.asyl_req_stat ///
    "Status of the asylum request (Ref.: approved): ", nolabel)
global table_opt $table_opt indicate("Survey year fe = *.syear" ///
    "Survey sample fe = *.msample" ///
    "Federal State fe = *.nuts1_first" ///
    "Country of origin (aggregated) fe = *.immigroup_nat")
global table_opt $table_opt scalars(N groups M_mi e_r2 e_r2a)
global table_opt $table_opt sfmt(%9.0f %9.0f %9.0f %9.4f %9.4f)

program define _mi_addstats
    quietly {
        capture soepdrop e_*
        args estimates
        est des `estimates'
        mi xeq: `r(cmdline)'; gen e_r2 = e(r2); gen e_r2a = e(r2_a)
        foreach var of varlist e_* {
            mi est, post: mean `var'
            local `var' = _b[`var']
            estadd scalar `var' = ``var'', replace: `estimates'
        }
        soepdrop e_*
        capture soepdrop groups
        bysort pid: generate groups = _n
        count if groups == 1
        local groups = r(N)
        display `groups'
        estadd scalar groups = `groups', replace: `estimates'
    }
end

capture soepdrop m_001p
eststo m_001p: mi estimate, post dots ///
    saving($mydata/msuemer/tab03_total, replace) esample(m_001p): ///
    reg paid_work $controls_fv c.stay_dur c.z_ratio_courseoport ///
    [pweight=weight_p], vce(cluster pid)
_mi_addstats m_001p

capture soepdrop m_002p
eststo m_002p: mi estimate, post dots ///
    saving($mydata/msuemer/tab03_interact, replace) esample(m_002p): ///
    reg paid_work $controls_fv c.stay_dur##c.z_ratio_courseoport ///
    [pweight=weight_p], vce(cluster pid)
_mi_addstats m_002p

esttab m_001p m_002p, ///
    title("LANGUAGE COURSE SUPPLY AND EMPLOYMENT, p.p.") ///
    order(z_ratio_courseoport stay_dur ///
        c.stay_dur#c.z_ratio_courseoport $keeporder_controls _cons) ///
    coeflabels(z_ratio_courseoport "County supply of courses, std." ///
        stay_dur "Duration of stay, in months (/12)" ///
        c.stay_dur#c.z_ratio_courseoport "x County supply" ///
        $coeflabels _cons "Constant") ///
    $table_opt nobaselevels varwidth(34) ///
    transform(@*100 100) b(%9.2f) se(%9.2f)

display "23A ok"
