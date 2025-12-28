# theme.R
# ----------------
# This file sets up the ggplot2 theme for the epilepsy in the older adult
# project.

epilepsy_theme <- function(
  base_size = 14,
  base_family = "sans"
) {
  ggplot2::theme_minimal(
    base_size = base_size,
    base_family = base_family
  ) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        size = base_size * 1.25,
        hjust = 0.5,
        margin = ggplot2::margin(b = 10)
      ),
      plot.subtitle = ggplot2::element_text(
        size = base_size * 0.95,
        hjust = 0.5,
        margin = ggplot2::margin(b = 10)
      ),
      plot.caption = ggplot2::element_text(
        size = base_size * 0.8,
        hjust = 1,
        margin = ggplot2::margin(t = 10)
      ),
      axis.title = ggplot2::element_text(face = "bold"),
      axis.text = ggplot2::element_text(size = base_size * 0.9),
      legend.title = ggplot2::element_text(face = "bold"),
      legend.position = "right",
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3),
      panel.spacing = ggplot2::unit(1, "lines")
    )
}

epilepsy_fill_scale <- function() {
  ggplot2::scale_fill_manual(values = epilepsy_colors)
}

epilepsy_color_scale <- function() {
  ggplot2::scale_color_manual(values = epilepsy_colors)
}
