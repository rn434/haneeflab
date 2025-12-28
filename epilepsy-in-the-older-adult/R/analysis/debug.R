conduct_latency_by_workup_quantile_regression <- function(data, test_cols) {
  age_levels <- levels(data$AgeGroup)

  rhs <- paste("AgeGroup * (", paste(test_cols, collapse = " + "), ")", sep = "")
  formula <- as.formula(paste("Latency ~", rhs))

  fit <- quantreg::rq(
    formula,
    tau = 0.5,
    data = dplyr::filter(data, rlang::.data$LatencyFlag)
  )

  coef_ci <- summary(fit, se = "boot")$coefficients
  coef_names <- names(quantreg::coef(fit))

  pred_grid <- purrr::map_dfr(test_cols, function(test_col) {
    tidyr::expand_grid(AgeGroup = age_levels) %>%
      dplyr::mutate(dplyr::across(dplyr::all_of(test_cols), ~FALSE)) %>%
      dplyr::mutate(!!test_col := TRUE, test = test_col)
  }) %>%
    dplyr::mutate(AgeGroup = factor(rlang::.data$AgeGroup, levels = age_levels))

  pred_grid <- dplyr::mutate(pred_grid,
    pred = purrr::pmap_dbl(
      dplyr::select(., rlang::.data$AgeGroup, dplyr::all_of(test_cols)),
      function(...) {
        newrow <- tibble::tibble(..., .rows = 1)
        predict(fit, newdata = newrow)
      }
    )
  ) %>%
    mutate(
      lower = purrr::pmap_dbl(
        dplyr::select(., rlang::.data$AgeGroup, dplyr::all_of(test_cols)),
        function(...) {
          X <- model.matrix(formula, data = tibble::tibble(..., .rows = 1))
          sum(X * coef_ci[coef_names, "Lower"])
        }
      ),
      upper = purrr::pmap_dbl(
        dplyr::select(., rlang::.data$AgeGroup, dplyr::all_of(test_cols)),
        function(...) {
          X <- model.matrix(formula, data = tibble::tibble(..., .rows = 1))
          sum(X * coef_ci[coef_names, "Upper"])
        }
      )
    )

  test_labels <- c(
    CTDone = "CT Head",
    MRIDone = "MRI Head",
    EEGDone = "EEG",
    HolterDone = "Ambulatory\nECG",
    TiltDone = "Tilt Table"
  )

  quantile_regression_plot <- ggplot2::ggplot(pred_grid, ggplot2::aes(x = AgeGroup, y = pred)) +
    ggplot2::geom_col(ggplot2::aes(fill = AgeGroup), width = 0.6) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0.2, linewidth = 0.7) +
    ggplot2::facet_wrap(~test, labeller = ggplot2::as_labeller(test_labels), ncol = 5) +
    ggplot2::labs(
      x = "Epilepsy Onset",
      y = "Predicted Median Diagnostic Delay (months)",
      fill = "Group"
    ) +
    ggplot2::theme(
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 15)),
      legend.position = "top",
      strip.text = ggplot2::element_text(face = "bold")
    )

  list(
    model = fit,
    predictions = pred_grid,
    plot = quantile_regression_plot
  )
}

