# latency_by_index_dx.R
# ----------------
# This file contains an analysis of diagnostic latency, with stratification
# by the index diagnosis.

make_latency_by_index_dx_table <- function(data) {
  index_dx_rows <- data %>%
    dplyr::filter(.data$LatencyFlag) %>%
    dplyr::group_by(.data$IndexDx) %>%
    dplyr::group_modify(~ {
      median_latency <- calculate_median_latency_by_age_group(.x)
      median_cols <- make_median_latency_cols(median_latency)
      kw <- kruskal.test(Latency ~ AgeGroup, data = .x)
      tibble::tibble(
        !!!median_cols,
        p_value = kw$p.value
      )
    }) %>%
    dplyr::ungroup() %>%
    dplyr::select("IndexDx", dplyr::everything())

  overall_row <- data %>%
    dplyr::filter(.data$LatencyFlag) %>%
    dplyr::mutate(IndexDx = "Overall") %>%
    dplyr::group_by(.data$IndexDx) %>%
    dplyr::group_modify(~ {
      median_latency <- calculate_median_latency_by_age_group(.x)
      median_cols <- make_median_latency_cols(median_latency)
      kw <- kruskal.test(Latency ~ AgeGroup, data = .x)
      tibble::tibble(
        !!!median_cols,
        p_value = kw$p.value
      )
    }) %>%
    dplyr::ungroup() %>%
    dplyr::select("IndexDx", dplyr::everything())
    # dplyr::filter(.data$LatencyFlag) %>%
    # calculate_median_latency_by_age_group() %>%
    # make_median_latency_cols() %>%
    # dplyr::mutate(
    #   IndexDx = "Overall",
    #   p_value = kruskal.test(Latency ~ AgeGroup, data = data %>% dplyr::filter(.data$LatencyFlag))$p.value
    # ) %>%
    # dplyr::select("IndexDx", dplyr::everything())

  dplyr::bind_rows(index_dx_rows, overall_row) %>%
    gt::gt() %>%
    gt::fmt(
      columns = c("p_value"),
      fns = function(x) ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
    ) %>%
    gt::cols_label(
      IndexDx = "Diagnosis",
      p_value = "p"
    ) %>%
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    )
}

make_bubble_plot <- function(data) {
  median_latency_summary <- data %>%
    dplyr::filter(.data$LatencyFlag) %>%
    dplyr::group_by(.data$AgeGroup, .data$IndexDx) %>%
    dplyr::summarise(
      n_patients = dplyr::n(),
      median_latency = median(.data$Latency),
      .groups = "drop"
    ) %>%
    dplyr::group_by(.data$AgeGroup) %>%
    dplyr::mutate(pct_patients = 100 * .data$n_patients / sum(.data$n_patients)) %>%
    dplyr::ungroup()

  median_latency_summary %>%
    ggplot2::ggplot(ggplot2::aes(x = stringr::str_wrap(IndexDx, width = 10), y = median_latency, size = pct_patients, color = AgeGroup)) +
    ggplot2::geom_point(alpha = 0.6) +
    ggplot2::geom_point(ggplot2::aes(color = AgeGroup, fill = AgeGroup), shape = 21, size = 1.5, stroke = 0.1, show.legend = FALSE) +
    ggrepel::geom_text_repel(ggplot2::aes(label = sprintf("%.1f%%", pct_patients)),
      size = 4, show.legend = FALSE, max.overlaps = Inf,
      box.padding = 0.4, point.padding = 0.5
    ) +
    ggplot2::scale_size(range = c(6, 30), name = "Percent of Patients in Age Group") +
    ggplot2::scale_y_continuous(limits = c(0, 25)) +
    epilepsy_fill_scale() + 
    epilepsy_color_scale() +
    ggplot2::labs(x = "Index Diagnosis", y = "Median Diagnostic\nDelay (months)", color = "Age at Onset (years)") +
    ggplot2::theme(
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 15)),
      panel.grid.minor = ggplot2::element_blank()
    ) +
    ggplot2::guides(size = "none")
}
