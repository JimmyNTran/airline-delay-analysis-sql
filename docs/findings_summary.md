# Airline Operational Performance — Findings Summary

**Scope:** 12 months of 2025 BTS Marketing Carrier On-Time Performance data: 7,736,770 flights across 10 carriers.

**Data validation:** before any analysis, the data was checked for completeness and accuracy. All 12 months loaded exactly once with dates in range, no duplicate flights were found, monthly and carrier totals reconcile to 7,736,770, and December matches the source file's expected count (644,987). The checks and their results are recorded in [`05_kpi_analysis.sql`](../sql/05_kpi_analysis.sql).

## 1. What is the #1 cause of flight delays?

Late Aircraft (38.9% of delayed flights) and Carrier-caused delays (29.4%) are the top primary causes. Together they account for about two-thirds (68.3%) of the 1,685,334 delayed flights and about 74% of total minutes lost system-wide (91.7M of 124.7M delay-minutes). Weather has the highest average severity per incident (119.9 minutes, versus 51–80 minutes for other causes), but it is rare: 4.1% of delayed flights and about 7% of total minutes lost.

| Primary cause | % of delayed flights | Avg. delay (min) | Total minutes lost | % of minutes |
| --- | ---: | ---: | ---: | ---: |
| Late Aircraft | 38.9% | 80.4 | 52,768,128 | 42.3% |
| Carrier | 29.4% | 78.7 | 38,969,514 | 31.3% |
| Air Traffic System (NAS) | 27.4% | 53.0 | 24,477,024 | 19.6% |
| Weather | 4.1% | 119.9 | 8,333,762 | 6.7% |
| Security | 0.2% | 51.1 | 147,553 | 0.1% |

**Method note:** each delayed flight is assigned to its single largest cause. A cross-check that instead splits every flight's minutes across all contributing causes gives the same picture: Late Aircraft + Carrier 71.8%, Weather 6.5%.

**Recommendation:** Operational improvements — turnaround time, scheduling buffer, aircraft and crew readiness — will move the needle far more than weather-resilience investment, since most lost time is within the airline's own control.

## 2. Which carriers actually perform best, once fairly compared?

A naive on-time ranking can mislead: carriers with many uncontested routes look strong or weak depending on route difficulty rather than operational skill. Allegiant, for example, flies 89.6% of its network on routes with no direct competitor. Restricting the comparison to routes flown by 2 or more carriers:

| Carrier | Naive on-time % | Naive rank | Shared-route on-time % | Shared rank |
| --- | ---: | ---: | ---: | ---: |
| Hawaiian (HA) | 82.7% | 1 | 82.7% | 1 |
| Delta (DL) | 80.6% | 2 | 79.7% | 2 |
| Southwest (WN) | 78.6% | 3 | 77.8% | 5 |
| Spirit (NK) | 78.6% | 4 | 78.5% | 3 |
| Alaska (AS) | 78.5% | 5 | 77.0% | 6 |
| United (UA) | 78.2% | 6 | 78.1% | 4 |
| American (AA) | 75.5% | 7 | 74.5% | 8 |
| Allegiant (G4) | 75.0% | 8 | 76.2% | 7 |
| JetBlue (B6) | 73.8% | 9 | 73.5% | 9 |
| Frontier (F9) | 72.1% | 10 | 72.0% | 10 |

- **Frontier** is last in both rankings, so its poor performance can't be explained by harder routes.
- **United** moved from 6th to 4th, but not because its own rate improved (78.2% to 78.1%; it runs 78.3% on exclusive routes and 78.1% on shared ones). It moved up because **Southwest** (78.6% to 77.8%) and **Alaska** (78.5% to 77.0%) performed worse on contested routes, so their naive rankings were partly boosted by exclusive routes. Ranks 3–6 sit within 0.4 points of each other, so this is a small shift in a tight group.
- **Allegiant** is hard to benchmark: only about 13,500 of its flights go head-to-head with another carrier.

### 2b. Which carriers drive the Late Aircraft problem?

