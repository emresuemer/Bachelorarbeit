#!/usr/bin/env python3
"""Generate the Part C country-mapping and linguistic-proximity jobs.

WHY GENERATED RATHER THAN HAND-WRITTEN. Part C calls two sub-do-files via
`qui: do` (00013:859, :912). `do` is banned on SOEPremote, so they have to be
inlined -- 1,184 + 250 = 1,434 lines, which at ~190 lines per job is eight
e-mails of hand-copied country codes. Every one of those lines is a chance to
mistype a code into a variable nothing downstream would flag.

Instead this script *executes the original mapping in Python*, restricted to
the citizenships that actually occur, and emits the result. The output is
therefore derived from the authors' own files, not retyped from them.

HOW THE ORIGINAL MAPPING WORKS. It is a three-stage chain of `replace`s:

    country_name_str  ->  citizenship_var  ->  iso3166  ->  iso_num_o
    "[30] Syrien"         "Syrian Arab Rep"     "SYR"        760

Stage 1 matches on the *decoded label text*. That is the part that cannot
survive porting as-is: 266 of its 385 rules key on bare German strings with no
[NN] prefix, and the label text differs between editions -- our local EU
edition has stripped the non-ASCII characters, so its labels read "[47]
thiopien" and "[32] Ruland". A non-ASCII character anywhere in a job is fatal
(WRONG HEADER), so matching remote label text is not an option either.

So this script composes the whole chain down to what it really is -- a map from
the *numeric* pgnation code to an ISO code -- and emits `replace ... if
country_name == <code>`. Matching on the code rather than the label is immune
to label-text and encoding differences in both directions, and is pure ASCII.

WHICH CODES. Measured from the local SOEP: ppathl psample 17/18/19 joined to
pgen gives 19,365 person-years and exactly 71 distinct pgnation codes. That is
a superset of the remote analysis sample (18,342 rows, which additionally
requires the pl merge), and citizenship is not a redacted variable, so the code
set cannot be larger remotely. The emitted job keeps the original's own
`tab country_name if iso_num_o == 0` check, which lists any code this mapping
missed -- read it before trusting the run.

Six of the 71 map to nothing, and that is the original's behaviour, not a gap:
98 Staatenlos (-> stateless, handled separately), -1/-2 (SOEP missing), and
999/149/172 (Ethnische Minderheiten / Kurdistan / Kaukasus -- not countries).

Run from src/analyses/:  python3 remote/tools/make_partc_jobs.py
"""

import re
import sys
from pathlib import Path

import pandas as pd
from pandas.io.stata import StataReader

HERE = Path(__file__).resolve().parent
ANALYSES = HERE.parent.parent
REMOTE = HERE.parent
JOBS = REMOTE / "jobs"
# Migrated Part C jobs live under src/stata/remote/ (repo migration, batch 2).
# Writing them back to REMOTE would resurrect the pre-migration filenames.
STATA_REMOTE = Path(__file__).resolve().parents[4] / "src/stata/remote"
SOEP = ANALYSES.parent.parent / "data" / "SOEP-CORE.v36eu_STATA"
MT = ANALYSES / "macro_orig" / "Melitz_Toubal_proxling"

ISO_SRC = ANALYSES / "00_X_iso_country_codes_to_refugee_sample.do"
MARKER = "* ============ SEND FROM HERE DOWN (below your auth header) ============"

# proxling/proxling2 are transmitted as integers at this scale and divided back
# down in the job. 1e6 keeps six decimals, far beyond the third decimal that
# survives into ln(proxling2*100 + 1).
PROX_SCALE = 1_000_000

# Single source of truth, so a token learned from a rejection reaches every
# generator at once. It gained `update` on 2026-08-30; see preflight.py.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from preflight import BANNED  # noqa: E402


def parse_original():
    """Pull the three stages of replaces out of the authors' file, in order."""
    text = ISO_SRC.read_text(encoding="utf-8", errors="replace").splitlines()
    pats = {
        "s1": re.compile(r'^\s*replace\s+citizenship_var\s*=\s*"(.*?)"\s*'
                         r'if\s+country_name_str\s*==\s*"(.*?)"'),
        "s1n": re.compile(r'^\s*replace\s+citizenship_var\s*=\s*"(.*?)"\s*'
                          r'if\s+country_name\s*==\s*(\d+)'),
        "s2": re.compile(r'^\s*replace\s+iso3166\s*=\s*"(.*?)"\s*'
                         r'if\s+citizenship_var\s*==\s*"(.*?)"'),
        "s3": re.compile(r'^\s*replace\s+iso_num_o\s*=\s*(\d+)\s*'
                         r'if\s+iso3166\s*==\s*"(.*?)"'),
    }
    out = {k: [] for k in pats}
    for line in text:
        if line.lstrip().startswith("*"):
            continue
        for key, rx in pats.items():
            m = rx.match(line)
            if m:
                out[key].append(m.groups())
                break
    return out


