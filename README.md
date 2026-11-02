# CBEOF 2026: Accounting and Payroll Services (NAICS 5412)

Data, scripts and notes for the Accounting and Payroll Services section of the Professional and Business Services chapter.

## Layout

| Path | What it is |
|---|---|
| `R/qcew_accounting_payroll_co.R` | BLS QCEW pull. Writes `output/CO_QCEW_Accounting_Payroll.xlsx`, with sheets for annual employment, growth rates (live formulas), quarterly data, the accounting vs payroll split (CO vs US), and the QWI age summary. |
| `output/5412_section_calculations.qmd` | **Audit notebook.** Recomputes every number in the section from source data and writes the section text with inline R, so the text stays live. Ends with an audit table that flags wording to review. Render with `quarto render output/5412_section_calculations.qmd`. |
| `R/qwi_age_extract.R` | Census QWI pull: 5412, PST and all industries, by age group, quarterly from 2015. Writes `output/CO_QWI_Accounting_Payroll_by_age.xlsx` with Quarterly, Annual and Definitions sheets. |
| `inputs/` | Local source files: the two Lightcast exports and the CDLE LMI 2025–35 projections CSV. `inputs/raw/` holds cached API pulls written by the notebook; delete a file to refresh it. |
| `notes/draft_section.md` | Draft replacement text for the section (snapshot; the live version is in the Claude doc). |
| `notes/research_notes.md` | Industry data and trends, split into accounting and payroll. |
| `notes/qwi_age_detail.md` | Employment by detailed age, shares, pay and turnover. |
| `notes/separations_hiring.md` | Hires vs separations; firm job gains and losses; LEHD Job-to-Job Flows (PST sector). |
| `notes/talent_pipeline_and_citations.md` | 2025 Colorado Talent Pipeline Report items; the chapter's citation style. |

## Running

Run both scripts from the project root:

```r
source("R/qcew_accounting_payroll_co.R")
source("R/qwi_age_extract.R")
```

- Packages: `openxlsx2`, `jsonlite`.
- QCEW needs no key.
- QWI needs a Census API key in the `CENSUS_API_KEY` environment variable.
- Outputs go to `output/`.

## Data cautions

- **Seasonality:** QCEW and QWI are not seasonally adjusted. 5412 peaks in Q1 (tax season), so compare like quarters or full years.
- **No accounting/payroll split in QWI:** QWI stops at 4-digit NAICS, so the age figures cover accounting and payroll combined.
- **Latest QWI quarter:** separations, stable employment, earnings and firm job flows are blank, so annual figures for that year are incomplete.
- **US payroll services (541214):** fell about 30,000 in a single step in January 2025, likely a reclassification.
