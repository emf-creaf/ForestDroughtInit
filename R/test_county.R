source("R/init_province_medfateland.R")

comarques <- sf::read_sf("~/OneDrive/EMF_datasets/PoliticalBoundaries/Catalunya/Comarques/comarques.shp")

res <- 1000
buffer_dist <- 50
emf_dataset_path <- "~/OneDrive/EMF_datasets/"
test_plots <- TRUE

ripolles <- comarques[31,] 
l <- init_province_medfateland(emf_dataset_path = emf_dataset_path,
                               target_polygon = ripolles,
                               res = res,
                               buffer_dist = buffer_dist,
                               ifn_imputation_source = "IFN4",
                               height_correction = TRUE)