Raw counts favor large carriers by volume (American: 202,329 Late Aircraft delays). Adjusted for each carrier's own flight volume, the ranking reshuffles: two of the smallest carriers, Frontier and Allegiant, have the worst rates. American and Southwest lead on raw counts and stay in the worst four, while United and Delta fall into the better half and Spirit has the lowest rate.

| Carrier | Total flights | Late Aircraft delays | Late Aircraft rate |
| --- | ---: | ---: | ---: |
| Frontier (F9) | 198,065 | 24,844 | 12.54% |
| Allegiant (G4) | 130,899 | 14,786 | 11.30% |
| Southwest (WN) | 1,391,885 | 149,302 | 10.73% |
| American (AA) | 1,992,906 | 202,329 | 10.15% |
| JetBlue (B6) | 231,413 | 21,671 | 9.36% |
| Alaska (AS) | 422,375 | 37,516 | 8.88% |
| United (UA) | 1,467,730 | 97,157 | 6.62% |
| Hawaiian (HA) | 80,084 | 4,987 | 6.23% |
| Delta (DL) | 1,626,898 | 94,068 | 5.78% |
| Spirit (NK) | 194,515 | 9,721 | 5.00% |

### 2c. Why do Frontier and Allegiant have the worst Late Aircraft rates?

**Hypothesis 1, tighter fleet utilization: not supported.** Flights per aircraft was measured on each airline's own operated flights, because this dataset files flights under the marketing carrier, which mixes regional partners' aircraft into the legacy carriers' counts. There is no consistent link: Southwest (1st) and Frontier (3rd) work their fleets hard and have high rates, but Hawaiian (2nd) and Spirit (4th) work theirs just as hard with the two lowest rates, and Allegiant (8th) has the 2nd-worst rate while using its planes less than most.

**Hypothesis 2, seasonality: partly supported.** Both carriers' Late Aircraft rates peak in June–July (Frontier 17.4% and 15.9%; Allegiant 14.5% and 13.9%) and bottom out in September (8.7% and 7.2%). Weather delays rise in the same summer months for both. Frontier's taxi times also peak in June–July, a second independent signal; Allegiant's taxi times peak in winter instead, so ground congestion doesn't explain its summer spike. Taxi-time swings are modest for both (2–3 minutes across the year).

**December breaks the pattern.** Late Aircraft rates climb again (Frontier 14.7%; Allegiant 14.7%, its highest month), but weather delays don't (low for Frontier, mid-year for Allegiant). A likely reason: BTS attributes "Weather" only to the first delayed flight in a chain, and later flights that inherit the delay are labeled "Late Aircraft," which hides the root cause downstream. Weather-coded delays are also small (0.2–3.5% of flights) next to Late Aircraft (7–17%), so the two move together; this doesn't prove weather causes them.

**Recommendation:** Frontier and Allegiant would benefit most from added schedule buffer in June–July and December.

## 3. Where do delays concentrate?

