# Colorado employment: Accounting & Payroll Services (NAICS 5412) vs.
# Professional, Scientific & Technical Services (NAICS 54) vs. statewide total.
#
# Sheets written:
#   Employment   - QCEW annual averages, 2014 onward
#   Growth       - CAGR / annual change as live Excel formulas
#   Quarterly    - latest QCEW quarters with year-over-year change (incl. 6-digit detail)
#   Detail       - accounting vs payroll (6-digit NAICS), Colorado vs US, annual
#   Age          - Census QWI employment and hires by age group (4-quarter averages)
#   Age detail   - QWI detailed age groups by year: employment, share, new hires
#   Raw QCEW, Raw QWI, Notes
#
# Sources: BLS QCEW open data API (no key needed); Census QWI API (needs a free key
# in the CENSUS_API_KEY environment variable: https://api.census.gov/data/key_signup.html).

library(openxlsx2) # install.packages(c("openxlsx2", "jsonlite")) if needed
library(jsonlite)

years <- 2014:2025 # QCEW annual averages
qtr_years <- 2024:2026 # QCEW quarters to try (missing ones are skipped)
age_years <- c(2015, 2025) # QWI range; summary sheet compares these two years
dir.create("output", showWarnings = FALSE)
out_file <- file.path("output", "CO_QCEW_Accounting_Payroll.xlsx") # run from the project root

# own_code 0 = total covered (all ownerships); 5 = private
series <- data.frame(
  own_code = c(0, 5, 5, 5),
  industry_code = c("10", "10", "54", "5412"),
  label = c(
    "Colorado total (all ownerships)",
    "Colorado total private",
    "PST sector (NAICS 54), private",
    "Accounting & Payroll (NAICS 5412), private"
  )
)

# 6-digit detail inside 5412 (private) for the quarterly sheet
detail <- data.frame(
  industry_code = c("541211", "541213", "541214", "541219"),
  label = c(
    "Offices of CPAs (541211)",
    "Tax preparation (541213)",
    "Payroll services (541214)",
    "Other accounting services (541219)"
  )
)

qcew_url <- function(y, period) {
  sprintf("https://data.bls.gov/cew/data/api/%d/%s/area/08000.csv", y, period)
}

# Read a BLS open-data CSV. A file BLS has not yet published returns HTTP 404:
# report that as a message and return NULL, and drop the "cannot open URL"
# warning that read.csv() raises alongside the error. Any other warning or
# error still surfaces, so a network failure is not mistaken for "not published".
read_bls_csv <- function(url, what, col_classes) {
  not_published <- FALSE
  d <- tryCatch(
    withCallingHandlers(
      read.csv(url, colClasses = col_classes),
      warning = function(w) {
        if (grepl("404", conditionMessage(w))) {
          not_published <<- TRUE
          invokeRestart("muffleWarning")
        }
      }
    ),
    error = function(e) {
      if (!not_published) {
        warning(what, ": ", conditionMessage(e), call. = FALSE)
      }
      NULL
    }
  )
  if (not_published) {
    message("  ", what, " not yet published by BLS; skipped")
  }
  if (is.null(d) || nrow(d) == 0) NULL else d
}

read_qcew <- function(y, period) {
  what <- if (period == "a") paste(y, "annual") else paste0(y, " Q", period)
  read_bls_csv(
    qcew_url(y, period),
    what,
    c(industry_code = "character", area_fips = "character")
  )
}

# ---------------- Annual averages ----------------
pull_year <- function(y) {
  d <- read_qcew(y, "a")
  if (is.null(d)) {
    stop("QCEW annual data not available for ", y)
  }
  d <- merge(d, series, by = c("own_code", "industry_code"))
  d[, c(
    "year",
    "area_fips",
    "own_code",
    "industry_code",
    "agglvl_code",
    "label",
    "annual_avg_estabs",
    "annual_avg_emplvl",
    "total_annual_wages",
    "annual_avg_wkly_wage",
    "disclosure_code"
  )]
}

