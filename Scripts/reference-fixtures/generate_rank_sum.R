# R reference for the exact rank-sum distribution. Base R only.
#
# Called by generate_rank_sum.py with a cases file of *averaged ranks* (the Python side has
# already run `rankdata`, so both tools see the same numbers):
#
#     Rscript generate_rank_sum.R cases.txt
#
# This is a second, independent implementation of the convolution in a different language:
# it shares no code with the Python generator or with BusinessMath. For each case it
# convolves one discrete uniform per judge over that judge's doubled ranks, in double
# precision, and then reads the two-sided critical values off the result at alpha = 0.05,
# 0.10 and 0.01. A sum <= lower or >= upper is significant; `lower` is the largest attainable
# sum with P(S <= lower) <= alpha/2, and `upper` the smallest with P(S >= upper) <= alpha/2.
#
# Prints, per case, one tab-separated line:
#   name, minimum doubled sum, then the pmf over consecutive doubled sums separated by
#   commas, then for each alpha "lower|upper" in doubled units (NA when none exists).
#
# The comparison against alpha/2 allows a relative 1e-9, because P(S <= s) is a rounded sum
# and can land a few ulps above an alpha/2 it equals exactly (2 judges x 20 wines).

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[1] else "rank_sum_cases.txt"

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

pmf_of <- function(ranks) {
  n <- ncol(ranks)
  pmf <- 1
  low <- 0
  for (j in seq_len(nrow(ranks))) {
    doubled <- as.integer(round(2 * ranks[j, ]))
    lo <- min(doubled)
    hi <- max(doubled)
    step <- tabulate(doubled - lo + 1L, nbins = hi - lo + 1L) / n
    out <- numeric(length(pmf) + length(step) - 1L)
    for (k in seq_along(step)) {
      if (step[k] == 0) next
      idx <- seq_along(pmf) + (k - 1L)
      out[idx] <- out[idx] + pmf * step[k]
    }
    pmf <- out
    low <- low + lo
  }
  list(low = low, pmf = pmf)
}

critical <- function(d, alpha) {
  tail <- alpha / 2
  allow <- tail * (1 + 1e-9)
  support <- which(d$pmf > 0)
  cdf <- cumsum(d$pmf)
  sf <- rev(cumsum(rev(d$pmf)))
  lower <- support[cdf[support] <= allow]
  upper <- support[sf[support] <= allow]
  lo <- if (length(lower) > 0) max(lower) - 1L + d$low else NA
  hi <- if (length(upper) > 0) min(upper) - 1L + d$low else NA
  paste0(lo, "|", hi)
}

for (case in read_cases(path)) {
  d <- pmf_of(case$m)
  crit <- sapply(c(0.05, 0.10, 0.01), function(a) critical(d, a))
  cat(case$name, d$low, paste(fmt(d$pmf), collapse = ","), crit, sep = "\t")
  cat("\n")
}
