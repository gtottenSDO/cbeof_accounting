# QWI age detail: Accounting & Payroll Services (NAICS 5412), Colorado

Pulled Nov 2, 2026. Source: Census Quarterly Workforce Indicators (QWI) API, state 08, private ownership (A05), not seasonally adjusted.

Note: QWI industry detail stops at 4-digit NAICS, so these figures cover accounting and payroll combined. `R/qwi_age_extract.R` rebuilds the underlying data.

## Employment by detailed age, 2023 vs 2025

Average of beginning-of-quarter counts.

| Age | 5412, 2023 | 5412, 2025 | 5412 change | All industries change |
|---|---|---|---|---|
| 19–21 | 333 | 276 | −17.3% | +1.3% |
| 22–24 | 1,352 | 1,085 | −19.7% | +1.3% |
| 25–34 | 7,167 | 6,520 | −9.0% | −0.4% |
| 35–44 | 5,347 | 5,569 | +4.2% | +3.8% |
| 45–54 | 4,338 | 4,252 | −2.0% | +2.7% |
| 55–64 | 3,555 | 3,468 | −2.4% | +0.5% |
| 65+ | 2,304 | 2,298 | −0.3% | +8.4% |
| **Total** | **24,530** | **23,604** | **−3.8%** | **+1.6%** |

- Workers 19–34 fell by about 970 jobs, more than the industry's entire net loss of about 930.
- Employment of workers 55+ was essentially flat.

## Trend in young workers (5412)

**Ages 22–24, average employment:**
- 762 (2015)
- 1,046 (2019)
- 1,318 (2022)
- 1,352 (2023, peak)
- 1,239 (2024)
- 1,085 (2025)

**Ages 25–34, average employment:**
- 4,486 (2015)
- 5,300 (2019)
- 6,821 (2022)
- 7,167 (2023, peak)
- 6,946 (2024)
- 6,520 (2025)

**New hires aged 22–24 (excludes recalls):**
- 5412: 1,514 (2022) to 1,029 (2025), down 32%.
- All industries: 181,292 to 142,757, down 21%.

**New hires aged 25–34:**
- 5412: 4,060 (2022) to 2,872 (2025), down 29%.
- All industries: 492,343 to 391,497, down 20%.

## Age shares (5412)

| Age | 2015 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| 22–24 | 4.2% | 5.1% | 5.6% | 4.6% |
| 25–34 | 24.6% | 25.8% | 28.7% | 27.6% |
| 55–64 | 18.8% | 17.2% | 15.1% | 14.7% |
| 65+ | 7.9% | 9.2% | 9.5% | 9.7% |

Statewide 65+ share: 5.2% (2015), 7.7% (2025).

## Pay and turnover by age, 2024

**Average monthly earnings (EarnS, stable jobs):**

| Age | 5412 | All industries |
|---|---|---|
| 22–24 | $5,728 | $3,669 |
| 25–34 | $8,538 | $6,118 |
| 35–54 | about $10,150–10,320 | |

**Average quarterly separation rate:**

| Age | 5412 | All industries |
|---|---|---|
| 22–24 | 21.8% | 28.4% |
| 25–34 | 14.2% | 19.8% |
| 65+ | 19.7% | 16.3% |

The 65+ rate is likely driven by seasonal tax workers.

## Data notes

For the latest quarter (2025 Q4), Sep, EarnS and EmpS are blank, so 2025 annual figures should use Emp and HirN only. An aggregate() call with cbind() on those columns silently drops the quarter.