raw <- do.call(
  rbind,
  lapply(years, function(y) {
    message("Pulling annual ", y)
    pull_year(y)
  })
)
raw <- raw[order(raw$label, raw$year), ]
if (any(raw$disclosure_code != "")) {
  warning("Some annual cells are suppressed (disclosure_code = 'N').")
}

emp <- reshape(
  raw[, c("year", "label", "annual_avg_emplvl")],
  idvar = "year",
  timevar = "label",
  direction = "wide"
)
names(emp) <- sub("annual_avg_emplvl\\.", "", names(emp))
emp <- emp[order(emp$year), c("year", series$label)]

# ---------------- Quarterly ----------------
qtr_series <- rbind(
  series[series$label != "Colorado total private", ],
  data.frame(own_code = 5, detail)
)

pull_qtr <- function(y, q) {
  d <- read_qcew(y, q)
  if (is.null(d)) {
    return(NULL)
  }
  d <- merge(d, qtr_series, by = c("own_code", "industry_code"))
  data.frame(
    year = y,
    qtr = q,
    label = d$label,
    industry_code = d$industry_code,
    estabs = d$qtrly_estabs,
    emp = round((d$month1_emplvl + d$month2_emplvl + d$month3_emplvl) / 3),
    avg_wkly_wage = d$avg_wkly_wage,
    disclosure_code = d$disclosure_code
  )
}
qgrid <- expand.grid(q = 1:4, y = qtr_years)
qraw <- do.call(
  rbind,
  Map(
    function(y, q) {
      message("Pulling ", y, " Q", q)
      pull_qtr(y, q)
    },
    qgrid$y,
    qgrid$q
  )
)
qraw$period <- paste0(qraw$year, " Q", qraw$qtr)
# Year-over-year change vs same quarter a year earlier (QCEW is not seasonally adjusted)
key <- paste(qraw$label, qraw$year - 1, qraw$qtr)
prior <- setNames(qraw$emp, paste(qraw$label, qraw$year, qraw$qtr))[key]
qraw$emp_yoy_pct <- round(100 * (qraw$emp / prior - 1), 1)
qtr_tbl <- reshape(
  qraw[, c("label", "period", "emp")],
  idvar = "label",
  timevar = "period",
  direction = "wide"
)
names(qtr_tbl) <- sub("emp\\.", "", names(qtr_tbl))
qtr_tbl <- qtr_tbl[match(qtr_series$label, qtr_tbl$label), ]
latest_q <- tail(sort(unique(qraw$period)), 1)
qtr_tbl$`Latest YoY %` <- qraw$emp_yoy_pct[qraw$period == latest_q][match(
  qtr_tbl$label,
  qraw$label[qraw$period == latest_q]
)]

# ---------------- QWI age ----------------
age_labels <- c(
  A01 = "Under 25",
  A02 = "Under 25",
  A03 = "Under 25",
  A04 = "25-34",
  A05 = "35-54",
  A06 = "35-54",
  A07 = "55-64",
  A08 = "65+"
)
qwi_inds <- c(
  "5412" = "Accounting & Payroll (NAICS 5412)",
  "54" = "PST sector (NAICS 54)",
  "00" = "All industries"
)

detail_age <- c(
  A01 = "14-18",
  A02 = "19-21",
  A03 = "22-24",
  A04 = "25-34",
  A05 = "35-44",
  A06 = "45-54",
  A07 = "55-64",
  A08 = "65+"
)

