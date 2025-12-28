# median.R
# ----------------
# This file contains helper functions for median calculation with bootstrap
# estimation.

median_bootstrap <- function(x, n_bootstrap = 5000, seed = 123) {
  set.seed(seed)
  n <- length(x)

  b <- boot::boot(
    x,
    statistic = function(data, i) median(data[i]),
    R = n_bootstrap
  )

  ci <- boot::boot.ci(b, type = "perc")

  tibble::tibble(
    n = n,
    median = median(x),
    lower = ci$percent[4],
    upper = ci$percent[5]
  )
}

calculate_median_latency_by_age_group <- function(data) {
  data %>%
    dplyr::group_by(.data$AgeGroup) %>%
    dplyr::summarise(
      out = list(median_bootstrap(.data$Latency)),
      .groups = "drop"
    ) %>%
    tidyr::unnest("out")
}

make_median_latency_cols <- function(median_bootstrap_summary) {
  median_bootstrap_summary %>%
    dplyr::mutate(
      Label = glue::glue(
        "{sprintf('%.1f', median)} ",
        "(n = {format(n, big.mark = ',')})"
      )
    ) %>%
    dplyr::select("AgeGroup", "Label") %>%
    tidyr::pivot_wider(
      names_from = AgeGroup,
      values_from = Label
    )
}