def resolve(code, label, rules):
    """Run one (code, label) pair through the original chain, in file order.

    Mirrors the initialisations exactly: citizenship_var starts as the decoded
    label, iso3166 as "miss", iso_num_o as 0. Later replaces overwrite earlier
    ones, which is why order matters and why this is a loop rather than a dict.
    """
    cvar = label
    for new, match in rules["s1"]:
        if match == label:
            cvar = new
    for new, num in rules["s1n"]:
        if int(num) == code:
            cvar = new
    iso = "miss"
    for new, match in rules["s2"]:
        if match == cvar:
            iso = new
    isonum = 0
    for new, match in rules["s3"]:
        if match == iso:
            isonum = int(new)
    return cvar, iso, isonum


def observed_codes():
    """The pgnation codes present in the refugee subsamples, with their labels."""
    pp = pd.read_stata(SOEP / "ppathl.dta",
                       columns=["pid", "syear", "psample"], convert_categoricals=False)
    ref = pp[pp.psample.isin([17, 18, 19])][["pid", "syear"]]
    pg = pd.read_stata(SOEP / "pgen.dta",
                       columns=["pid", "syear", "pgnation"], convert_categoricals=False)
    joined = ref.merge(pg, on=["pid", "syear"], how="inner")
    with StataReader(SOEP / "pgen.dta") as reader:
        labels = reader.value_labels()["pgnation"]
    counts = joined.pgnation.value_counts()
    return [(int(c), labels.get(int(c), ""), int(n))
            for c, n in counts.sort_index().items()]


def proximity_table(keep_iso):
    """Rebuild 00013:984-1010 locally: the ling_web/proxling merge, DEU only."""
    web = pd.read_stata(MT / "ling_web.dta", convert_categoricals=False)
    prox = pd.read_stata(MT / "proxling.dta", convert_categoricals=False)
    web = web[web.iso_d == "DEU"].rename(columns={"iso_d": "iso3_d", "iso_o": "iso3_o"})
    merged = web.merge(prox, on=["iso3_o", "iso3_d"], how="outer")
    merged = merged[merged.iso3_d == "DEU"]
    merged["proxling2"] = merged.proxling2.fillna(merged.prox2)
    merged["proxling"] = merged.proxling.fillna(merged.prox1)
    table = merged[["iso3_o", "proxling", "proxling2"]].dropna(subset=["iso3_o"])
    assert not table.iso3_o.duplicated().any(), "proximity table has duplicate origins"
    return table[table.iso3_o.isin(keep_iso)].sort_values("iso3_o")


def preflight(text):
    body = text.split(MARKER, 1)[1] if MARKER in text else text
    words, cur = set(), []
    for ch in body:
        if ch.isalpha():
            cur.append(ch.lower())
        elif cur:
            words.add("".join(cur))
            cur = []
    if cur:
        words.add("".join(cur))
    bad = sorted(words & BANNED)
    nonascii = sorted({c for c in body if ord(c) > 126})
    return bad, nonascii


def write(path, text):
    bad, nonascii = preflight(text)
    if bad or nonascii:
        sys.exit(f"{path.name}: banned={bad} nonascii={nonascii}")
    over = [l for l in text.split(MARKER, 1)[-1].splitlines() if len(l) > 72]
    if over:
        sys.exit(f"{path.name}: {len(over)} line(s) over 72 chars, e.g. {over[0]!r}")
    path.write_text(text, encoding="ascii")
    lines = text.split(MARKER, 1)[-1].strip().count("\n") + 1
    print(f"  {path.name}: {lines} send lines, {len(text):,} bytes")
    return lines


