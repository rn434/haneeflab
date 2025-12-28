# summary.R
# ----------------
# This file contains basic summary analyses.

make_summary_table <- function(data) {
  data %>%
    dplyr::select(
      "Age",
      "Sex",
      "Race",
      "Ethnicity",
      "AgeGroup"
    ) %>%
    gtsummary::tbl_summary(
      by = "AgeGroup",
      # missing = "ifany",
      missing = "no",
      statistic = list(
        gtsummary::all_continuous() ~ "{mean} ({sd})",
        gtsummary::all_categorical() ~ "{n} ({p})"
      ),
      digits = list(
        gtsummary::all_continuous() ~ c(1, 1),
        gtsummary::all_categorical() ~ c(0, 2)
      )
    ) %>%
    gtsummary::add_stat_label() %>%
    gtsummary::add_p(
      test = list(
        gtsummary::all_continuous() ~ "kruskal.test",
        gtsummary::all_categorical() ~ "chisq.test"
      )
    ) %>%
    gtsummary::as_gt()
}