# One call per industry for the whole quarterly range.
# Emp = beginning-of-quarter employment; HirA = all hires; HirN = new hires (not recalls).
qwi <- function(ind) {
  u <- paste0(
    "https://api.census.gov/data/timeseries/qwi/sa?get=Emp,HirA,HirN,agegrp",
    "&for=state:08&ownercode=A05&sex=0&seasonadj=U",
    "&time=from+",
    min(age_years),
    "-Q1+to+",
    max(age_years),
    "-Q4",
    if (ind != "00") paste0("&industry=", ind) else "",
    "&key=",
    Sys.getenv("CENSUS_API_KEY")
  )
  r <- fromJSON(u)
  d <- as.data.frame(r[-1, , drop = FALSE])
  names(d) <- r[1, ]
  data.frame(
    industry = qwi_inds[[ind]],
    time = d$time,
    agegrp = d$agegrp,
    emp = as.numeric(d$Emp),
    hires = as.numeric(d$HirA),
    new_hires = as.numeric(d$HirN)
  )
}

age_tbl <- NULL
age_detail <- NULL
qwi_raw <- NULL
if (nzchar(Sys.getenv("CENSUS_API_KEY"))) {
  qwi_raw <- do.call(
    rbind,
    lapply(names(qwi_inds), function(i) {
      message("QWI ", i)
      qwi(i)
    })
  )
  qwi_raw <- qwi_raw[order(qwi_raw$industry, qwi_raw$time, qwi_raw$agegrp), ]
  a <- qwi_raw[qwi_raw$agegrp != "A00", ]
  a$year <- substr(a$time, 1, 4)
  # keep only complete years (4 quarters) so annual averages and totals are comparable
  nq <- tapply(a$time, a$year, function(t) length(unique(t)))
  a <- a[a$year %in% names(nq)[nq == 4], ]

  # Summary groups for the comparison years: 4-quarter averages and shares
  b <- a[a$year %in% age_years, ]
  b$age <- factor(age_labels[b$agegrp], unique(age_labels))
  age_tbl <- aggregate(
    cbind(emp, hires) ~ industry + year + age,
    b,
    function(v) sum(v) / 4
  )
  tot <- function(v) ave(v, age_tbl$industry, age_tbl$year, FUN = sum)
  age_tbl$emp_share <- age_tbl$emp / tot(age_tbl$emp)
  age_tbl$hires_share <- age_tbl$hires / tot(age_tbl$hires)
  age_tbl <- age_tbl[
    order(match(age_tbl$industry, qwi_inds), age_tbl$year, age_tbl$age),
  ]
  age_tbl$emp <- round(age_tbl$emp)
  age_tbl$hires <- round(age_tbl$hires)

  # Detailed age groups by year: average employment, share, and annual new hires
  a$age <- factor(detail_age[a$agegrp], detail_age)
  age_detail <- merge(
    aggregate(emp ~ industry + year + age, a, mean),
    aggregate(new_hires ~ industry + year + age, a, sum)
  )
  age_detail$emp_share <- age_detail$emp /
    ave(age_detail$emp, age_detail$industry, age_detail$year, FUN = sum)
  age_detail <- age_detail[
    order(
      match(age_detail$industry, qwi_inds),
      age_detail$age,
      age_detail$year
    ),
  ]
  age_detail$emp <- round(age_detail$emp)
} else {
  warning("CENSUS_API_KEY not set: skipping the Age sheets.")
}

