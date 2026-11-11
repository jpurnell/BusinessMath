# R reference values for the tie-corrected concordance tests.
#
# Called by generate_concordance.py; can be run on its own:
#
#     Rscript generate_concordance.R concordance_cases.txt
#
# Prints one tab-separated line per case:
#   name, friedman.test statistic, friedman.test p-value,
#   irr::kendall(correct = TRUE) W, its chi-squared, its p-value
#
# `friedman.test` applies the tie correction to its statistic. `irr::kendall` ranks each
# rater's column itself (average method) and, with `correct = TRUE`, applies the
# m * sum(t^3 - t) correction to W's denominator. Its ratings argument is subjects x raters,
# so the judge-by-item matrix is transposed before it is passed.
#
# If the irr package is not installed the last three columns are NA, and W can be recovered
# from the Friedman statistic as chi2 / (m (n - 1)).

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[1] else "concordance_cases.txt"

have_irr <- suppressWarnings(requireNamespace("irr", quietly = TRUE))

read_cases <- function(path) {
  lines <- readLines(path)
  cases <- list()
  name <- NULL
  rows <- list()
  flush <- function() {
    if (!is.null(name) && length(rows) > 0) {
      cases[[length(cases) + 1]] <<- list(name = name, m = do.call(rbind, rows))
    }
  }
  for (line in lines) {
    if (startsWith(line, "#")) next
    if (startsWith(line, "case ")) {
      flush()
      name <- substring(line, 6)
      rows <- list()
    } else if (nchar(trimws(line)) == 0) {
      flush()
      name <- NULL
      rows <- list()
    } else {
      rows[[length(rows) + 1]] <- as.numeric(strsplit(trimws(line), "[[:space:]]+")[[1]])
    }
  }
  flush()
  cases
}

fmt <- function(x) formatC(x, digits = 17, format = "g")

for (case in read_cases(path)) {
  y <- case$m
  fr <- friedman.test(y)
  if (have_irr) {
    kw <- irr::kendall(t(y), correct = TRUE)
    w <- kw$value
    wchi <- kw$statistic
    wp <- kw$p.value
  } else {
    w <- NA
    wchi <- NA
    wp <- NA
  }
  cat(case$name, fmt(unname(fr$statistic)), fmt(fr$p.value),
      fmt(unname(w)), fmt(unname(wchi)), fmt(wp), sep = "\t")
  cat("\n")
}
