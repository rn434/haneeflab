# misc.R
# ----------------
# This file contains miscellaneous pieces of analysis, usually exploratory.

age_distribution <- function(data) {
  data %>%
    ggplot2::ggplot(ggplot2::aes(x = rlang::.data$Age)) +
    ggplot2::geom_histogram(binwidth = 2, fill = "steelblue", color = "white") +
    ggplot2::labs(
      title = "Age Histogram",
      x = "Age",
      y = "Count"
    )
}

latency_quantile_distribution <- function(data) {
  data %>%
    dplyr::filter(rlang::.data$LatencyFlag == TRUE) %>%
    dplyr::group_by(rlang::.data$AgeGroup) %>%
    dplyr::summarise(
      Q1 = quantile(rlang::.data$Latency, 0.25, na.rm = TRUE),
      Median = quantile(rlang::.data$Latency, 0.50, na.rm = TRUE),
      Q3 = quantile(rlang::.data$Latency, 0.75, na.rm = TRUE),
      .groups = "drop"
    )
}