# ---------------- Annual 6-digit detail: accounting vs payroll, CO vs US ----------------
# Uses the QCEW industry files, which hold every area for one industry.
detail_years <- c(2015, max(years) - 1, max(years))
pull_detail <- function(ind, y) {
  d <- read_bls_csv(
    sprintf("https://data.bls.gov/cew/data/api/%d/a/industry/%s.csv", y, ind),
    paste(y, "annual, industry", ind),
    c(area_fips = "character")
  )
  if (is.null(d)) {
    return(NULL)
  }
  d <- d[d$area_fips %in% c("08000", "US000") & d$own_code == 5, ]
  data.frame(
    industry_code = ind,
    year = y,
    area = ifelse(d$area_fips == "08000", "Colorado", "United States"),
    emp = d$annual_avg_emplvl,
    estabs = d$annual_avg_estabs,
    wkly_wage = d$annual_avg_wkly_wage
  )
}
draw <- do.call(
  rbind,
  lapply(detail$industry_code, function(i) {
    do.call(
      rbind,
      lapply(detail_years, function(y) {
        message("Detail ", i, " ", y)
        pull_detail(i, y)
      })
    )
  })
)
draw$label <- detail$label[match(draw$industry_code, detail$industry_code)]
detail_tbl <- reshape(
  draw[, c("label", "area", "year", "emp")],
  idvar = c("label", "area"),
  timevar = "year",
  direction = "wide"
)
y0 <- detail_years[1]
y1 <- detail_years[2]
y2 <- detail_years[3]
detail_tbl$cagr <- (detail_tbl[[paste0("emp.", y2)]] /
  detail_tbl[[paste0("emp.", y0)]])^(1 / (y2 - y0)) -
  1
detail_tbl$chg <- detail_tbl[[paste0("emp.", y2)]] /
  detail_tbl[[paste0("emp.", y1)]] -
  1
detail_tbl$wage <- draw$wkly_wage[draw$year == y2][match(
  paste(detail_tbl$label, detail_tbl$area),
  paste(draw$label, draw$area)[draw$year == y2]
)]
detail_tbl <- detail_tbl[
  order(detail_tbl$area, match(detail_tbl$label, detail$label)),
]
names(detail_tbl) <- c(
  "Industry",
  "Area",
  paste("Employment", detail_years),
  paste0("CAGR ", y0, "-", y2),
  paste0("Change ", y1, "-", y2),
  paste("Avg weekly wage", y2)
)

# ---------------- Workbook ----------------
wb <- wb_workbook()

# helper: bold, wrapped header row
style_header <- function(wb, sheet, row, ncol) {
  d <- wb_dims(rows = row, cols = 1:ncol)
  wb |>
    wb_add_font(sheet, dims = d, bold = TRUE) |>
    wb_add_cell_style(sheet, dims = d, wrap_text = TRUE) |>
    wb_add_border(
      sheet,
      dims = d,
      top_border = NULL,
      left_border = NULL,
      right_border = NULL
    )
}

# Employment
wb <- wb |>
  wb_add_worksheet("Employment") |>
  wb_add_data("Employment", emp) |>
  style_header("Employment", 1, ncol(emp)) |>
  wb_add_numfmt(
    "Employment",
    dims = wb_dims(rows = 2:(nrow(emp) + 1), cols = 2:ncol(emp)),
    numfmt = "#,##0"
  ) |>
  wb_set_col_widths("Employment", cols = 1:ncol(emp), widths = c(8, rep(22, 4)))

# Growth: formulas reference the Employment sheet so every number is traceable
row_of <- function(y) match(y, emp$year) + 1
cols <- LETTERS[2:(1 + nrow(series))]
periods <- data.frame(
  measure = c("CAGR (10-yr)", "CAGR", "CAGR", "Annual change", "Annual change"),
  start = c(2015, 2014, 2015, 2023, 2024),
  end = c(2025, 2023, 2024, 2024, 2025)
)
periods <- periods[periods$end <= max(years), ]
growth_hdr <- as.data.frame(t(c("Measure", "Start", "End", series$label)))
wb <- wb |>
  wb_add_worksheet("Growth") |>
  wb_add_data("Growth", growth_hdr, col_names = FALSE) |>
  wb_add_data("Growth", periods, start_row = 2, col_names = FALSE) |>
  style_header("Growth", 1, 3 + nrow(series))
