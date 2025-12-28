# data/load.R
# ----------------
# This file defines functions to load raw data for the `epilepsy in the older
# adult` project


build_select_query <- function(
  table
) {
  sprintf(
    "SELECT * FROM %s",
    table
  )
}

load_tables <- function(conn, tables) {
  if (is.null(conn)) {
    stop("Not connected to VA network")
  }

  raw <- purrr::imap(
    tables,
    ~ {
      query <- build_select_query(.x)
      RODBC::sqlQuery(conn, query, as.is = TRUE)
    }
  )

  raw
}
