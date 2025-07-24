source("R/init_province_medfateland.R")
source("R/write_medfateland_objects.R")

res <- 1000
buffer_dist <- 50000
emf_dataset_path <- "~/datasets/"
test_plots <- TRUE

provinces <- c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
               as.character(11:50))
provinces <- sample(provinces)

for(province_code in provinces) {
  out_sf <- paste0("data/provinces_",res,"m/medfateland_", province_code, "_sf_", res,"m.rds")
  if(!file.exists(out_sf)) {
    cli::cli_h1(paste0("Processing province ", province_code))
    ifn_imputation_source <- "IFN4"
    ifn_file <- paste0(emf_dataset_path, "ForestInventories/IFN_medfateland/medfateland_",
                       tolower(ifn_imputation_source), "_",province_code,"_soilmod_WGS84.rds")
    if(!file.exists(ifn_file)) ifn_imputation_source = "IFN3"
    if(province_code %in% c("35", "38")) {
      l <- init_province_medfateland(province_code = province_code,
                                     emf_dataset_path = emf_dataset_path,
                                     res = res,
                                     buffer_dist = buffer_dist,
                                     crs_out = "EPSG:32628", # UTM 28N
                                     biomass_correction = FALSE, # Biomass map does not include Canary Islands
                                     ifn_imputation_source = ifn_imputation_source)
    } else {
      l <- init_province_medfateland(province_code = province_code,
                                     emf_dataset_path = emf_dataset_path,
                                     res = res,
                                     buffer_dist = buffer_dist,
                                     crs_out = "EPSG:25830", # UTM 30N
                                     biomass_correction = TRUE,
                                     ifn_imputation_source = ifn_imputation_source)
    }

    
    write_medfateland_object(l, res)
    write_medfateland_raster(l, res)
    
    if(test_plots) {
      ggplot2::ggsave(paste0("plots/elevation_", province_code, "_", res, "m.png"),
                      medfateland::plot_variable(l$sf, "elevation", r = l$r))
      ggplot2::ggsave(paste0("plots/mean_tree_height_", province_code, "_", res, "m.png"),
                      medfateland::plot_variable(l$sf, "mean_tree_height", r = l$r))
      ggplot2::ggsave(paste0("plots/basal_area_", province_code, "_", res, "m.png"),
                      medfateland::plot_variable(l$sf, "basal_area", r = l$r))
      
    }
  }
}