for (i in seq_len(nrow(periods))) {
  r <- i + 1
  p <- periods[i, ]
  for (j in seq_along(cols)) {
    f <- sprintf(
      "(Employment!%s%d/Employment!%s%d)^(1/(C%d-B%d))-1",
      cols[j],
      row_of(p$end),
      cols[j],
      row_of(p$start),
      r,
      r
    )
    wb <- wb_add_formula(
      wb,
      "Growth",
      x = f,
      dims = wb_dims(rows = r, cols = 3 + j)
    )
  }
}
wb <- wb |>
  wb_add_numfmt(
    "Growth",
    dims = wb_dims(rows = 2:(nrow(periods) + 1), cols = 4:(3 + nrow(series))),
    numfmt = "0.0%"
  ) |>
  wb_set_col_widths(
    "Growth",
    cols = 1:(3 + nrow(series)),
    widths = c(14, 7, 7, rep(22, 4))
  )

# Quarterly
wb <- wb |>
  wb_add_worksheet("Quarterly") |>
  wb_add_data(
    "Quarterly",
    paste(
      "QCEW quarterly employment (average of 3 months), Colorado. Not seasonally",
      "adjusted: compare a quarter with the same quarter a year earlier. Latest:",
      latest_q
    )
  ) |>
  wb_add_data("Quarterly", qtr_tbl, start_row = 3) |>
  style_header("Quarterly", 3, ncol(qtr_tbl)) |>
  wb_add_numfmt(
    "Quarterly",
    dims = wb_dims(rows = 4:(nrow(qtr_tbl) + 3), cols = 2:(ncol(qtr_tbl) - 1)),
    numfmt = "#,##0"
  ) |>
  wb_set_col_widths(
    "Quarterly",
    cols = 1:ncol(qtr_tbl),
    widths = c(40, rep(11, ncol(qtr_tbl) - 1))
  )

# Detail: accounting vs payroll
nd <- nrow(detail_tbl)
rd <- 4:(nd + 3)
wb <- wb |>
  wb_add_worksheet("Detail") |>
  wb_add_data(
    "Detail",
    paste(
      "QCEW annual averages, private ownership. Note: US payroll services (541214)",
      "dropped ~30,000 in Jan 2025 in a single step, likely a reclassification."
    )
  ) |>
  wb_add_data("Detail", detail_tbl, start_row = 3) |>
  style_header("Detail", 3, ncol(detail_tbl)) |>
  wb_add_numfmt(
    "Detail",
    dims = wb_dims(rows = rd, cols = 3:5),
    numfmt = "#,##0"
  ) |>
  wb_add_numfmt(
    "Detail",
    dims = wb_dims(rows = rd, cols = 6:7),
    numfmt = "0.0%"
  ) |>
  wb_add_numfmt(
    "Detail",
    dims = wb_dims(rows = rd, cols = 8),
    numfmt = "$#,##0"
  ) |>
  wb_set_col_widths(
    "Detail",
    cols = 1:8,
    widths = c(34, 14, 12, 12, 12, 12, 12, 12)
  )