Route length is not the driver: the 15 worst routes range from 79 to 232 scheduled minutes. Aspen appears in 4 of them and Dallas-Fort Worth in 5 (DFW is also American's top weather-cancellation airport; see Section 4). Among the 15 worst airports, three clusters stand out.

**Cluster 1 — Mountain-resort airports.** Aspen (ASE, 3rd-worst airport) and Eagle-Vail (EGE, 5th) are served mainly by United, American and Delta. Weather causes about 3.6x its system-wide share of delays there, and those delays run longer. But Carrier-caused delays are still the most common cause, at a higher share than system-wide, so weather adds risk on top of operational issues rather than replacing them.

| Metric | System-wide | ASE / EGE flights |
| --- | ---: | ---: |
| Weather share of delayed flights | 4.1% | 14.7% |
| Avg. weather delay (min) | 119.9 | 127.3 |
| Carrier share of delayed flights (#1 cause at ASE/EGE) | 29.4% | 36.2% |

**Cluster 2 — Allegiant's leisure airports.** Concord, NC (USA) is the single worst airport (56.8% on-time), followed by Sanford (SFB, 2nd-worst), St. Pete-Clearwater (PIE, 7th) and Rickenbacker (LCK, 15th). Every departure at all four is Allegiant, compounding the carrier's own Late Aircraft problem from Section 2b.

**Cluster 3 — Small United-marketed regional airports.** Sioux City (SUX), Hancock (CMX), Salina (SLN), Cody (COD) and Dickinson (DIK) are served only by United-branded flights, about 700–970 departures each, likely flown by United's regional partners. Their volumes are small, so these rates swing more from chance.

**Recommendation:** The clusters need different fixes: weather contingency and de-icing capacity at mountain airports, alongside the carriers' own operations there; scheduling changes specific to Allegiant's leisure-airport network; and a closer look at United's small regional service.

## 4. Cancellation patterns

| Carrier | Total flights | Cancelled | Cancellation % |
| --- | ---: | ---: | ---: |
| American (AA) | 1,992,906 | 47,125 | 2.36% |
| Frontier (F9) | 198,065 | 3,508 | 1.77% |
| JetBlue (B6) | 231,413 | 3,825 | 1.65% |
| Spirit (NK) | 194,515 | 2,927 | 1.50% |
| Delta (DL) | 1,626,898 | 22,207 | 1.36% |
| United (UA) | 1,467,730 | 19,999 | 1.36% |
| Alaska (AS) | 422,375 | 5,503 | 1.30% |
| Southwest (WN) | 1,391,885 | 11,799 | 0.85% |
| Hawaiian (HA) | 80,084 | 660 | 0.82% |
| Allegiant (G4) | 130,899 | 615 | 0.47% |

American has the highest cancellation rate: about 1.3x the next carrier (Frontier) and 1.7x Delta and United. Allegiant, with the second-worst Late Aircraft rate, has the lowest cancellation rate of all 10 carriers. That suggests a possible behavioral difference: a carrier under margin pressure may prefer to delay and still fly rather than absorb a cancellation and refund.

| Carrier | Reason | Cancelled flights | % of carrier's cancellations |
| --- | --- | ---: | ---: |
| American | Weather | 35,319 | 74.9% |
| American | Air Traffic System (NAS) | 7,254 | 15.4% |
| American | Carrier | 4,515 | 9.6% |
| American | Security | 37 | 0.1% |
| Allegiant | Weather | 361 | 58.7% |
| Allegiant | Carrier | 147 | 23.9% |
| Allegiant | Air Traffic System (NAS) | 107 | 17.4% |

Weather causes only 4.1% of delayed flights but dominates outright cancellations: 74.9% for American and 58.7% for Allegiant. Airlines appear to cancel proactively once weather severity crosses a threshold.

**American's weather cancellations by origin airport**

| Airport | Weather cancellations | % of AA's weather cancellations |
| --- | ---: | ---: |
| DFW | 6,767 | 19.2% |
| CLT | 2,988 | 8.5% |
| DCA | 2,828 | 8.0% |
| ORD | 2,317 | 6.6% |
| PHL | 1,558 | 4.4% |

DFW alone accounts for 19.2% of American's weather cancellations, about 2.3x the next airport, and the top five airports together account for 46.6%. By month, the pattern across American's network has two peaks: January (17.4%) and July (16.5%) are the highest, December is comparatively low (4.9%), and September–October are lowest (under 2%). DFW itself follows a different shape: one sharp January peak (1,369 cancellations, about 20% of its year, consistent with ice storms) plus a long March–August storm season (624–797 per month, 62% of the year combined), with September, December and February quiet. DFW does not peak in July, so American's network-wide July peak comes partly from other airports.

**Recommendation:** American's high cancellation rate is concentrated and addressable: weather-contingency planning at DFW, covering January ice and the March–August storm season, and at its other top-five airports would target nearly half of its weather cancellations.

## Overall

Delays are driven mostly by factors within the airlines' own control: Late Aircraft and Carrier causes account for about 74% of delay-minutes, while weather accounts for about 7%, except in specific pockets (mountain airports, summer months) where weather adds real risk. Cancellations flip this pattern: weather causes 4.1% of delayed flights but about 75% of American's and 59% of Allegiant's cancellations. The clearest targets are Frontier and Allegiant schedule buffer in June–July and December, Allegiant's leisure-airport network, and American's weather planning at DFW (January ice and the March–August storm season) and its other top cancellation airports.