# The repo-wide header standard (docs/lab_notebook.md, "Repository migration"). It MUST be
# emitted here rather than added to the files afterwards: these four jobs are
# generated, so a hand-applied header is silently wiped on the next regeneration.
STANDARD = {
    "PART C1": ("clean_citizenship.do",
                "SOEP country codes -> ISO 3166 numeric, keyed on the numeric\n"
                "*           code rather than German label text."),
    "PART C2": ("clean_citizenship_tc.do",
                "The time-constant citizenship variable, plus the inverse ISO\n"
                "*           map the authors keep in 00_X_iso.do."),
    "LINGUISTIC PROXIMITY": ("clean_lingprox.do",
                "Melitz & Toubal linguistic-proximity-to-German table, embedded\n"
                "*           by input, restricted to the origins that occur."),
    "PART C3": ("clean_confounders.do",
                "The proximity merge and the remaining personal confounders."),
}


def head(title, orig, reads, saves, notes):
    name, purpose = STANDARD[title]
    out = ["*" + "=" * 78 + "*",
           f"* {name}",
           "*",
           "* GENERATED BY src/python/lmi/remote/make_partc_jobs.py",
           "*           -- DO NOT EDIT BY HAND, REGENERATE",
           "*",
           f"* Purpose : {purpose}",
           f"* Source  : 00013_data_clean.do:{orig}",
           "* Runs    : SOEPremote (soep-exec@diw.de)",
           f"* Depends : {reads}",
           f"* Saves   : $mydata/msuemer/{saves}",
           "* Deviates: see the notes below",
           "* Author  : Emre Suemer",
           "*" + "=" * 78 + "*",
           "* " + "=" * 72,
           f"* PORT OF 00013_data_clean.do, {title} (orig lines {orig})",
           "* DOCUMENTATION, DO NOT SEND THIS PART",
           "* " + "=" * 72,
           f"* Reads  $mydata/msuemer/{reads}",
           f"* Writes $mydata/msuemer/{saves}",
           "*",
           "* Do not send until the previous job's listing shows its .dta saved.",
           "* A missing input does not halt a SOEPremote job.",
           "*"]
    out += ["* " + n for n in notes]
    out += ["* " + "=" * 72, "", MARKER]
    return out


def job_c1(rules, codes):
    """Personal confounders + the composed pgnation -> ISO numeric mapping."""
    mapped = [(c, resolve(c, lab, rules)) for c, lab, _ in codes]
    lines = [f"replace iso_num_o = {num} if country_name == {c}"
             for c, (_, _, num) in mapped if num]
    unmapped = [c for c, (_, _, num) in mapped if not num]

    notes = [
        "The country block (orig :854-871). The authors' 1,184-line sub-do-file",
        "is called with `qui: do`, which is banned, and it matches on decoded",
        "German label TEXT -- unusable here, because label text differs between",
        "editions and any non-ASCII character is fatal to a job.",
        "",
        f"So the chain country_name_str -> citizenship_var -> iso3166 ->",
        f"iso_num_o was executed in Python and collapsed to its composition:",
        f"{len(lines)} direct code -> ISO-numeric assignments. Matching on the",
        "numeric code is immune to label text and is pure ASCII.",
        "",
        f"iso3166 is not built. The original renames it to citizenship_iso and",
        "drops it unused at :915, so nothing observes its absence.",
        "",
        f"Codes deliberately left at 0 (the original leaves them too): "
        f"{', '.join(map(str, unmapped))}.",
        "  98  Staatenlos  -> handled by the `stateless` flag below",
        "  -1/-2           -> SOEP missing codes",
        "  999/149/172     -> Ethnische Minderheiten / Kurdistan / Kaukasus,",
        "                     which are not countries",
        "",
        "> CHECK `tab country_name if iso_num_o == 0` IN THE LISTING. It must",
        "> show only those six codes. Anything else is a citizenship this",
        "> mapping missed, and the run has to be redone with it added.",
        "",
        "stateless: the original sets it from the English name string",
        "(citizenship == \"stateless\"). Code 98 is the only pgnation value that",
        "reaches that string, so it is set from the code directly and the",
        "English-name variable is never built.",
    ]
    body = [
        "use $mydata/msuemer/clean_county, clear",
        "count",
        "xtset pid syear",
        "",
        "gen year = syear",
        "assert year != 2015",
        "",
        "gen female = sex == 2",
        "lab var female \"female\"",
        "tabulate female",
        "",
        "gen h_child = d11107 >= 1 if d11107 < .",
        "label var h_child \"children in the household\"",
        "",
        "rename partner partner_orig",
        "tabulate partner_orig pgfamstd, m",
        "gen partner = .",
        "label var partner \"partner in the household\"",
        "replace partner = 1 if inlist(plj0627,1)",
        "replace partner = 1 if inlist(plj0630,1)",
        "replace partner = 1 if inlist(partner_orig,1,2)",
        "recode partner .= 0 if inlist(plj0627,2,3,4,5)",
        "recode partner .= 0 if inlist(plj0630,2,3,4,5)",
        "recode partner .= 0 if inlist(partner_orig,0)",
        "recode partner .= 0 if inlist(plj0629,2)",
        "tabulate partner, m",
        "",
        "gen age = syear - gebjahr if gebjahr > 0",
        "lab var age \"current age\"",
        "bysort pid (syear): egen age1st = min(age)",
        "lab var age1st \"age the first interview\"",
        "gen age_arriv = arrival_yr - gebjahr if gebjahr > 0",
        "lab var age_arriv \"age at arrival\"",
        "summarize age age1st age_arriv",
        "",
        "clonevar country_name = pgnation",
        "gen iso_num_o = 0",
    ] + lines + [
        "",
        "tabulate country_name if iso_num_o == 0, m",
        "count if iso_num_o == 0",
        "",
        "rename iso_num_o citizenship_iso_num",
        "label var citizenship_iso_num \"citizenship: iso code (numeric)\"",
        "",
        "gen stateless = 1 if country_name == 98",
        "bysort pid (syear): carryforward stateless, replace",
        "bysort pid (minusyear): carryforward stateless, replace",
        "recode stateless (. = 0)",
        "label var stateless \"reported stateless\"",
        "tabulate stateless, m",
        "soepdrop country_name",
        "",
        "count",
        "save $mydata/msuemer/clean_citizenship, replace",
        "display \"13C1 ok\"",
    ]
    return "\n".join(head("PART C1", "793-905", "clean_county", "clean_citizenship",
                          notes) + body) + "\n"


