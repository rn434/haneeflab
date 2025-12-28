# save.R
# ----------------
# This file contains personal patches of ggsave and gtsave to facilitate
# analysis.

my_ggsave <- function(figure, filename = NULL, ...) {
  if (is.null(filename)) {
    fig_sym <- rlang::ensym(figure)
    if (!rlang::is_symbol(fig_sym)) {
      rlang::abort(
        "Figure must be a named object or you must supply `filename=`."
      )
    }
    filename <- gsub("_", "-", rlang::as_string(fig_sym))
  }

  out_dir <- "../results"
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }
  out_path <- file.path(out_dir, paste0(filename, ".pdf"))

  if (file.exists(out_path)) {
    invisible(file.remove(out_path))
  }
  ggplot2::ggsave(filename = out_path, plot = figure, ...)
}

my_gtsave <- function(table, filename = NULL, ...) {
  if (is.null(filename)) {
    tbl_sym <- rlang::ensym(table)
    if (!rlang::is_symbol(tbl_sym)) {
      rlang::abort(
        "Table must be a named object or you must supply `filename=`."
      )
    }
    filename <- gsub("_", "-", rlang::as_string(tbl_sym))
  }

  out_dir <- "../results"
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }
  out_path <- file.path(out_dir, paste0(filename, ".docx"))

  if (file.exists(out_path)) {
    invisible(file.remove(out_path))
  }
  gt::gtsave(data = table, filename = out_path, ...)
}
