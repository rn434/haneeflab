# main.R
# ---------------------------------
# Runner file for epilepsy in the older adult project.

source("helpers/operators.R")
source("helpers/utils.R")
install_packages(c(
  "broom", "boot", "cowplot", "data.table", "ggfortify", "ggpubr", "ggrepel", "ggsci",
  "glue", "gtsummary", "patchwork", "quantreg", "ranger", "RODBC", "scales"
))

source("helpers/theme.R")
ggplot2::theme_set(epilepsy_theme())
epilepsy_colors <- c(
  "EOE" = "#E9D8A6",
  "18-44" = "#E9D8A6",
  "MOE" = "#EE9B00",
  "45-64" = "#EE9B00",
  "LOE" = "#CA6702",
  "65+" = "#CA6702"
)

source("helpers/db.R")
conn <- connect_scs_eegutil()
if (is.null(conn)) stop("Not connected to VA network")

source("data/load.R")
tables <- c(
  epilepsy = "SCS_EEGUtil.EEG.rnEpilepsy",
  index_episodes = "SCS_EEGUtil.EEG.rnIndexEpisode",
  demographics = "SCS_EEGUtil.EEG.rnDemographics",
  mri = "SCS_EEGUtil.EEG.rnMRI",
  eeg = "SCS_EEGUtil.EEG.rnEEG",
  ct = "SCS_EEGUtil.EEG.rnCT",
  holter = "SCS_EEGUtil.EEG.rnHolterMonitor",
  tilt = "SCS_EEGUtil.EEG.rnTiltTable"
)
raw_data <- load_tables(conn, tables)

source("data/process.R")
tests <- c("mri", "eeg", "ct", "holter", "tilt")
data <- build_final_data(
  raw_data = raw_data, 
  tests = tests
)

source("helpers/save.R")
source("analysis/summary.R")
summary_table <- make_summary_table(data)
print(summary_table)
my_gtsave(summary_table)

source("helpers/median.R")
source("analysis/latency_by_age.R")
with(
  make_latency_proportion_table_and_plot(data),
  {
    latency_proportion_table <<- table
    print(latency_proportion_table)
    my_gtsave(latency_proportion_table)
    
    latency_proportion_plot <<- plot
    print(latency_proportion_plot)
    my_ggsave(latency_proportion_plot)
  }
)

with(
  make_latency_median_table_and_plot(data),
  {
    latency_median_table <<- table
    print(latency_median_table)
    my_gtsave(latency_median_table)
    
    latency_median_plot <<- plot
    print(latency_median_plot)
    my_ggsave(latency_median_plot)
  }
)

latency_boxplot <- make_latency_boxplot(data)
print(latency_boxplot)
my_ggsave(latency_boxplot)

with(
  make_latency_binned_proportion_table_and_plot(data),
  {
    latency_binned_proportion_table <<- table
    print(latency_binned_proportion_table)
    my_gtsave(latency_binned_proportion_table)
    
    latency_binned_proportion_plot <<- plot
    print(latency_binned_proportion_plot)
    my_ggsave(latency_binned_proportion_plot)
  }
)

with(
  make_latency_binned_median_table_and_plot(data),
  {
    latency_binned_median_table <<- table
    print(latency_binned_median_table)
    my_gtsave(latency_binned_median_table)
    
    latency_binned_median_plot <<- plot
    print(latency_binned_median_plot)
    my_ggsave(latency_binned_median_plot)
  }
)

source("analysis/latency_by_index_dx.R")
latency_by_index_dx_table <- make_latency_by_index_dx_table(data)
print(latency_by_index_dx_table)
my_gtsave(latency_by_index_dx_table)

bubble_plot <- make_bubble_plot(data)
print(bubble_plot)
my_ggsave(bubble_plot)

source("analysis/latency_by_workup.R")
latency_by_workup_table <- make_latency_by_workup_table(
  data = data,
  all_tests = tests,
  tests_to_combine = c("mri", "eeg", "ct")
)
print(latency_by_workup_table)
my_gtsave(latency_by_workup_table)

source("analysis/misc.R")