def job_c2(rules, codes):
    """Time-constant citizenship, the ISO-numeric -> ISO3 inverse, immigroup."""
    seen, inverse = set(), []
    for c, lab, _ in codes:
        _, iso, num = resolve(c, lab, rules)
        if num and num not in seen:
            seen.add(num)
            inverse.append(f'replace cou_help = "{iso}" if citizenship_iso_num_tc == {num}')
    notes = [
        "The time-constant citizenship construction (orig :917-991), unchanged,",
        "plus the inverse map that the authors keep in 00_X_iso.do -- another",
        f"`qui: do`, 250 lines. Only the {len(inverse)} codes that occur are",
        "emitted; the rest could never match.",
        "",
        "KOS is not special-cased here. The original adds",
        "`replace cou_help = \"KOS\" if citizenship_iso_num_tc == 999` after the",
        "sub-do-file because 999 is its own invention (Kosovo has no ISO number);",
        "999 is already in the generated list below, so the extra line would be a",
        "no-op and is omitted.",
    ]
    body = [
        "use $mydata/msuemer/clean_citizenship, clear",
        "count",
        "xtset pid syear",
        "",
        "recode citizenship_iso_num (0 = .)",
        "gen helpvar = citizenship_iso_num if n == 1",
        "bysort pid (syear): carryforward helpvar, replace",
        "replace helpvar = citizenship_iso_num if helpvar >= .",
        "replace helpvar = citizenship_iso_num if helpvar >= . & n == 2",
        "bysort pid (syear): carryforward helpvar, replace",
        "bysort pid (minusyear): carryforward helpvar, replace",
        "replace helpvar = citizenship_iso_num if helpvar >= . & n == 3",
        "bysort pid (syear): carryforward helpvar, replace",
        "bysort pid (minusyear): carryforward helpvar, replace",
        "replace helpvar = citizenship_iso_num if helpvar >= . & n == 4",
        "bysort pid (syear): carryforward helpvar, replace",
        "bysort pid (minusyear): carryforward helpvar, replace",
        "",
        "rename helpvar citizenship_iso_num_tc",
        "recode citizenship_iso_num_tc (. = 0)",
        "label variable citizenship_iso_num_tc \"1st reported citizenship, num\"",
        "soepdrop citizenship_iso_num",
        "",
        "gen cou_help = \"\"",
    ] + inverse + [
        "rename cou_help citizenship_iso_tc",
        "replace citizenship_iso_tc = \"missing\" if citizenship_iso_tc == \"\"",
        "label variable citizenship_iso_tc \"1st reported citizenship, iso\"",
        "tabulate citizenship_iso_tc, m",
        "",
        "label define immigroup 1 \"SYR\" 2 \"AFG\" 3 \"IRQ\" 4 \"Eritrea\" ///",
        "    5 \"IRN\" 6 \"rest MENA\" 7 \"former USSR\" 8 \"West Balkan\" ///",
        "    9 \"Rest Africa\" 10 \"Rest\" 11 \"stateless\", replace",
        "",
        "gen immigroup_nat = .",
        "replace immigroup_nat = 1 if inlist(citizenship_iso_tc,\"SYR\")",
        "replace immigroup_nat = 2 if inlist(citizenship_iso_tc,\"AFG\")",
        "replace immigroup_nat = 3 if inlist(citizenship_iso_tc,\"IRQ\")",
        "replace immigroup_nat = 4 if inlist(citizenship_iso_tc,\"ERI\")",
        "replace immigroup_nat = 5 if inlist(citizenship_iso_tc,\"IRN\")",
        "replace immigroup_nat = 6 if ///",
        "    inlist(citizenship_iso_tc,\"DZA\",\"LBN\",\"MAR\",\"PSE\")",
        "replace immigroup_nat = 6 if ///",
        "    inlist(citizenship_iso_tc,\"EGY\",\"YEM\",\"SAU\",\"TUN\",\"JOR\") | ///",
        "    inlist(citizenship_iso_tc,\"LBY\",\"ARE\",\"KWT\")",
        "replace immigroup_nat = 7 if ///",
        "    inlist(citizenship_iso_tc,\"RUS\",\"ARM\",\"AZE\",\"GEO\",\"KGZ\")",
        "replace immigroup_nat = 7 if ///",
        "    inlist(citizenship_iso_tc,\"MDA\",\"TJK\",\"TKM\",\"UKR\",\"UZB\") | ///",
        "    inlist(citizenship_iso_tc,\"MNG\")",
        "replace immigroup_nat = 8 if ///",
        "    inlist(citizenship_iso_tc,\"ALB\",\"BIH\",\"KOS\",\"MKD\",\"MNE\") | ///",
        "    inlist(citizenship_iso_tc,\"SRB\",\"HRV\")",
        "replace immigroup_nat = 9 if ///",
        "    inlist(citizenship_iso_tc,\"BFA\",\"CIV\",\"CMR\",\"COG\",\"ETH\") | ///",
        "    inlist(citizenship_iso_tc,\"GHA\",\"GIN\",\"GMB\",\"KEN\")",
        "replace immigroup_nat = 9 if ///",
        "    inlist(citizenship_iso_tc,\"MLI\",\"NER\",\"NGA\",\"RWA\",\"SDN\") | ///",
        "    inlist(citizenship_iso_tc,\"SEN\",\"SLE\",\"SOM\")",
        "replace immigroup_nat = 9 if ///",
        "    inlist(citizenship_iso_tc,\"TCD\",\"UGA\",\"AGO\",\"GNB\",\"ROU\")",
        "replace immigroup_nat = 10 if ///",
        "    inlist(citizenship_iso_tc,\"BGD\",\"NPL\",\"IND\",\"LKA\",\"PAK\") | ///",
        "    inlist(citizenship_iso_tc,\"TUR\")",
        "replace immigroup_nat = 10 if ///",
        "    inlist(citizenship_iso_tc,\"FRA\",\"GBR\",\"GRC\",\"ITA\",\"VEN\")",
        "recode immigroup_nat . = 11 if stateless == 1",
        "label variable immigroup_nat \"citizenship, aggr\"",
        "label values immigroup_nat immigroup",
        "tabulate immigroup_nat, m",
        "",
        "label define citiz_tc3 1 \"Good remain perspectives\" ///",
        "    2 \"Secure\" 3 \"Other\", replace",
        "gen citiz_tc3 = .",
        "replace citiz_tc3 = 1 if ///",
        "    inlist(citizenship_iso_tc,\"SYR\",\"IRQ\",\"IRN\",\"ERI\",\"SOM\")",
        "replace citiz_tc3 = 2 if ///",
        "    inlist(citizenship_iso_tc,\"ALB\",\"BIH\",\"KOS\",\"MKD\",\"MNE\") | ///",
        "    inlist(citizenship_iso_tc,\"SRB\",\"GHA\",\"SEN\")",
        "recode citiz_tc3 . = 3 if immigroup_nat < .",
        "label variable citiz_tc3 \"coo, clustering\"",
        "label values citiz_tc3 citiz_tc3",
        "tabulate citiz_tc3, m",
        "",
        "count",
        "save $mydata/msuemer/clean_citizenship_tc, replace",
        "display \"13C2 ok\"",
    ]
    return "\n".join(head("PART C2", "917-985", "clean_citizenship", "clean_citizenship_tc",
                          notes) + body) + "\n"


