*==============================================================================*
* verify_server_state.do
*
* Purpose : Fingerprint every intermediate the Table 1 chain depends on, so the
*           server state stops being undocumented. Reports obs, vars and a value
*           checksum per file. Reads only; writes nothing.
* Source  : none (written for this thesis)
* Runs    : SOEPremote (soep-exec@diw.de)
* Depends : nothing. Safe to send at any time, in parallel with other jobs.
* Saves   : nothing
* Result  : results/verification/remote_state.md
* Author  : Emre Suemer  ·  2026-08-13
*==============================================================================*
* DOCUMENTATION, DO NOT SEND THIS PART
* ==========================================================================
*
* WHY THIS EXISTS
*
* clean_sample.do opens with `use $mydata/msuemer/clean_asylum`. That file was
* produced on 2026-08-07 by a chain of nine jobs. Nothing on disk here proves it
* is the output of the code we currently hold -- we have been trusting it because
* the numbers it produced looked right. That is exactly the dependency this job
* converts into a recorded, checkable fact.
*
* It is NOT a substitute for a cold re-run. It proves the files exist and match a
* fingerprint; it cannot prove the fingerprint came from the current code. What it
* buys is that a cold re-run can be scheduled deliberately, after the upstream
* jobs are migrated, instead of being forced now by uncertainty.
*
* WHY A MISSING FILE IS THE MOST USEFUL RESULT
*
* SOEPremote does not halt on runtime errors. A cleared intermediate gives r(601)
* and the job carries on -- so a downstream job would read a STALE file and save a
* wrong result that still passes isid. This is not hypothetical: supply_p13 went
* missing once and 11/13/14 all "succeeded" on a 2,651-row file. Because r(601) is
* non-halting, every file can be probed in ONE job: the not-founds are the answer.
*
* WHAT TO DO WITH THE OUTPUT
*
* Transcribe into results/verification/remote_state.md. Compare N and K against the
* figures recorded in docs/lab_notebook.md (soep_merged 18,342 x 206; clean_county
* 18,342 x 266; clean_asylum 18,342 x 298; cty_supply 2,807 x 16;
* sample_analytic 5,467 x 81). A mismatch means re-run that stage.
*
* The checksum is sum(pid) for person files and sum(kkz) for the county panel --
* order-independent, so it is insensitive to sort order, and sensitive to any
* change in which rows are present. Paired with N it is enough to detect a
* silently truncated or partially-written file.
*
* Pre-flight:
*   python3 src/analyses/remote/tools/preflight.py src/stata/remote/verify_server_state.do
* ==========================================================================
* ============ SEND FROM HERE DOWN (below your auth header) ============
display "FINGERPRINT START"

foreach f in soep_merged clean_outcomes clean_geography clean_county ///
             clean_citizenship clean_citizenship_tc clean_confounders clean_asylum ///
             sample_full sample_analytic {
    capture use $mydata/msuemer/`f', clear
    if _rc {
        display "FP `f' ABSENT rc=" _rc
    }
    else {
        count
        local n = r(N)
        quietly describe, short
        local k = r(k)
        summarize pid
        display "FP `f' N=" `n' " K=" `k' " S=" %15.0f r(sum)
    }
}

capture use $mydata/msuemer/cty_supply, clear
if _rc {
    display "FP cty_supply ABSENT rc=" _rc
}
else {
    count
    local n = r(N)
    quietly describe, short
    local k = r(k)
    summarize kkz
    display "FP cty_supply N=" `n' " K=" `k' " S=" %15.0f r(sum)
    tabulate year
}

capture use $mydata/msuemer/clean_lingprox, clear
if _rc {
    display "FP clean_lingprox ABSENT rc=" _rc
}
else {
    count
    local n = r(N)
    quietly describe, short
    local k = r(k)
    summarize proxling
    display "FP clean_lingprox N=" `n' " K=" `k' " S=" %15.0f r(sum)
}

display "FINGERPRINT END"
