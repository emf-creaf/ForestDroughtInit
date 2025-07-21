source("R/init_province_medfateland.R")

res <- 2000
buffer_dist <- 50
emf_dataset_path <- "~/datasets/"

sf_all_provinces <- sf::read_sf(paste0(emf_dataset_path, "PoliticalBoundaries/Spain/Provincias_ETRS89_30N/Provincias_ETRS89_30N.gpkg"))
sf_all_provinces <- sf::st_make_valid(sf_all_provinces)

bcn_tar <- sf_all_provinces[c(8,43),] 
l <- init_province_medfateland(emf_dataset_path = emf_dataset_path,
                               target_polygon = bcn_tar,
                               res = res,
                               buffer_dist = buffer_dist,
                               ifn_imputation_source = "IFN4")

ggplot2::ggsave(filename = "plots/bcntar_elevation.png",medfateland::plot_variable(l$sf, "elevation", r = l$r),width = 5)
ggplot2::ggsave(filename = "plots/bcntar_mean_tree_height.png",medfateland::plot_variable(l$sf, "mean_tree_height", r = l$r),width = 5)
ggplot2::ggsave(filename = "plots/bcntar_basal_area.png",medfateland::plot_variable(l$sf, "basal_area", r = l$r),width = 5)