# conduct_latency_by_workup_quantile_regression <- function(data, test_cols) {
#   fit <- quantreg::rq(
#     Latency ~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone),
#     tau = 0.5,
#     data = data %>% dplyr::filter(rlang::.data$LatencyFlag)
#   )
#
#   coef_ci <- summary(fit, se = "boot")$coefficients
#   coef_names <- names(coef(fit))
#
#   pred_grid <- purrr::map_dfr(tests, function(test_col) {
#     tidyr::expand_grid(AgeGroup = age_levels) %>%
#       dplyr::mutate(
#         CTDone = FALSE,
#         MRIDone = FALSE,
#         EEGDone = FALSE,
#         HolterDone = FALSE,
#         TiltDone = FALSE,
#         !!test_col := TRUE,
#         test = test_col
#       )
#   }) %>%
#     dplyr::mutate(AgeGroup = factor(AgeGroup, levels = age_levels))
#
#   pred_grid <- pred_grid %>%
#     rowwise() %>%
#     mutate(pred = predict(fit, newdata = cur_data())) %>%
#     ungroup()
#
#   pred_grid <- pred_grid %>%
#     rowwise() %>%
#     mutate(
#       lower = {
#         X <- model.matrix(~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone), data = cur_data())
#         sum(X * coef_ci[coef_names, "Lower"])
#       },
#       upper = {
#         X <- model.matrix(~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone), data = cur_data())
#         sum(X * coef_ci[coef_names, "Upper"])
#       }
#     ) %>%
#     ungroup()
#
#   test_labels <- setNames(
#     c("CT Head", "MRI Head", "EEG", "Ambulatory\nECG", "Tilt Table"),
#     c("CTDone", "MRIDone", "EEGDone", "HolterDone", "TiltDone")
#   )
#
#   quantile_regression_plot <- ggplot2::ggplot(pred_grid, ggplot2::aes(x = AgeGroup, y = pred)) +
#     ggplot2::geom_col(ggplot2::aes(fill = AgeGroup), width = 0.6) +
#     ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0.2, linewidth = 0.7) +
#     ggplot2::facet_wrap(~test, labeller = ggplot2::as_labeller(test_labels), ncol = 5) +
#     ggplot2::labs(
#       x = "Epilepsy Onset",
#       y = "Predicted Median Diagnostic Delay (months)",
#       fill = "Group"
#     ) +
#     ggplot2::theme(
#       axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 15)),
#       legend.position = "top",
#       strip.text = ggplot2::element_text(face = "bold")
#     )
#
#   list(
#     model = fit,
#     predictions = pred_grid,
#     plot = quantile_regression_plot
#   )
# }
#
# conduct_latency_by_workup_quantile_regression <- function(data, test_cols) {
#   fit <- quantreg::rq(
#     Latency ~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone),
#     tau = 0.5,
#     data = data %>% filter(rlang::.data$LatencyFlag)
#   )
#
#   baseline <- tinyr::expand_grid(
#     AgeGroup = levels(data$AgeGroup)
#   ) %>%
#     dplyr::mutate(
#       CTDone = FALSE,
#       MRIDone = FALSE,
#       EEGDone = FALSE,
#       HolterDone = FALSE,
#       TiltDone = FALSE,
#       pred = predict(fit, newdata)
#     ) %>%
#     dplyr::select("AgeGroup", "pred")
#
#   newdata <- purrr::map_dfr(test_cols, function(t) {
#     tinyr::expand_grid(
#       AgeGroup = levels(data$AgeGroup)
#     ) %>%
#       dplyr::mutate(
#         CTDone = FALSE,
#         MRIDone = FALSE,
#         EEGDone = FALSE,
#         HolterDone = FALSE,
#         TiltDone = FALSE,
#         !!paste0(t, "Done") := rlang::.data$test_done,
#         test = t
#       )
#   }) %>%
#     dplyr::mutate(
#       test = factor(rlang::.data$test, levels = test_cols),
#       AgeGroup = factor(rlang::.data$AgeGroup, levels = c("18-44", "45-64", "65+")),
#       pred = predict(fit, newdata)
#     )
#
#
#   ci <- summary(fit, se = "boot")$coefficients
#
#   test_labels <- c(
#     CT = "CT Head",
#     MRI = "MRI Head",
#     EEG = "EEG",
#     Holter = "Ambulatory\nECG",
#     Tilt = "Tilt Table"
#   )
#   quantile_regression <- ggplot(newdata, aes(x = AgeGroup, y = pred)) +
#     geom_col(aes(fill = AgeGroup), width = 0.6) +
#     geom_hline(data = baseline, aes(yintercept = pred, color = AgeGroup), linetype = "dashed", linewidth = 0.7) +
#     facet_wrap(~test, labeller = as_labeller(test_labels), ncol = 5) +
#     scale_fill_manual(values = epilepsy_colors) +
#     scale_color_manual(values = epilepsy_colors) +
#     guides(color = "none") +
#     labs(
#       x = "Epilepsy Onset",
#       y = "Predicted Median\nDiagnostic Delay (months)",
#       fill = "Group",
#       title = "Predicted Diagnostic Delay\nby Diagnostic Test",
#       subtitle = "Dashed line = predicted delay when no tests are performed"
#     ) +
#     theme(
#       axis.title.y = element_text(margin = margin(r = 15)),
#       legend.position = "top",
#       strip.text = element_text(face = "bold")
#     )
# }
#
#
# conduct_latency_by_workup_quantile_regression <- function(data, tests, epilepsy_colors) {
#   library(dplyr)
#   library(tidyr)
#   library(ggplot2)
#   library(quantreg)
#
#   age_levels <- levels(data$AgeGroup)
#
#   # ---- Fit quantile regression ---------------------------------------------
#   fit <- quantreg::rq(
#     Latency ~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone),
#     tau = 0.5,
#     data = data %>% filter(LatencyFlag)
#   )
#
#   # ---- Coefficient CIs -----------------------------------------------------
#   coef_ci <- summary(fit, se = "boot")$coefficients
#   coef_names <- names(coef(fit))
#
#   # ---- Construct prediction grid -------------------------------------------
#
#   # ---- Predicted medians ---------------------------------------------------
#   pred_grid <- pred_grid %>%
#     rowwise() %>%
#     mutate(pred = predict(fit, newdata = cur_data())) %>%
#     ungroup()
#
#   # ---- Approximate prediction CIs ------------------------------------------
#   pred_grid <- pred_grid %>%
#     rowwise() %>%
#     mutate(
#       lower = {
#         X <- model.matrix(~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone), data = cur_data())
#         sum(X * coef_ci[coef_names, "Lower"])
#       },
#       upper = {
#         X <- model.matrix(~ AgeGroup * (CTDone + MRIDone + EEGDone + HolterDone + TiltDone), data = cur_data())
#         sum(X * coef_ci[coef_names, "Upper"])
#       }
#     ) %>%
#     ungroup()
#
#   # ---- Plot ----------------------------------------------------------------
#   test_labels <- setNames(
#     c("CT Head", "MRI Head", "EEG", "Ambulatory\nECG", "Tilt Table"),
#     c("CTDone", "MRIDone", "EEGDone", "HolterDone", "TiltDone")
#   )
#
#   quantile_regression_plot <- ggplot2::ggplot(pred_grid, ggplot2::aes(x = AgeGroup, y = pred)) +
#     ggplot2::geom_col(ggplot2::aes(fill = AgeGroup), width = 0.6) +
#     ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0.2, linewidth = 0.7) +
#     ggplot2::facet_wrap(~test, labeller = ggplot2::as_labeller(test_labels), ncol = 5) +
#     ggplot2::scale_fill_manual(values = epilepsy_colors) +
#     ggplot2::labs(
#       x = "Epilepsy Onset",
#       y = "Predicted Median Diagnostic Delay (months)",
#       fill = "Group",
#       title = "Predicted Diagnostic Delay by Diagnostic Test",
#       subtitle = "Bars = predicted median; error bars = 95% bootstrap CI of coefficients"
#     ) +
#     ggplot2::theme(
#       axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 15)),
#       legend.position = "top",
#       strip.text = ggplot2::element_text(face = "bold")
#     )
#
#   # ---- Return --------------------------------------------------------------
#   list(
#     tidy_predictions = pred_grid,
#     plot = quantile_regression_plot,
#     model = fit
#   )
# }
