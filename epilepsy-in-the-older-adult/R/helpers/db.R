# db.R
# ----------------
# This sets up the database connection to CDW for QI projects using
# SCS_EEGUtil.


connect_scs_eegutil <- function(
  server = "vhacdwrb03.vha.med.va.gov",
  database = "SCS_EEGUtil",
  driver = "{SQL Server}"
) {
  tryCatch(
    {
      RODBC::odbcDriverConnect(
        paste0(
          "driver=", driver, ";",
          "server=", server, ";",
          "database=", database, ";",
          "trusted_connection=true"
        )
      )
    },
    warning = function(w) {
      message("Not connected to VA network.")
      NULL
    },
    error = function(e) {
      message("Not connected to VA network.")
      NULL
    }
  )
}
