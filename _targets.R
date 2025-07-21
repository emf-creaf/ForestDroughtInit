
# Load packages required to define the pipeline:
library(targets)
library(tarchetypes)
library(crew)
library(stringr)

# Set target options:
tar_option_set(
  packages = c("tibble", "sf", "medfate", "medfateland", "terra", "dplyr", "cli"),
  format = "qs",
  memory = "transient",
  # Workers to be changed in server:
  controller = crew::crew_controller_local(workers = 10),
  iteration = "list"
)

tar_source("R/init_province_medfateland.R")
tar_source("R/write_medfateland_objects.R")

emf_dataset_path <- "~/datasets/"
provinces <- seq(1, 50) |>
  as.character() |>
  stringr::str_pad(2, "left", "0")
provinces <- provinces[-c(35, 38)]
res <- 1000

list(
  tar_target(input_provinces, provinces),
  tar_target(
    processed_data, init_province_medfateland(emf_dataset_path = emf_dataset_path,
                                              province_code = input_provinces,
                                              res = res),
    pattern = map(input_provinces),
    error = "null"
  ),
  tar_target(
    written_object_files, write_medfateland_object(processed_data, res = res),
    pattern = map(processed_data),
    format = "file",
    error = "null"
  ),
  tar_target(
    written_tif_files, write_medfateland_raster(processed_data, res = res),
    pattern = map(processed_data),
    format = "file",
    error = "null"
  )
)