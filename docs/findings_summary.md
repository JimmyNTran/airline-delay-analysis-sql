# Airline Operational Performance — Findings Summary

**Scope:** 12 months of 2025 BTS Marketing Carrier On-Time Performance data across 10 carriers.

## 1. What is the #1 cause of flight delays?

Late Aircraft delays (38.9% of delayed flights) and Carrier-caused delays (29.4%) together account for 68.3% of delayed flights and, more importantly, about 74% of total minutes lost system-wide (91.7M of 124.7M delay-minutes). Weather has the highest average severity per incident (119.9 minutes, versus 50–80 minutes for other causes), but it is rare: 4.1% of delayed flights and about 7% of total minutes lost.

| Primary cause | % of delayed flights | Avg. delay (min) | Total minutes lost |
| --- | ---: | ---: | ---: |
| Late Aircraft | 38.9% | 80.4 | 52,768,128 |
| Carrier | 29.4% | 78.7 | 38,969,514 |
| Air Traffic System (NAS) | 27.4% | 53.0 | 24,477,024 |
| Weather | 4.1% | 119.9 | 8,333,762 |
| Security | 0.2% | 51.1 | 147,553 |

**Recommendation:** Operational improvements — turnaround time, scheduling buffer, aircraft and crew readiness — will move the needle far more than weather-resilience investment, since most lost time is within the airline's own control.

## 2. Which carriers actually perform best, once fairly compared?

A naive on-time ranking is misleading: carriers with many uncontested routes look strong or weak depending on route difficulty rather than operational skill. Allegiant, for example, flies roughly 90% of its network with zero direct competitors. Restricting the comparison to routes flown head-to-head by 2 or more carriers changes the picture:

- **Frontier** stayed last in both the naive and fairness-adjusted rankings, so its poor performance can't be explained by harder routes.
- **United** moved from 6th to 4th once uncontested routes were excluded; its naive ranking was partly dragged down by flying more competitive, congested routes.
- **Allegiant's** on-time metric is close to unusable for competitive benchmarking: there is too little head-to-head overlap to draw a fair conclusion.

### 2b. Which carriers drive the Late Aircraft problem specifically?

Raw counts favor large carriers by volume (American: ~202K Late Aircraft delays). Adjusted for each carrier's own flight volume, the ranking reverses: Frontier (12.54%) and Allegiant (11.30%) have the worst Late Aircraft rates, while Delta (5.78%) and United (6.62%) have the best.

A "tighter fleet utilization" hypothesis was tested and ruled out: Southwest works its fleet hardest of all 10 carriers yet does not have the worst rate. A seasonal investigation found real support instead: weather and ground congestion (taxi time) both spike in June/July and again in December, tracking Frontier's and Allegiant's Late Aircraft peaks. December's spike is only partly explained by same-flight weather data, likely because BTS attributes "Weather" only to the first delayed flight in a chain; later flights inheriting that delay are labeled "Late Aircraft."

**Recommendation:** Frontier and Allegiant would benefit most from added schedule buffer in June/July and December, when weather and holiday-volume congestion compound.

## 3. Where do delays concentrate?

The worst-performing airports split into two distinct clusters.

**Cluster 1 — Mountain-resort airports.** Aspen (ASE) and Eagle-Vail (EGE) are served mainly by United, American and Delta. Weather-attributed delays there run about 3.6x the system-wide rate and are more severe.

| Metric | System-wide | ASE / EGE flights |
| --- | ---: | ---: |
| Weather share of delays | 4.1% | 14.7% |
| Avg. weather delay (min) | 119.9 | 127.3 |

**Cluster 2 — Allegiant's secondary leisure airports.** Sanford (SFB), St. Pete-Clearwater (PIE) and Rickenbacker (LCK) are served almost entirely by Allegiant: minimal ground infrastructure compounds the carrier's tight scheduling.

Route length is not the driver: the 15 worst routes range from 79 to 232 scheduled minutes.

**Recommendation:** De-icing and weather-contingency investment for mountain airports; scheduling changes for Allegiant's secondary-airport network.

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

American has the highest cancellation rate. Allegiant, one of the worst performers on Late Aircraft delays, has the lowest, suggesting a carrier under margin pressure may prefer to delay and still fly rather than absorb a full cancellation and refund.

| Carrier | Reason | Cancelled flights | % of carrier's cancellations |
| --- | --- | ---: | ---: |
| American | Weather | 35,319 | 74.9% |
| American | Air Traffic System (NAS) | 7,254 | 15.4% |
| American | Carrier | 4,515 | 9.6% |
| American | Security | 37 | 0.1% |
| Allegiant | Weather | 361 | 58.7% |
| Allegiant | Carrier | 147 | 23.9% |
| Allegiant | Air Traffic System (NAS) | 107 | 17.4% |

Weather causes only 4.1% of delays but dominates outright cancellations. Airlines appear to cancel proactively once weather severity crosses a threshold.

**American's weather cancellations by origin airport**

| Airport | Weather cancellations | % of AA's weather cancellations |
| --- | ---: | ---: |
| DFW | 6,767 | 19.2% |
| CLT | 2,988 | 8.5% |
| DCA | 2,828 | 8.0% |
| ORD | 2,317 | 6.6% |
| PHL | 1,558 | 4.4% |

By month the pattern is bimodal: January (17.4%) and July (16.5%) are the two highest, while December is low (4.9%), consistent with DFW's winter ice storms and summer thunderstorms.

**Recommendation:** American's high cancellation rate is concentrated and addressable: weather-contingency planning at DFW covering both seasons would reduce a disproportionate share of its cancellations.

## Overall

Delays are driven mostly by factors within the airline's control — turnaround scheduling and buffer time — except in specific pockets (mountain airports, peak season) where weather's impact is real. Cancellations flip this pattern: weather causes 4.1% of delays but about 75% of American's and 59% of Allegiant's cancellations. The clearest targets are Frontier and Allegiant schedule buffer in June–July and December, Allegiant's secondary-airport network, and American's weather planning at DFW.
