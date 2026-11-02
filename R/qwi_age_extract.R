# Colorado QWI extract: Accounting & Payroll Services (NAICS 5412), PST (54) and all
# industries, by age group, quarterly 2015 onward, private ownership.
#
# Writes output/CO_QWI_Accounting_Payroll_by_age.xlsx with three sheets:
#   Quarterly   - every variable below, by industry x age group x quarter
#   Annual      - stocks/rates/earnings averaged, flows summed (complete years only)
#   Definitions - what each variable means, plus notes
#
# Needs a Census API key in CENSUS_API_KEY. Run from the project root.

library(openxlsx2)
library(jsonlite)

start_q  <- "2015-Q1"
end_q    <- "2025-Q4"               # Census returns what exists; later quarters can be blank
out_file <- file.path("output", "CO_QWI_Accounting_Payroll_by_age.xlsx")
dir.create("output", showWarnings = FALSE)

vars <- c("Emp", "EmpEnd", "EmpS", "EmpTotal", "HirA", "HirN", "HirR", "Sep", "SepBeg",
          "FrmJbGn", "FrmJbLs", "FrmJbC", "TurnOvrS", "EarnS", "EarnHirNS", "Payroll")
inds <- c("5412" = "Accounting & Payroll Services (5412)",
          "54"   = "Professional, Scientific & Technical Services (54)",
          "00"   = "All industries")
ages <- c(A00 = "All ages", A01 = "14-18", A02 = "19-21", A03 = "22-24", A04 = "25-34",
          A05 = "35-44", A06 = "45-54", A07 = "55-64", A08 = "65+")

pull <- function(ind) {
  message("QWI ", ind)
  u <- paste0("https://api.census.gov/data/timeseries/qwi/sa?get=", paste(vars, collapse = ","), ",agegrp",
              "&for=state:08&ownercode=A05&sex=0&seasonadj=U",
              "&time=from+", start_q, "+to+", end_q,
              if (ind != "00") paste0("&industry=", ind) else "",
              "&key=", Sys.getenv("CENSUS_API_KEY"))
  r <- fromJSON(u); d <- as.data.frame(r[-1, , drop = FALSE]); names(d) <- r[1, ]
  d[vars] <- lapply(d[vars], as.numeric)
  data.frame(industry = inds[[ind]],
             year = as.integer(substr(d$time, 1, 4)), quarter = as.integer(substr(d$time, 7, 7)),
             age_group = factor(ages[d$agegrp], ages), d[vars])
}

if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY first.")
qwi <- do.call(rbind, lapply(names(inds), pull))
qwi <- qwi[order(match(qwi$industry, inds), qwi$age_group, qwi$year, qwi$quarter), ]
qwi$age_group <- as.character(qwi$age_group)

# ---- Annual: averages for stocks, rates and earnings; sums for flows ----
stocks <- c("Emp", "EmpEnd", "EmpS", "EmpTotal", "TurnOvrS", "EarnS", "EarnHirNS")
flows  <- c("HirA", "HirN", "HirR", "Sep", "SepBeg", "FrmJbGn", "FrmJbLs", "FrmJbC", "Payroll")
g <- split(qwi, list(qwi$industry, qwi$age_group, qwi$year), drop = TRUE)
annual <- do.call(rbind, lapply(g, function(d) {
  full <- function(v) nrow(d) == 4 && !anyNA(v)     # blank if any quarter is missing
  cbind(d[1, c("industry", "age_group", "year")],
        as.data.frame(lapply(setNames(stocks, stocks), function(v)
          if (full(d[[v]])) round(mean(d[[v]]), ifelse(v == "TurnOvrS", 3, 0)) else NA)),
        as.data.frame(lapply(setNames(flows, flows), function(v)
          if (full(d[[v]])) sum(d[[v]]) else NA)))
}))
annual <- annual[order(match(annual$industry, inds), match(annual$age_group, ages), annual$year), ]
rownames(annual) <- NULL