def job_prox(table):
    notes = [
        "The Melitz-Toubal linguistic-proximity table (orig :984-1010).",
        "",
        "The original builds it inside a preserve block from two local .dta",
        "files (ling_web, proxling). Those cannot be attached to a job, so the",
        "merge was rebuilt locally and the result is embedded with `input`.",
        "",
        f"{len(table)} rows: every ISO3 that occurs in this sample, plus ISR,",
        "which the original substitutes for PSE. Origins that never occur are",
        "omitted -- the original drops them anyway (`drop if _merge == 2`), so",
        "the merge result is identical.",
        "",
        f"Values are sent as integers scaled by {PROX_SCALE:,} and divided back",
        "down, the same encoding the supply panel uses.",
        "",
        "Melitz, J. & Toubal, F. (2014), Journal of International Economics",
        "92(2), 351-363.",
    ]
    body = ["clear", "input str3 iso3_o double p1 double p2"]
    for _, r in table.iterrows():
        body.append(f'"{r.iso3_o}" {round(r.proxling * PROX_SCALE)} '
                    f'{round(r.proxling2 * PROX_SCALE)}')
    body += [
        "end",
        f"replace p1 = p1/{PROX_SCALE}",
        f"replace p2 = p2/{PROX_SCALE}",
        "rename p1 proxling",
        "rename p2 proxling2",
        "isid iso3_o",
        "count",
        "summarize proxling proxling2",
        "save $mydata/msuemer/clean_lingprox, replace",
        "display \"ling prox ok\"",
    ]
    return "\n".join(head("LINGUISTIC PROXIMITY", "984-1010", "(nothing)",
                          "clean_lingprox", notes) + body) + "\n"


