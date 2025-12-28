# latency_by_age.R
# ----------------
# This file contains an analysis of diagnostic latency, strictly based on age
# at index episode.

make_latency_proportion_table_and_plot <- function(data) {
  latency_proportion_table <- data %>%
    dplyr::group_by(.data$AgeGroup) %>%
    dplyr::summarise(
      n = dplyr::n(),
      n_latency = sum(.data$LatencyFlag, na.rm = TRUE),
      proportion = n_latency / n,
      lower = binom.test(n_latency, n)$conf.int[1],
      upper = binom.test(n_latency, n)$conf.int[2]
    )

  latency_proportion_plot <- latency_proportion_table %>%
    ggplot2::ggplot(ggplot2::aes(x = AgeGroup, y = proportion, fill = AgeGroup)) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = lower, ymax = upper),
      width = 0.2,
      linewidth = 0.8
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(),
      limits = c(0, .3)
    ) +
    ggplot2::labs(
      x = "Age at Onset (years)",
      y = "Proportion Experiencing\nDiagnostic Latency"
    ) +
    ggplot2::theme(legend.position = "none") +
    epilepsy_fill_scale()

  list(
    table = latency_proportion_table %>% gt::gt(), 
    plot = latency_proportion_plot
  )
}

make_latency_median_table_and_plot <- function(data) {
  latency_median_table <- data %>%
    dplyr::filter(.data$LatencyFlag) %>%
    dplyr::group_by(.data$AgeGroup) %>%
    dplyr::summarise(
      out = list(median_bootstrap((.data$Latency)))
    ) %>%
    tidyr::unnest("out")

  latency_median_plot <- latency_median_table %>%
    ggplot2::ggplot(ggplot2::aes(x = AgeGroup, y = median, fill = AgeGroup)) +
    ggplot2::geom_col(ggplot2::aes(y = median), width = 0.6) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0.2) +
    ggplot2::scale_y_continuous(limits = c(0, 15)) +
    ggplot2::labs(
      x = "Age at Onset (years)",
      y = "Median Diagnostic\nLatency (months)"
    ) +
    ggplot2::theme(legend.position = "none") +
    epilepsy_fill_scale()

  list(
    table = latency_median_table %>% gt::gt(), 
    plot = latency_median_plot
  )
}


make_latency_boxplot <- function(data) {
  data %>%
    dplyr::filter(.data$LatencyFlag) %>%
    ggplot2::ggplot(ggplot2::aes(x = AgeGroup, y = Latency)) +
    ggplot2::geom_boxplot(ggplot2::aes(fill = AgeGroup), width = 0.6, color = "black") +
    ggplot2::labs(
      x = "Age at Onset (years)",
      y = "Diagnostic Latency (months)"
    ) +
    ggplot2::theme(legend.position = "none") +
    epilepsy_fill_scale()
}

make_latency_binned_proportion_table_and_plot <- function(data) {
  bin_size <- 5

  data_binned <- data %>%
    dplyr::mutate(age_bin = cut(
      .data$Age,
      breaks = seq(20, 90, by = bin_size),
      right = FALSE,
      include.lowest = TRUE
    ))

  latency_binned_proportion_table <- data_binned %>%
    dplyr::group_by(.data$age_bin) %>%
    dplyr::summarise(
      n = dplyr::n(),
      n_latency = sum(.data$LatencyFlag, na.rm = TRUE),
      proportion = n_latency / n,
      lower = binom.test(n_latency, n)$conf.int[1],
      upper = binom.test(n_latency, n)$conf.int[2]
    ) %>%
    dplyr::mutate(age_mid = as.numeric(sub("\\[(.+),.*", "\\1", .data$age_bin)) + bin_size / 2)

  latency_binned_proportion_plot <- latency_binned_proportion_table %>%
    ggplot2::ggplot(ggplot2::aes(x = age_mid, y = proportion)) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = lower, ymax = upper),
      width = 0.2,
      linewidth = 0.8
    ) +
    ggplot2::geom_point(size = 2, color = "steelblue") +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(),
      limits = c(0, .3)
    ) +
    ggplot2::labs(
      x = "Age at Onset (years)",
      y = "Proportion Experiencing\nDiagnostic Latency"
    ) +
    ggplot2::theme(legend.position = "none")

  list(
    table = latency_binned_proportion_table %>% gt::gt(), 
    plot = latency_binned_proportion_plot
  )
}

make_latency_binned_median_table_and_plot <- function(data) {
  bin_size <- 5

  data_binned <- data %>%
    dplyr::mutate(age_bin = cut(
      .data$Age,
      breaks = seq(20, 90, by = bin_size),
      right = FALSE,
      include.lowest = TRUE
    ))

  latency_binned_median_table <- data_binned %>%
    dplyr::filter(.data$LatencyFlag) %>%
    dplyr::group_by(.data$age_bin) %>%
    dplyr::summarise(
      out = list(median_bootstrap((.data$Latency)))
    ) %>%
    tidyr::unnest("out") %>%
    dplyr::mutate(age_mid = as.numeric(sub("\\[(.+),.*", "\\1", .data$age_bin)) + bin_size / 2)

  latency_binned_median_plot <- latency_binned_median_table %>%
    ggplot2::ggplot(ggplot2::aes(x = age_mid, y = median)) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0.8, linewidth = 0.8, color = "steelblue") +
    ggplot2::geom_point(size = 2, color = "steelblue") +
    ggplot2::labs(
      x = "Age at Onset (years)",
      y = "Median Diagnostic\nLatency (months)"
    )

  list(
    table = latency_binned_median_table %>% gt::gt(), 
    plot = latency_binned_median_plot
  )
}
