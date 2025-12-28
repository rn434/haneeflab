# utils.R
# ----------------
# This file contains convenience functions.



install_packages <- function(pkgs) {
  installed <- pkgs %in% rownames(installed.packages())
  if (any(!installed)) {
    install.packages(pkgs[!installed], type = "binary")
  }
}

