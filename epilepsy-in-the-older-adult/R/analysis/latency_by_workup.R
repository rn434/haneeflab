# latency_by_index_dx.R
# ----------------
# This file contains an analysis of diagnostic latency depending on the
# diagnostic workup received by the patient.

make_combo_label <- function(all_cols, included_cols) {
  paste(
    ifelse(all_cols %in% included_cols,
      paste0("+", gsub("Done$", "", all_cols)),
      paste0("-", gsub("Done$", "", all_cols))
    ),
    collapse = ","
  )
}

make_latency_by_workup_table <- function(
  data,
  all_tests,
  tests_to_combine
) {
  all_workup_cols <- stringr::str_c(stringr::str_to_title(all_tests), "Done")
  workup_cols_to_combine <- stringr::str_c(stringr::str_to_title(tests_to_combine), "Done")
  
  individual_rows <- purrr::map_dfr(all_workup_cols, function(col) {
    median_cols <- data %>%
      dplyr::filter(.data$LatencyFlag) %>%
      dplyr::filter(.data[[col]]) %>%
      calculate_median_latency_by_age_group() %>%
      make_median_latency_cols()

    tibble::tibble(
      Workup = gsub("Done$", "", col),
      !!!median_cols,
      p_value = tryCatch(
        kruskal.test(Latency ~ AgeGroup, data = data)$p.value,
        error = function(e) NA_real_
      )
    )
  })

  combo_sets <- unlist(
    lapply(seq_along(workup_cols_to_combine), function(k) {
      combn(workup_cols_to_combine, k, simplify = FALSE)
    }),
    recursive = FALSE
  )

  combo_rows <- purrr::map_dfr(combo_sets, function(included_cols) {
    excluded_cols <- setdiff(workup_cols_to_combine, included_cols)

    median_cols <- data %>%
      dplyr::filter(.data$LatencyFlag) %>%
      dplyr::filter(
        dplyr::if_all(dplyr::all_of(included_cols), ~ .x == TRUE),
        dplyr::if_all(dplyr::all_of(excluded_cols), ~ .x == FALSE)
      ) %>%
      calculate_median_latency_by_age_group() %>%
      make_median_latency_cols()

    tibble::tibble(
      Workup = make_combo_label(workup_cols_to_combine, included_cols),
      !!!median_cols,
      p_value = tryCatch(
        kruskal.test(Latency ~ AgeGroup, data = data)$p.value,
        error = function(e) NA_real_
      )
    )
  })

  dplyr::bind_rows(individual_rows, combo_rows) %>%
    gt::gt() %>%
    gt::fmt(
      columns = c("p_value"),
      fns = function(x) ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
    ) %>%
    gt::cols_label(
      Workup = "Workup",
      p_value = "p"
    ) %>%
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    )
}
