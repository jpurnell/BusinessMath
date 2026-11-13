# R reference for wilsonInterval, medianAbsoluteDeviation and poissonSurvival. Base R only.
#
#     Rscript generate_hub_statistics.R
#
# Shares no code with BusinessMath or with generate_hub_statistics.py (SciPy). Prints one
# tab-separated line per case, every number with 17 significant digits, which is what
# HubStatisticsReferenceTests records. Run both scripts and compare before changing a value.
#
# - Wilson: prop.test(x, n, conf.level, correct = FALSE)$conf.int, the Wilson score interval
#   without continuity correction. `binom::binom.wilson` is not used because `binom` is not a
#   base package.
# - MAD: mad(x, constant = 1) (raw), mad(x) (R's rounded constant 1.4826), and
#   mad(x, constant = 1 / qnorm(3/4)) (the exact normal-consistency constant BusinessMath uses).
# - Poisson upper tail P(X >= k): ppois(k - 1, lambda, lower.tail = FALSE).

fmt <- function(v) formatC(v, digits = 17, format = "g")

cat("# wilson\tsuccesses\ttrials\tconfidence\tlower\tupper\n")
wilson <- list(c(0, 10, 0.95), c(1, 10, 0.95), c(10, 10, 0.95), c(0, 5, 0.95),
               c(3, 1000, 0.95), c(1, 1, 0.95), c(50, 100, 0.95), c(999, 1000, 0.95),
               c(7, 20, 0.90), c(7, 20, 0.99))
for (w in wilson) {
  ci <- suppressWarnings(prop.test(w[1], w[2], conf.level = w[3], correct = FALSE)$conf.int)
  cat("wilson", w[1], w[2], w[3], fmt(ci[1]), fmt(ci[2]), sep = "\t")
  cat("\n")
}

cat("# mad\tname\traw\tR1.4826\texact\n")
mads <- list(
  outlier = c(1, 2, 3, 4, 100),
  even = c(1, 2, 3, 4),
  single = c(7),
  constant = c(5, 5, 5),
  signed = c(-3.5, 2.25, 0, 10, -1, 4.75),
  lowCounts = c(0, 0, 1, 0, 2, 0, 0, 1, 0, 0, 0, 3, 0, 1),
  overdispersed = c(3, 8, 1, 12, 4, 0, 6, 15, 2, 5, 9, 1, 7, 3)
)
for (name in names(mads)) {
  x <- mads[[name]]
  cat("mad", name, fmt(mad(x, constant = 1)), fmt(mad(x)), fmt(mad(x, constant = 1 / qnorm(3 / 4))),
      sep = "\t")
  cat("\n")
}

cat("# poisson\tk\tlambda\tsurvival\n")
poisson <- list(c(0, 3), c(0, 0), c(1, 0), c(1, 0.5), c(3, 1), c(5, 1), c(5, 0.1), c(10, 2),
                c(8, 2), c(12, 3), c(15, 10), c(20, 10), c(25, 10), c(1, 50), c(20, 1),
                c(30, 2), c(40, 5), c(60, 10), c(900, 1000), c(1000, 1000), c(1100, 1000),
                c(1200, 1000), c(101000, 100000), c(50, 0.001))
for (p in poisson) {
  cat("poisson", p[1], p[2], fmt(ppois(p[1] - 1, p[2], lower.tail = FALSE)), sep = "\t")
  cat("\n")
}