def job_c3():
    notes = [
        "The proximity merge (orig :1002-1019) and the remaining personal",
        "confounders: education abroad, pre-migration work, pre-migration",
        "German, duration of stay, arrival with family, prior contacts,",
        "accommodation, health, trauma (orig :1022-1204).",
        "",
        "Send only after BOTH clean_citizenship_tc and clean_lingprox report saved.",
        "",
        "Deviations: keep/drop -> soepkeep/soepdrop; the foreach over the three",
        "pre-migration German items is unrolled, matching the Part A convention",
        "(macro substitution stays untested against the scanner and unrolling",
        "costs nothing analytically).",
    ]
    body = [
        "use $mydata/msuemer/clean_citizenship_tc, clear",
        "count",
        "xtset pid syear",
        "",
        "gen iso3_o = citizenship_iso_tc",
        "replace iso3_o = \"ALB\" if iso3_o == \"KOS\"",
        "replace iso3_o = \"ISR\" if iso3_o == \"PSE\"",
        "merge m:1 iso3_o using $mydata/msuemer/clean_lingprox",
        "soepdrop if _merge == 2",
        "tabulate citizenship_iso_tc if _merge == 1",
        "soepdrop _merge iso3_o",
        "",
        "replace proxling2 = proxling2 * 100",
        "gen ln_ling_proximity = ln(proxling2 + 1)",
        "lab var ln_ling_proximity \"ln of linguistic proximity to German\"",
        "rename proxling ling_proximity",
        "lab var ling_proximity \"linguistic proximity to German\"",
        "summarize ling_proximity ln_ling_proximity",
        "",
        "rename lb0228 eduasl",
        "clonevar years_sch0 = lb0187",
        "replace years_sch0 = 0 if lb0183 == 2",
        "recode years_sch0 .= 0 if lr3076 == 2",
        "label variable years_sch0 \"school: years of education abroad\"",
        "recode years_sch0 (-10/-1 = .)",
        "",
        "rename lm0076i01 voc1yr",
        "rename lm0076i08 voc1m",
        "rename lm0076i02 voc2yr",
        "rename lm0076i09 voc2m",
        "rename lm0076i03 voc3yr",
        "rename lm0076i10 voc3m",
        "rename lm0076i04 uni1yr",
        "rename lm0076i11 uni1m",
        "rename lm0076i05 uni2yr",
        "rename lm0076i12 uni2m",
        "rename lm0076i06 phd1yr",
        "rename lm0076i13 phd1m",
        "rename lm0076i07 voc4yr",
        "rename lm0076i14 voc4m",
        "",
        "recode voc1yr voc1m voc2yr voc2m voc3yr voc3m uni1yr uni1m ///",
        "    uni2yr uni2m phd1yr phd1m voc4m voc4yr (-5/-1 = .)",
        "",
        "gen temp1 = voc1yr + voc1m/12",
        "gen temp2 = voc2yr + voc2m/12",
        "gen temp3 = voc3yr + voc3m/12",
        "gen temp4 = voc4yr + voc4m/12",
        "gen temp5 = uni1yr + uni1m/12",
        "gen temp6 = uni2yr + uni2m/12",
        "gen temp7 = phd1yr + phd1m/12",
        "egen years_ausbhoch0 = rowtotal(temp1 temp2 temp3 temp4 temp5 ///",
        "    temp6 temp7), missing",
        "replace years_ausbhoch0 = 0 if eduasl == 2",
        "lab var years_ausbhoch0 \"voc/uni years of education abroad\"",
        "",
        "egen total_years_edu0 = rowtotal(years_sch0 years_ausbhoch0), missing",
        "lab var total_years_edu0 \"years of education before migration\"",
        "replace total_years_edu0 = . if years_sch0 >= .",
        "replace total_years_edu0 = . if years_ausbhoch0 >= .",
        "bysort pid (syear): carryforward total_years_edu0 years_sch0 ///",
        "    years_ausbhoch0, replace",
        "bysort pid (minusyear): carryforward total_years_edu0 years_sch0 ///",
        "    years_ausbhoch0, replace",
        "",
        "soepdrop temp1 temp2 temp3 temp4 temp5 temp6 temp7",
        "soepdrop voc1yr voc1m voc2yr voc2m voc3yr voc3m",
        "soepdrop uni1yr uni1m uni2yr uni2m phd1yr phd1m voc4m voc4yr",
        "",
        "recode pgpsbila pgpbbila eduasl (-5/-1 = .)",
        "bysort pid (syear): carryforward pgpsbila pgpbbila, replace",
        "replace pgpsbila = 0 if eduasl == 2",
        "xtsum total_years_edu0 years_sch0 years_ausbhoch0",
        "",
        "gen work0 = 1 if lr3034 > 0 & lr3034 < .",
        "recode work0 . = 0 if lb0248 == 1 | lr3032 == 1 | ///",
        "    lr3033_v1 == 1 | lr3033_v2 == 1 | lr3033_h == 1",
        "bysort pid (syear): carryforward work0, replace",
        "bysort pid (minusyear): carryforward work0, replace",
        "label variable work0 \"worked before arrival\"",
        "",
        "gen speak_german0 = lm0128i01",
        "replace speak_german0 = lb1231 if speak_german0 < 0 | speak_german0 >= .",
        "gen write_german0 = lm0128i02",
        "replace write_german0 = lb1232 if write_german0 < 0 | write_german0 >= .",
        "gen read_german0 = lm0128i03",
        "replace read_german0 = lb1233 if read_german0 < 0 | read_german0 >= .",
        "recode speak_german0 (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)",
        "lab val speak_german0 language",
        "recode write_german0 (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)",
        "lab val write_german0 language",
        "recode read_german0 (1=4) (2=3) (3=2) (4=1) (5=0) (-10/-1 = .)",
        "lab val read_german0 language",
        "gen german0_additive = speak_german0 + read_german0 + write_german0",
        "lab var german0_additive \"pre-migration german profficiency\"",
        "bysort pid (syear): carryforward german0_additive, replace",
        "bysort pid (minusyear): carryforward german0_additive, replace",
        "",
        "gen stay_duryr = intyear - arrival_yr",
        "replace stay_duryr = . if stay_duryr < 0",
        "lab var stay_duryr \"duration of stay in years\"",
        "gen stay_durm = intdate - arrival_date",
        "lab var stay_durm \"duration of stay in months\"",
        "summarize stay_duryr stay_durm",
        "",
        "gen arriv_fam = lr3133 == 1",
        "recode arriv_fam (. = 0) if lr3132 == 1",
        "recode arriv_fam (. = 0) if lr3134 == 1",
        "recode arriv_fam (. = 0) if lr3135 == 1",
        "bysort pid (syear): carryforward arriv_fam, replace",
        "bysort pid (minusyear): carryforward arriv_fam, replace",
        "lab var arriv_fam \"arrived with family\"",
        "",
        "recode lb1246 lb1247_v1 lb1247_v2 lb1247_v3 lb1247_v4 lb1248 ///",
        "    (-10/-1 = .)",
        "bysort pid (syear): carryforward lb1246 lb1247_v1 lb1247_v2 ///",
        "    lb1247_v3 lb1247_v4 lb1248, replace",
        "bysort pid (minusyear): carryforward lb1246 lb1247_v1 lb1247_v2 ///",
        "    lb1247_v3 lb1247_v4 lb1248, replace",
        "",
        "gen support0 = 1 if lb1246 == 1 | lb1247_v1 == 1 | ///",
        "    lb1247_v2 == 1 | lb1247_v3 == 1 | lb1247_v4 == 1",
        "recode support0 .= 0 if lb1248 == 1",
        "lab var support0 \"family/friends in Germany before arrival\"",
        "gen friends0 = 1 if lb1247_v1 == 1 | lb1247_v2 == 1 | ///",
        "    lb1247_v3 == 1 | lb1247_v4 == 1",
        "recode friends0 .= 0 if support0 == 1",
        "recode friends0 .= 0 if lb1248 == 1",
        "lab var friends0 \"pre-migration friends in Germany\"",
        "gen family0 = 1 if lb1246 == 1",
        "recode family0 .= 0 if support0 == 1",
        "recode family0 .= 0 if lb1247_v1 == 1 | lb1247_v2 == 1 | ///",
        "    lb1247_v3 == 1 | lb1247_v4 == 1",
        "recode family0 .= 0 if lb1248 == 1",
        "lab var family0 \"pre-migration family in Germany\"",
        "",
        "clonevar hwunt = hlj0005_h",
        "label def hwunt 1 \"shared accommodation\" ///",
        "    2 \"private accommodation\" 3 \"other\", replace",
        "gen priv_accom = hwunt == 2 if hwunt < .",
        "lab var priv_accom \"private accommodation (house/flat)\"",
        "",
        "mvdecode ple0008, mv(-1,-2,-3,-5,-6,-7,-9)",
        "gen healthy = 6 - ple0008",
        "lab def healthy 1 \"very bad\" 5 \"very good\"",
        "lab val healthy healthy",
        "lab var healthy \"self-rated health\"",
        "",
        "mvdecode lr3048, mv(-1,-2,-3,-5,-6,-7,-9)",
        "gen health0 = lr3048",
        "lab var health0 \"premigration health satisfacation\"",
        "",
        "mvdecode lr3122 lr3123 lr3124 lr3125 lr3126 lr3127 lr3128, ///",
        "    mv(-1,-2,-3,-5,-6,-7,-9)",
        "gen trauma_exp = 0 if lr3129 == 1",
        "replace trauma_exp = 1 if lr3122 == 1 | lr3123 == 1 | ///",
        "    lr3124 == 1 | lr3125 == 1 | lr3126 == 1 | lr3127 == 1 | ///",
        "    lr3128 == 1",
        "lab var trauma_exp \"traumatic experience\"",
        "bysort pid (syear): carryforward trauma_exp, replace",
        "bysort pid (minusyear): carryforward trauma_exp, replace",
        "tabulate trauma_exp, m",
        "",
        "count",
        "summarize total_years_edu0 work0 german0_additive priv_accom",
        "summarize healthy health0 trauma_exp support0",
        "describe, short",
        "save $mydata/msuemer/clean_confounders, replace",
        "display \"13C3 ok\"",
    ]
    return "\n".join(head("PART C3", "1002-1204", "clean_citizenship_tc + clean_lingprox",
                          "clean_confounders", notes) + body) + "\n"


def main():
    rules = parse_original()
    codes = observed_codes()
    print(f"{len(codes)} pgnation codes observed; "
          f"stage sizes {[len(v) for v in rules.values()]}")

    keep = set()
    for c, lab, _ in codes:
        _, iso, num = resolve(c, lab, rules)
        if num:
            keep.add(iso)
    keep = {("ALB" if i == "KOS" else "ISR" if i == "PSE" else i) for i in keep}
    keep.add("ISR")
    table = proximity_table(keep)
    print(f"{len(table)} proximity rows kept of 212")

    total = 0
    total += write(STATA_REMOTE / "clean_citizenship.do", job_c1(rules, codes))
    total += write(STATA_REMOTE / "clean_citizenship_tc.do", job_c2(rules, codes))
    total += write(STATA_REMOTE / "clean_lingprox.do", job_prox(table))
    total += write(STATA_REMOTE / "clean_confounders.do", job_c3())
    print(f"\n{total} send lines across 4 jobs; all clean, all lines <= 72 chars")


if __name__ == "__main__":
    main()
