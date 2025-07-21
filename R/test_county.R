source("R/init_province_medfateland.R")

comarques <- sf::read_sf("~/OneDrive/EMF_datasets/PoliticalBoundaries/Catalunya/Comarques/comarques.shp")

res <- 1000
buffer_dist <- 50000
emf_dataset_path <- "~/OneDrive/EMF_datasets/"
test_plots <- TRUE

ripolles <- comarques[31,] |>
  sf::st_transform("EPSG:25830")
l <- init_province_medfateland(emf_dataset_path = emf_dataset_path,
                               target_polygon = ripolles,
                               res = res,
                               buffer_dist = buffer_dist,
                               ifn_imputation_source = "IFN4",
                               height_correction = TRUE)


for(province_code in provinces) {
  cli::cli_h1(paste0("Processing province ", province_code))
  ifn_imputation_source <- "IFN4"
  ifn_file <- paste0(emf_dataset_path, "ForestInventories/IFN_medfateland/medfateland_",
                     tolower(ifn_imputation_source), "_",province_code,"_soilmod_WGS84.rds")
  if(!file.exists(ifn_file)) ifn_imputation_source = "IFN3"
  l <- init_province_medfateland(province_code = province_code,
                                 emf_dataset_path = emf_dataset_path,
                                 res = res,
                                 buffer_dist = buffer_dist,
                                 ifn_imputation_source = ifn_imputation_source,
                                 height_correction = TRUE)
  
  saveRDS(l$sf, paste0("data/medfateland_", province_code, "_sf.rds"))
  terra::writeRaster(l$r, paste0("data/medfateland_", province_code, "_raster.tif"), overwrite = TRUE)
  
  if(test_plots) {
    ggplot2::ggsave(paste0("plots/elevation_", province_code, ".png"),
                    medfateland::plot_variable(l$sf, "elevation", r = l$r))
    ggplot2::ggsave(paste0("plots/mean_tree_height_", province_code, ".png"),
                    medfateland::plot_variable(l$sf, "mean_tree_height", r = l$r))
    ggplot2::ggsave(paste0("plots/basal_area_", province_code, ".png"),
                    medfateland::plot_variable(l$sf, "basal_area", r = l$r))
    
  }
}
