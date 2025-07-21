source("R/init_province_medfateland.R")


res <- 100
buffer_dist <- 5000
emf_dataset_path <- "~/datasets/"
test_plots <- TRUE

comarques <- sf::read_sf(paste0(emf_dataset_path, "PoliticalBoundaries/Catalunya/Comarques/comarques.shp"))

ripolles <- comarques[6,] 
l <- init_province_medfateland(emf_dataset_path = emf_dataset_path,
                               target_polygon = ripolles,
                               res = res,
                               buffer_dist = buffer_dist,
                               ifn_imputation_source = "IFN4")

ggplot2::ggsave(filename = "plots/ripolles_elevation.png",medfateland::plot_variable(l$sf, "elevation", r = l$r),width = 5)
ggplot2::ggsave(filename = "plots/ripolles_mean_tree_height.png",medfateland::plot_variable(l$sf, "mean_tree_height", r = l$r),width = 5)
ggplot2::ggsave(filename = "plots/ripolles_basal_area.png",medfateland::plot_variable(l$sf, "basal_area", r = l$r),width = 5)
