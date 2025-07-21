source("R/init_province_medfateland.R")

res <- 1000
buffer_dist <- 50000
emf_dataset_path <- "~/datasets/"
test_plots <- TRUE

provinces <- sample(c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
               as.character(11:50)))
provinces <- provinces[-c(35, 38)]

for(province_code in provinces) {
  out_sf <- paste0("data/medfateland_", province_code, "_sf.rds")
  if(!file.exists(out_sf)) {
    cli::cli_h1(paste0("Processing province ", province_code))
    ifn_imputation_source <- "IFN4"
    ifn_file <- paste0(emf_dataset_path, "ForestInventories/IFN_medfateland/medfateland_",
                       tolower(ifn_imputation_source), "_",province_code,"_soilmod_WGS84.rds")
    if(!file.exists(ifn_file)) ifn_imputation_source = "IFN3"
    l <- init_province_medfateland(province_code = province_code,
                                   emf_dataset_path = emf_dataset_path,
                                   res = res,
                                   buffer_dist = buffer_dist,
                                   ifn_imputation_source = ifn_imputation_source)
    
    saveRDS(l$sf, out_sf)
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
}
