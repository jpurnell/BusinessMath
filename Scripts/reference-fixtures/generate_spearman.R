# R reference for Spearman's rho p-values. Base R only.
#
# Called by generate_spearman.py with a tab-separated file of observations:
#
#     Rscript generate_spearman.R observations.tsv
#
# Each input line is: name, index, x values (comma separated), y values (comma separated).
# For each line this prints one tab-separated line:
#
#   name, index, rho, p from cor.test(exact = TRUE), p from cor.test(exact = FALSE)
#
# What R computes (R 4.6.2, stats:::cor.test.default and src/library/stats/src/prho.c):
#
# - exact = TRUE, no ties, n <= 9: exact enumeration of all n! permutations (prho.c,
#   `n_small` = 9).
# - exact = TRUE, no ties, 10 <= n <= 1290: the Edgeworth series of AS 89 (Best and
#   Roberts 1975). This is an APPROXIMATION, despite the argument's name.
# - exact = TRUE with ties: R warns "cannot compute exact p-value with ties" and falls back
#   to exact = FALSE.
# - exact = FALSE: the t approximation, t = r sqrt((n - 2) / (1 - r^2)) on n - 2 degrees of
#   freedom, with r the Pearson correlation of the averaged ranks.
#
# Two-sided p-values double the one-sided tail on the side of the observation, capped at 1.

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[1] else "observations.tsv"

lines <- readLines(path)
for (line in lines) {
  fields <- strsplit(line, "\t", fixed = TRUE)[[1]]
  name <- fields[1]
  index <- fields[2]
  x <- as.numeric(strsplit(fields[3], ",", fixed = TRUE)[[1]])
  y <- as.numeric(strsplit(fields[4], ",", fixed = TRUE)[[1]])
  exact <- suppressWarnings(cor.test(x, y, method = "spearman", exact = TRUE))
  approx <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  cat(name, index,
      formatC(unname(exact$estimate), digits = 17, format = "g"),
      formatC(exact$p.value, digits = 17, format = "g"),
      formatC(approx$p.value, digits = 17, format = "g"),
      sep = "\t")
  cat("\n")
}
cat("#version\t", R.version.string, "\n", sep = "")
