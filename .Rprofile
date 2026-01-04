## ----------------------------
## Core safety and hygiene
## ----------------------------

options(
  stringsAsFactors = FALSE,
  save.image = FALSE,
  history = FALSE,
  warn = 1
)

## ----------------------------
## Formatting
## ----------------------------

options(styler.width.cutoff = 80)

## ----------------------------
## Reproducibility and numerics
## ----------------------------

options(
  scipen = 999,
  digits = 7
)

## ----------------------------
## Error handling and debugging
## ----------------------------

options(error = function() {
  traceback(2)
  if (interactive()) browser()
})

## ----------------------------
## Package management
## ----------------------------

options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  install.packages.check.source = "yes",
  renv.consent = TRUE
)

## ----------------------------
## Console ergonomics
## ----------------------------

options(
  width = 100,
  max.print = 2000,
  encoding = "UTF-8"
)

## ----------------------------
## Locale stability
## ----------------------------

try(Sys.setlocale("LC_ALL", "C"), silent = TRUE)

## ----------------------------
## RStudio-specific behavior
## ----------------------------

if (Sys.getenv("RSTUDIO") == "1") {
  options(
    rstudio.console.confirm.remove_objects = FALSE
  )
}