# ---- Definitions ----
dict <- data.frame(
  Variable = vars,
  Name = c("Beginning-of-quarter employment", "End-of-quarter employment",
           "Full-quarter (stable) employment", "Employment at any point in the quarter",
           "Hires (all)", "New hires", "Recalls", "Separations",
           "Separations of beginning-of-quarter workers",
           "Firm job gains", "Firm job losses", "Firm job change (net)",
           "Turnover rate, stable jobs", "Average monthly earnings, stable jobs",
           "Average monthly earnings, stable new hires", "Total quarterly payroll"),
  Definition = c(
    "Jobs held on the first day of the quarter (the worker was also on that employer's payroll the prior quarter). The standard 'employment' count.",
    "Jobs held on the last day of the quarter.",
    "Jobs held for the full quarter: the worker was on the payroll the quarter before, during, and after.",
    "Everyone who held a job with the employer at any time during the quarter.",
    "Workers who started a job with an employer they did not work for in the previous quarter. HirA = HirN + HirR.",
    "Hires who had not worked for that employer at any time in the previous four quarters (genuinely new to the employer).",
    "Hires who had worked for that employer within the previous four quarters, but not last quarter (e.g., seasonal tax staff returning).",
    "Workers with a job at the employer this quarter but not next quarter. Quits, layoffs and retirements are not distinguished. Blank in the latest quarter.",
    "Separations among workers who were employed at the start of the quarter.",
    "For each employer, end-of-quarter minus start-of-quarter employment within THIS age group, summed over employers where it rose. Blank in the latest quarter.",
    "Same calculation, summed over employers where it fell (reported as a positive number). Includes leavers who were not replaced, not only layoffs.",
    "Firm job gains minus firm job losses (equals EmpEnd minus Emp).",
    "Quarterly turnover rate for full-quarter jobs (a share, not a percent).",
    "Average monthly earnings of workers holding full-quarter jobs (nominal dollars).",
    "Average monthly earnings of new hires who stayed the full quarter (nominal dollars).",
    "Total wages paid in the quarter (nominal dollars)."))

notes <- c(
  "Source: U.S. Census Bureau, LEHD Quarterly Workforce Indicators (QWI), api.census.gov/data/timeseries/qwi/sa.",
  paste0("Colorado (state 08), private ownership (A05), both sexes, not seasonally adjusted. Pulled ", Sys.Date(), "."),
  "QWI industry detail stops at 4-digit NAICS: 5412 cannot be split into accounting vs payroll here.",
  "Age groups are set each quarter, so a worker turning 35 moves from 25-34 to 35-44 between quarters, not within one.",
  "Annual sheet: stocks, rates and earnings are 4-quarter averages; flows (hires, separations, job gains/losses, payroll) are 4-quarter sums. Years missing any quarter are blank.",
  "Not seasonally adjusted: 5412 peaks in Q1 (tax season); compare like quarters or full years.",
  "Documentation: https://lehd.ces.census.gov/doc/QWI_101.pdf  Interactive view: https://qwiexplorer.ces.census.gov")

# ---- Workbook ----
bold_header <- function(wb, sheet, n) wb_add_font(wb, sheet, dims = wb_dims(rows = 1, cols = 1:n), bold = TRUE)
wb <- wb_workbook() |>
  wb_add_worksheet("Quarterly") |> wb_add_data("Quarterly", qwi) |>
  bold_header("Quarterly", ncol(qwi)) |> wb_freeze_pane("Quarterly", first_row = TRUE) |>
  wb_add_worksheet("Annual") |> wb_add_data("Annual", annual) |>
  bold_header("Annual", ncol(annual)) |> wb_freeze_pane("Annual", first_row = TRUE) |>
  wb_add_worksheet("Definitions") |> wb_add_data("Definitions", dict) |>
  bold_header("Definitions", 3) |>
  wb_set_col_widths("Definitions", cols = 1:3, widths = c(12, 40, 110)) |>
  wb_add_data("Definitions", data.frame(Notes = notes), start_row = nrow(dict) + 3)
wb_save(wb, out_file, overwrite = TRUE)
message("Saved ", normalizePath(out_file))
