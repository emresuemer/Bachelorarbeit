# Lokales Sprachkursangebot und die Arbeitsmarktintegration Geflüchteter: Replikation und Erweiterung

**Mehmet Emre Sümer**  
Otto-Friedrich-Universität Bamberg  
Bachelorarbeit im Studiengang Soziologie, Sommersemester 2026

Dieses Repository ist die vollständige computergestützte Dokumentation von zwei Zielen:

1. **Eine Replikation** von Kanas, A., & Kosyakova, Y. (2022), *Greater local supply of
   language courses improves refugees' labor market integration*, European Societies,
   doi:[10.1080/14616696.2022.2096915](https://doi.org/10.1080/14616696.2022.2096915).
   Alle fünf Tabellen des Haupttexts und beide Abbildungen werden reproduziert. Die zentrale
   Schätzung, der Effekt des Integrationskursangebots im Landkreis auf die Erwerbstätigkeit,
   beträgt **2,98\* (1,19)** Prozentpunkte pro SD gegenüber 2,97\* (1,19) im Paper, auf
   einer Analysestichprobe von **5.467 Personenjahren / 2.730 Personen**, die der
   veröffentlichten an jedem Schritt des Auswahltrichters exakt entspricht.
2. **Eine Erweiterung**: Moderiert der *Asylstatus* den Zugang Geflüchteter zum Treatment?
   Geprüft wird das an den Mediatoren des Papers statt an der Erwerbstätigkeit. Jeder
   gemeinsame Test ist null (am nächsten dran: Kursteilnahme, p = 0,053); die
   Punktschätzungen ordnen sich mit der rechtlichen Berechtigung in der vorhergesagten
   Richtung, und das Design hatte zu wenig Power, um dies zu klären.

Nebenbei hat die Replikation **vier Fehler im veröffentlichten Paper** aufgedeckt (§5).

---

## 1. Daten und Zugang

| Quelle | Wo | Anmerkungen |
|---|---|---|
| IAB-BAMF-SOEP-Befragung von Geflüchteten, SOEP-Core **v36** | `data/` (gitignored) | EU Edition, herunterladbar. **Jeder geografische Identifikator unterhalb der Bundesländer ist dateiweit auf `-7` gesetzt**, sodass das Treatment auf Landkreisebene daraus nicht gebaut werden kann. |
| SOEP-Core v36 **Remote Edition** (doi:10.5684/soep.core.v36r) | DIW Berlin, über **SOEPremote** | Ungeschwärzte `kkz`. Kein Download: Man schickt Stata-Code als Klartext per E-Mail an `soep-exec@diw.de`, das DIW führt ihn aus, und zurück kommt ein Text-Listing, nie ein Datensatz. |
| Replikationspaket der Autorinnen (Code + ergänzende Makrodaten) | **OSF: https://doi.org/10.17605/OSF.IO/XZ3V5** | Nicht in diesem Repo. Meine einzigen Änderungen daran sind `src/analyses/authors_package_fixes.diff`. |
| Melitz & Toubal (2014), linguistische Nähe | [CEPII](https://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=19) | wird vom Paket benötigt, ist aber nicht darin enthalten |


Aufgrund der Lizenz- und Datenvereinbarungen sind in diesem Repository keine Daten enthalten. Um die Ergebnisse zu reproduzieren, beschaffen Sie sich bitte Zugang zu diesen Daten und legen Sie lokale Kopien unter `data/` ab.

- Das lokale SOEP-Core v36 enthält keine Regionalvariablen (Details im [SOEPcompanion](https://companion.soep.de/Data%20Structure%20of%20SOEPcore/Editions.html)). Einige Teile der Vorverarbeitung brauchten jedoch die lokalen SOEP-Daten, der Rest des Codes lief auf den SOEP-Remote-Servern.

- Der gesamte SOEPremote-Code unter `./src/stata/remote` wurde auf den Servern des DIW ausgeführt. Diese Dateien wurden an die Einschränkungen von SOEPremote angepasst: Es verbietet eine Reihe von Befehlen (`keep`/`drop`/`log`/`list`/`do`/`ssc`/…, auch innerhalb eines Kommentars oder Strings), akzeptiert keine Anhänge (externe Daten gelangen nur über inline `input … end`-Blöcke hinein) und schneidet Jobs ab, die länger als etwa 200 bis 250 Zeilen sind.
- Der Header-Kommentar jeder Do-Datei nennt die zugehörige(n) Datei(en) in der Originalimplementierung der Autorinnen.


## 2. Dateistruktur

```
src/stata/remote/      25 SOEPremote-Jobs, die jedes Ergebnis erzeugt haben, plus
                       verify_server_state.do (Diagnose des Serverbestands, ohne Listing)
src/stata/local/       Abbildung 1 (fig01_course_supply.do) und zwei lokale Diagnosen
                       (verify_geo_redaction.do, descriptives_nogeo.do)
src/analyses/          was vom Paket der Autorinnen übrig ist: mein Patch dazu, die 22
                       Jobs, die das Landkreis-Panel auf den Server gebracht haben, die Tools
results/transcripts/   die 25 Antwort-E-Mails des DIW, wortgetreu (*.eml).
```


## 3. Replikationsstudie

### Einen Job senden

Jeder Remote-Job ist eine `.do`-Datei mit einem Dokumentationsheader oberhalb der Zeile
`SEND FROM HERE DOWN` und dem eigentlichen Job darunter. Dieselben vier Header-Zeilen für jeden Job:


```text
* user = ...
* password = ...
* package = STATA
* project = GSOEP

# Die jeweilige Do-Datei, die an den DIW-Server gesendet wird
```

Die Antworten sind als `results/transcripts/src_stata_remote_<job>.do.eml` gespeichert. Der Server führt aus, was auch immer als Text ankommt, und gibt `end of do-file` aus, selbst wenn die Mail
abgeschnitten wurde; ein Laufzeitfehler (`r(601)` fehlende Datei) stoppt die Ausführung **nicht**. Deshalb habe ich jede Antwort-E-Mail geprüft, um sicherzustellen, dass der Code vollständig und korrekt gelaufen ist.


### Vorverarbeitung: das Landkreis-Jahr-Panel (lokal, Stata/BE 18)

Sie brauchen das OSF-Paket der Autorinnen in `src/analyses/`, die heruntergeladenen CEPII-Dateien in
`src/analyses/macro_orig/Melitz_Toubal_proxling/` sowie `ssc install carryforward
cleanplots iscogen missings estout fre egenmore shp2dta mif2dta spmap`.

```stata
cd src/analyses
* git apply src/analyses/authors_package_fixes.diff   (vom Repo-Root aus, einmalig)
do 00011_data_macro.do        // -> savedata/macro_data.dta, 2.807 Landkreis-Jahre
```

Log des Laufs, der meine Version erzeugt hat: `results/logs/00011_data_macro_date20260803.log`.

### Datentransfer: das Panel auf den Server bringen

`macro_data.dta` wird von den Vorverarbeitungs-Do-Dateien der Autorinnen erzeugt, und ich musste es auf den DIW-Server übertragen. Der einzige Weg war, es in Blöcke von 190 bis 200 Zeilen aufzuteilen, die Werte als Integer zu kodieren und sie über `input`-Blöcke zu senden.

Die Python-Skripte `make_supply_jobs.py` und `verify_payload.py` erzeugen diese Jobs und prüfen, dass der Roundtrip exakt ist.

| Senden | Jobs | Prüfung |
|---|---|---|
| zusammen | `10_supply_part1..18.do`, `12_soepvars_remote.do` | jeder gibt einen `count` und eine Prüfsumme aus; mit `src/analyses/remote/jobs/EXPECTED.txt` vergleichen |
| danach | `11_supply_stack.do` | **`tabulate year` zeigt 401 in allen sieben Jahren** (ein verlorener Teil bleibt sonst unsichtbar) |
| danach | `13_supply_assemble.do` → `14_supply_check.do` | `cty_supply.dta`, 2.807 × 16, `isid kkz year` |

`12_soepvars_remote.do` baut zwei Landkreisvariablen, die SOEP-Mikrodaten brauchen
(`concern_immigration`, `volunt`) und lokal nicht erstellt werden können.

### Replikationsaufgaben

Jeder Job liest den Datensatz des vorherigen Jobs aus `$mydata`. Erwartete Form und der
Abschlussmarker, nach dem im Listing zu suchen ist:

| # | Job | Speichert | N × K | Marker |
|---|---|---|---|---|
| 1 | `merge_soep.do` | `soep_merged` | 18.342 × 206 | nur `.dta saved` |
| 2 | `clean_outcomes.do` | `clean_outcomes` | 18.342 × 235 | nur `.dta saved` |
| 3 | `clean_geography.do` | `clean_geography` | 18.342 × 252 | `kkz1st` gültig für **16.186** |
| 4 | `clean_county_merge.do` | `clean_county` | 18.342 × 266 | `13B ok`; `init_course_opport` nicht fehlend bei **14.505**, Within-Person-SD 0 |
| 5 | `clean_citizenship.do` | `clean_citizenship` | 18.342 × 275 | `13C1 ok`; `iso_num_o == 0` listet **nur** die Codes 98, −1, −2, 999, 149, 172 |
| 6 | `clean_citizenship_tc.do` | `clean_citizenship_tc` | 18.342 × 278 | `13C2 ok` |
|   | `clean_lingprox.do` (jederzeit vor 7) | `clean_lingprox` | 60 × 3 | `ling prox ok` |
| 7 | `clean_confounders.do` | `clean_confounders` | 18.342 × 286 | `13C3 ok` |
| 8 | `clean_asylum.do` | `clean_asylum` | 18.342 × 298 | `13D ok`; `diff_kkz` 9.311 / 6.875 / 2.156 |
| 9 | `clean_sample.do` | `sample_full`, **`sample_analytic`** | 18.342 × 86, **5.467 × 81** | `13E ok`; **Tabelle 1 des Papers**, alle 11 Zeilen des Auswahltrichters |



### Imputation und die Ergebnisdarstellungen

| Job | Liest | Erzeugt | Marker |
|---|---|---|---|
| `impute_sample.do` | `sample_analytic` | `sample_imputed` (M = 20) | `14A ok` |
| `descriptives_micro.do` | `sample_imputed` | **Tabelle 2** | `22 ok` |
| `tab03_employment.do` | `sample_imputed` | **Tabelle 3** | `23A ok` |
| `tab04_intermediate_outcomes.do` | `sample_imputed` | **Tabelle 4** | `23D ok` |
| `tab05_mediation.do` | `sample_imputed` | **Tabelle 5** | `23C ok` |
| `fig02_proficiency.do`, `fig02_course_completion.do`, `fig02_certificate.do` | `sample_imputed` | **Abbildung 2**, je ein Panel | `23E1/2/3 ok` |

`impute_sample` zuerst; die übrigen sind unabhängig und können zusammen gesendet werden. `tab04`,
`tab05` und die drei `fig02_*` werden von `make_23_jobs.py` aus der Vorlage
`tab03_employment.do` erzeugt. Abbildungen können SOEPremote nicht verlassen; die `fig02_*`-Jobs
liefern die Margins-Tabelle zurück, und die Panels werden lokal gezeichnet.


## 4. Erweiterungsstudie


| Job | Liest | Frage | Marker | Transkript |
|---|---|---|---|---|
| `ext_asylum_moderator.do` | `sample_analytic` | E0: Ist `asyl_req_stat` als Moderator brauchbar? | `EXT ASYL END` | 244779 |
| `impute_sample_part.do` | `sample_analytic` | Voraussetzung: Variante mit imputiertem `int_course_part` | `14B ok` | 244834 |
| `ext_asyl_employment.do` | `sample_imputed` | E1: Angebot × Status auf Erwerbstätigkeit (= Tabelle S6, Modell 1.1.9 des Papers) | `EXT E1 ok` | 244835 |
| `ext_asyl_mediators_primary.do` | `sample_imputed` | E2: Sprachkenntnisse, Kursabschluss | `EXT E2 primary ok` | 244836 |
| `ext_asyl_mediators_secondary.do` | `sample_imputed` | E2: Zertifikat, Kontakt (Placebo) | `EXT E2 secondary ok` | 244837 |
| `ext_asyl_participation.do` | `sample_imputed_part` | E2: Kursteilnahme, der schärfste Test | `EXT E2 participation ok` | 244840 |
| `ext_asyl_threeway.do` | `sample_imputed` | E4: explorative Dreifachinteraktion mit Aufenthaltsdauer | `EXT E4 ok` | 244839 |

`impute_sample_part` vor `ext_asyl_participation` senden; alles andere zusammen.

## 5. Genauigkeit der Replikation und Abweichungen vom Paper

| Referenz | Ergebnis |
|---|---|
| Tabelle 1 | alle 11 Zeilen des Auswahltrichters stimmen überein, Personen und Personenjahre |
| Tabelle 2 | alle 102 veröffentlichten Zellen stimmen auf 2 Nachkommastellen überein; α = 0,937  |
| Tabelle 3 | 2,98\* (1,19) vs. 2,97\* (1,19); alle 37 Sterne stimmen überein  |
| Tabelle 4 | alle vier Panels; ein Sternwechsel bei 26 Zellen (p 0,047 vs. 0,061) |
| Tabelle 5 | innerhalb von 0,02 Prozentpunkten in allen sechs Modellen; die fiskalische Zahl von 1,5 Mio. € wird reproduziert  |
| Abbildung 1 | 401 Landkreise; Klassifikation identisch mit den Klassengrenzen des Papers  |
| Abbildung 2 | größte Abweichung von Tabelle S12: 0,006 Skalenpunkte (A), 0,29 Prozentpunkte (B), 0,10 Prozentpunkte (C); Signifikanzmuster identisch  |


Die folgenden Punkte weichen vom Paper ab:

1. **Die Zeilen zum Asylstatus sind in den Tabellen 2–5 falsch beschriftet.** Die Modelle
   verwenden `ib1.asyl_req_stat` mit 1 = keine Entscheidung, die Referenzkategorie ist also
   *keine Entscheidung* und nicht „anerkannt", wie gedruckt; die drei Koeffizienten sind um
   eine Beschriftung verschoben. Die korrekte Lesart kehrt die Interpretation des Papers um:
   Sowohl anerkannte als auch abgelehnte Geflüchtete sind mit höherer Wahrscheinlichkeit
   erwerbstätig als jene, die noch auf eine Entscheidung warten. Die Schätzungen selbst sind
   nicht betroffen.
2. **„165 Landkreise, davon 73"** (S. 11) stammt aus einem `recode`, dessen letzte Regel
   `(min/50 = 5)` Landkreise mit ≤ 50 % Wachstum in die Klasse 200–300 % einsortiert.
   Korrekte Zahlen: **142, davon 41**. Abbildung 1 ist nicht betroffen (aus der stetigen
   Variable gezeichnet).
3. **Tabelle 4, Panel A** lässt die eigene Haupteffektzeile aus (bei mir: 0,23\* (0,12),
   p = 0,050), mit der der Text argumentiert; Panel B druckt SE `.30` statt 1.30; in den
   Panels C und D sind die Einheitenüberschriften vertauscht.
4. **Tabelle S6** berichtet N = 5.473 / 2.732 für Modelle auf der Stichprobe, die jede andere
   Tabelle mit 5.467 / 2.730 angibt; mein E1-Job reproduziert Modell 1.1.9 auf 0,02
   Prozentpunkte genau mit 5.467.


## 6. Environment

- Lokal: Stata/BE 18.

- Remote: SOEPremote, Stata MP 19.5, alle benötigten Ado-Pakete
(`carryforward`, `egenmore`, `estout`, `mimrgns`, `iscogen`, `missings`, `fre`, `unique`) sind auf dem DIW-Server nachweislich installiert.

- Python 3 mit `pandas` und `matplotlib`, verwendet, um die integer-kodierten `input`-Blöcke für den DIW-Server zu erzeugen und die Abbildungen und Tabellen aus den Antwort-E-Mails des DIW zu bauen.


## Zitation

Sümer, M. E. (2026). *Lokales Sprachkursangebot und die Arbeitsmarktintegration
Geflüchteter: Replikation und Erweiterung der Untersuchung von Kanas und Kosyakova.*
Bachelorarbeit, Otto-Friedrich-Universität Bamberg, Studiengang Soziologie.  
Code und Materialien: https://github.com/emresuemer/Bachelorarbeit
