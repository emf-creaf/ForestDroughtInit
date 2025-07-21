write_medfateland_object <- function(processed_data, res) {
  # abort if null before anything
  if (is.null(processed_data)) {
    cli::cli_abort("No data")
  }
  # get the province and ifn version from the file name
  province <- substr(processed_data$sf$id, 1, 2) |>
    unique()

  # file name
  output_filename_rds <- paste0("data/medfateland_", province_code, "_sf_",res,"m.rds")

  # write the object
  # log
  cli::cli_inform(c(
    "i" = "Writing RDS data for province {province}"
  ))
  processed_data$sf |>
    dplyr::as_tibble() |>
    saveRDS(output_filename_rds)
  return(output_filename_rds)
}

write_medfateland_raster <- function(processed_data, res) {
  # abort if null before anything
  if (is.null(processed_data)) {
    cli::cli_abort("No data")
  }
  # get the province and ifn version from the file name
  province <- substr(processed_data$sf$id, 1, 2) |>
    unique()
  
  # file name
  output_filename_tif <- paste0("data/medfateland_", province_code, "_raster_",res,"m.tif")
  
  # write the object
  # log
  cli::cli_inform(c(
    "i" = "Writing raster data for province {province}"
  ))

  processed_data$r |>
    dplyr::as_tibble() |>
    saveRDS(output_filename_tif)
  
  return(output_filename_tif)
}