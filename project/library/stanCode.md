transformed data {
  int N = 100;
  real a_true = 0.2;
  real b_true = 0.3;
  real sigma_true = 0.2;
  vector[N] x;
  vector[N] y;
   for (n in 1:N) {
    x[n] = uniform_rng(0, 10);
    y[n] = normal_rng(1 / (a_true + b_true * x[n]), sigma_true);
  }
}
parameters {
  real<lower=0> a, b, sigma;
}
model {
  a ~ normal(0, 1);
  b ~ normal(0, 1);
  for (n in 1:N) {
    y[n] ~ normal(1 / (a + b * x[n]), sigma);
  }
}
