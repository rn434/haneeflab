# process.R
# ----------------
# This file transforms raw data into the final dataset for analysis for the `
# epilepsy in the older adult` project

process_epilepsy <- function(raw_epilepsy) {
  raw_epilepsy %>%
    dplyr::mutate(
      DefinitiveEpilepsyDxDate = lubridate::as_date(
        lubridate::parse_date_time(DxDate, orders = "ymd")
      )
    ) %>%
    dplyr::filter(
      .data$DefinitiveEpilepsyDxDate >= as.Date("2005-01-01"),
      .data$DefinitiveEpilepsyDxDate < as.Date("2025-01-01")
    ) %>%
    dplyr::select("PatientICN", "DefinitiveEpilepsyDxDate")
}

process_index_episodes <- function(raw_index_episodes) {
  raw_index_episodes %>%
    dplyr::mutate(dplyr::across(
      -dplyr::all_of(c("PatientICN")),
      ~ lubridate::as_date(lubridate::parse_date_time(.x, orders = "ymd"))
    ))
}


process_demographics <- function(raw_demographics) {
  raw_demographics %>%
    dplyr::mutate(dplyr::across(
      dplyr::all_of(c("BirthDate", "DeathDate")),
      ~ lubridate::as_date(lubridate::parse_date_time(.x, orders = "ymd"))
    )) %>%
    dplyr::mutate(
      Race = dplyr::case_when(
        .data$Race == "WHITE NOT OF HISP ORIG" ~ "WHITE",
        .data$Race == "AMERICAN INDIAN OR ALASKA NATIVE" ~ "NATIVE AMERICAN OR ALASKA NATIVE",
        TRUE ~ .data$Race
      ),
      dplyr::across(
        dplyr::all_of(c("Race", "Ethnicity")),
        ~ dplyr::if_else(.x %in% c("UNKNOWN BY PATIENT", "DECLINED TO ANSWER"), NA, .x)
      )
    )
}

identify_index_episode <- function(
  epilepsy,
  index_episodes,
  demographics,
  index_diagnoses
) {
  combined <- epilepsy %>%
    dplyr::inner_join(index_episodes, by = "PatientICN") %>%
    dplyr::inner_join(demographics, by = "PatientICN") %>%
    dplyr::mutate(dplyr::across(
      dplyr::all_of(index_diagnoses),
      ~ dplyr::case_when(
        !is.na(.) &
          (. >= DefinitiveEpilepsyDxDate - lubridate::years(5)) &
          (. <= DefinitiveEpilepsyDxDate) ~ .,
        TRUE ~ as.Date(NA)
      )
    )) %>%
    dplyr::mutate(TIA = dplyr::if_else(is.na(.data$Stroke), as.Date(.data$TIA), NA)) %>%
    dplyr::select(-"Stroke")

  data.table::setDT(combined)

  combined[, c("IndexDate", "IndexDx") := {
    vals <- unlist(.SD)
    if (all(is.na(vals))) {
      list(NA, NA)
    } else {
      min_val <- min(vals, na.rm = TRUE)
      min_col <- names(.SD)[which.min(vals)]
      list(as.Date(min_val), min_col)
    }
  }, .SDcols = index_diagnoses, by = seq_len(nrow(combined))]

  n_without_index <- combined %>%
    as.data.frame() %>%
    dplyr::filter(is.na(.data$IndexDate)) %>%
    nrow()

  print(paste0("There are ", n_without_index, " Veterans without a 5-year index episode."))

  combined %>%
    as.data.frame() %>%
    dplyr::filter(!is.na(.data$IndexDate))
}

build_tests_data <- function(raw, combined, tests) {
  test_counts <- purrr::map(tests, function(test_name) {
    test_data <- raw[[test_name]]
    
    date_col_name <- names(test_data)[stringr::str_ends(names(test_data), "Date")]
    if (length(date_col_name) != 1) {
      stop(paste0("Test ", test_name, "must have exactly one column ending in \"Date\""))
    }
    date_col <- rlang::sym(date_col_name)
    
    test_data %>%
      dplyr::inner_join(combined, by = "PatientICN") %>%
      dplyr::mutate(
        cutoff = pmin(.data$DefinitiveEpilepsyDxDate, .data$IndexDate %m+% months(6L))
      ) %>%
      dplyr::filter(
        !!date_col >= .data$IndexDate,
        !!date_col <= .data$cutoff
      ) %>%
      dplyr::group_by(.data$PatientICN) %>%
      dplyr::summarise(Count = dplyr::n(), .groups = "drop") %>%
      dplyr::rename(!!paste0(stringr::str_to_title(test_name), "Count") := Count)
  })
  
  purrr::reduce(test_counts, dplyr::full_join, by = "PatientICN") %>%
    dplyr::mutate(
      dplyr::across(dplyr::ends_with("Count"), ~ tidyr::replace_na(.x, 0)),
      dplyr::across(dplyr::ends_with("Count"), ~ .x >= 1, .names = "{sub('Count$', '', .col)}Done")
    ) 
}

group_and_compute_latency <- function(combined) {
  combined %>%
    dplyr::filter(!is.na(.data$BirthDate)) %>%
    dplyr::mutate(
      Age = lubridate::interval(.data$BirthDate, .data$IndexDate) %>% as.numeric("years"),
      AgeGroup = factor(
        dplyr::case_when(
          Age < 45 ~ "18-44",
          Age < 65 ~ "45-64",
          TRUE ~ "65+"
        ),
        levels = c("18-44", "45-64", "65+")
      ),
      Latency = lubridate::interval(.data$IndexDate, .data$DefinitiveEpilepsyDxDate) %>%
        as.numeric("months"),
      LatencyFlag = !(.data$Latency == 0 | .data$IndexDx %in% c("Convulsions", "Epilepsy"))
    )
}


build_final_data <- function(raw_data, tests) {
  epilepsy <- process_epilepsy(raw_data$epilepsy)
  index_episodes <- process_index_episodes(raw_data$index_episodes)
  demographics <- process_demographics(raw_data$demographics)
  index_diagnoses <- setdiff(names(index_episodes), c("PatientICN", "Stroke"))

  combined <- identify_index_episode(
    epilepsy,
    index_episodes,
    demographics,
    index_diagnoses
  )
  tests_data <- build_tests_data(raw_data, combined, tests)

  combined %>%
    dplyr::full_join(tests_data, by = "PatientICN") %>%
    group_and_compute_latency()
}