# Age
if (!is.null(age_tbl)) {
  out <- age_tbl[, c(
    "industry",
    "year",
    "age",
    "emp",
    "emp_share",
    "hires",
    "hires_share"
  )]
  out$age <- as.character(out$age)
  names(out) <- c(
    "Industry",
    "Year",
    "Age group",
    "Employment",
    "Share of employment",
    "Hires",
    "Share of hires"
  )
  rr <- 4:(nrow(out) + 3)
  wb <- wb |>
    wb_add_worksheet("Age") |>
    wb_add_data(
      "Age",
      paste(
        "Census QWI, Colorado, private sector, 4-quarter averages.",
        "Hires = all accessions (HirA). QWI industry detail stops at 4-digit NAICS."
      )
    ) |>
    wb_add_data("Age", out, start_row = 3) |>
    style_header("Age", 3, ncol(out)) |>
    wb_add_numfmt(
      "Age",
      dims = wb_dims(rows = rr, cols = 4),
      numfmt = "#,##0"
    ) |>
    wb_add_numfmt(
      "Age",
      dims = wb_dims(rows = rr, cols = 6),
      numfmt = "#,##0"
    ) |>
    wb_add_numfmt(
      "Age",
      dims = wb_dims(rows = rr, cols = 5),
      numfmt = "0.0%"
    ) |>
    wb_add_numfmt(
      "Age",
      dims = wb_dims(rows = rr, cols = 7),
      numfmt = "0.0%"
    ) |>
    wb_set_col_widths(
      "Age",
      cols = 1:7,
      widths = c(34, 7, 11, 12, 12, 10, 12)
    ) |>
    wb_add_worksheet("Raw QWI") |>
    wb_add_data("Raw QWI", qwi_raw)

  # Age detail: wide tables (age group x year) for employment, share, and new hires
  wide <- function(var) {
    w <- reshape(
      age_detail[, c("industry", "age", "year", var)],
      idvar = c("industry", "age"),
      timevar = "year",
      direction = "wide"
    )
    names(w) <- sub(paste0("^", var, "\\."), "", names(w))
    w$age <- as.character(w$age)
    names(w)[1:2] <- c("Industry", "Age group")
    w
  }
  blocks <- list(
    "Average employment" = list(wide("emp"), "#,##0"),
    "Share of employment" = list(wide("emp_share"), "0.0%"),
    "New hires (annual total)" = list(wide("new_hires"), "#,##0")
  )
  wb <- wb |>
    wb_add_worksheet("Age detail") |>
    wb_add_data(
      "Age detail",
      paste(
        "Census QWI, Colorado, private sector. Employment is the average of",
        "beginning-of-quarter counts; new hires exclude recalls. Complete years only."
      )
    )
  r0 <- 3
  for (nm in names(blocks)) {
    tb <- blocks[[nm]][[1]]
    wb <- wb |>
      wb_add_data("Age detail", nm, start_row = r0) |>
      wb_add_font(
        "Age detail",
        dims = wb_dims(rows = r0, cols = 1),
        bold = TRUE
      ) |>
      wb_add_data("Age detail", tb, start_row = r0 + 1) |>
      style_header("Age detail", r0 + 1, ncol(tb)) |>
      wb_add_numfmt(
        "Age detail",
        dims = wb_dims(rows = (r0 + 2):(r0 + 1 + nrow(tb)), cols = 3:ncol(tb)),
        numfmt = blocks[[nm]][[2]]
      )
    r0 <- r0 + nrow(tb) + 3
  }
  wb <- wb_set_col_widths(
    wb,
    "Age detail",
    cols = 1:ncol(tb),
    widths = c(34, 10, rep(9, ncol(tb) - 2))
  )
}

wb <- wb |>
  wb_add_worksheet("Raw QCEW") |>
  wb_add_data("Raw QCEW", raw) |>
  wb_add_data("Raw QCEW", qraw, start_col = ncol(raw) + 2)

wb <- wb |>
  wb_add_worksheet("Notes") |>
  wb_add_data(
    "Notes",
    data.frame(
      Notes = c(
        "QCEW: BLS Quarterly Census of Employment and Wages, Colorado statewide (08000).",
        "QCEW API: https://data.bls.gov/cew/data/api/{year}/{a|1-4}/area/08000.csv",
        "NAICS 54, 5412 and 6-digit detail are private ownership (own_code 5).",
        "CAGR = (End/Start)^(1/(End-Start)) - 1; one-year rows are simple percent change.",
        "QCEW quarterly data are not seasonally adjusted; 5412 peaks in Q1 (tax season).",
        "QWI: Census Quarterly Workforce Indicators, state 08, ownercode A05 (private), not seasonally adjusted.",
        "QCEW prior years are revised; a fresh pull may differ slightly from earlier published figures.",
        paste("Pulled:", format(Sys.time(), "%Y-%m-%d %H:%M"))
      )
    )
  ) |>
  wb_set_col_widths("Notes", cols = 1, widths = 110)

wb_save(wb, out_file, overwrite = TRUE)
message("Saved ", normalizePath(out_file))
