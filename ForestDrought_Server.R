############################ Forest Drought #####################################
# Librearias
library(medfateland)
library(traits4models)
library(IFNallometry)
library(terra)
library(sf)
library(dplyr)
library(curl)
#
###################### 1. TARGET FOREST LOCATIONS  #############################
#### Select target Mapa Forestal (CCAA) <- Maybe divide it by Provinces....
sf_mfe <- sf::read_sf("/home/rbalaguer/ForestDrought/emf/datasets/ForestMaps/Spain/MFE25/mfe_galicia/MFE_11_class.gpkg")
# Make valid all geometries
sf_mfe <- sf::st_make_valid(sf_mfe)
#
##### Charge all provinces boundaries
sf_pro <- sf::read_sf("/home/rbalaguer/ForestDrought/emf/datasets/PoliticalBoundaries/Spain/Provincias_ETRS89_30N/Provincias_ETRS89_30N.gpkg")
# Make all geometries valids
sf_pro <- sf::st_make_valid(sf_pro)
#
# Select target Province <- 15: A-Coruña (función para seleccionar provinvia desde aqui)
pro <- sf_pro[15,] 
# Crop REGIONAL forest SF with province sf limits
a <- st_intersection(sf_mfe, pro)
# Clean NA locations to just leave FOREST AREAS as a spatial vector
a <- vect(na.omit(a))
# Rasterize FOREST AREAS
res <- 500 # Define spatial resolution (500m)
r <-terra::rast(terra::ext(a), resolution = c(res,res), crs = "EPSG:25830")
# Sf object with target FOREST LOCATIONS at the established resolution
v <- terra::intersect(terra::as.points(r), a)
sf_for <- sf::st_as_sf(v)[,"geometry", drop = FALSE]
rm(v)
#
############################## 2. ADD TOPOGRAPHY  #################################
# Acesss DEM map <- same number code as province 
dem <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/Topography/Spain/PNOA_MDT25_PROVINCES_ETRS89/PNOA_MDT25_P15_ETRS89_H30.tif") # Same number as province
# Add topography
sf_for <- add_topography(sf_for, dem = dem)
# Filter mising
sf_for <- check_topography(sf_for, missing_action = "filter")
#
############################## 3. ADD LAND COVER ##################################
sf_for$land_cover_type <- "wildland"  
#
############################## 4. ADD FOREST OBJECTS  ###############################
# Acesss Forest Inventory Data sf object <- same number code as province 
sf_nfi <- readRDS("/home/rbalaguer/ForestDrought/emf/products/IFN2medfate/SpParamsES/IFN4/nosoilmod/IFN4_15_nosoilmod_WGS84.rds") # Same number as province
# Vectorize forest map
forest_map <- vect(sf_mfe)
# Input forest
sf_for <- impute_forests(sf_for, sf_fi = sf_nfi, dem = dem, forest_map = forest_map, progress = T)
# Fill mising
# empty <- emptyforest()
# sf_for <- check_forests(sf_for, missing_action = "default", default_values = empty) # Falta por inlcuir!
#
######################## 5. CORRECT FOREST OBJECTS STRUCTURES  #######################
######### 5.1 CORRECT TREE HEIGHT
height_map <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/RemoteSensing/Spain/CanopyHeight/PNOA_1Cob_PROVINCES_ETRS89/PNOA_CanopyHeight_P15_ETRS89H30_25_cm.tif") # Same number as province
# Agrregate
height_map<- terra::aggregate(height_map, fact = 20, fun = "mean", na.rm = TRUE) 
# Modify forest height
sf_for <- modify_forest_structure(x = sf_for, structure_map =  height_map, 
                                  variable = "mean_tree_height", map_var = "NDSM-Vegetacion-ETRS89-H29-0184-COB1", progress = T)
######### 5.1 CORRECT ABOVEGORUND TREE BIOMASS
biomass_map <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/RemoteSensing/Spain/CanopyBiomass/CanopyBiomass_Su2025/CanopyBiomass_2021.tif")
# Resample/Agrregate
biomass_map_ag<- terra::aggregate(biomass_map, fact = 10, fun = "mean", na.rm = TRUE) #Define aggregation needed
# Change CRS
biomass_map_ag <- project(biomass_map_ag, "EPSG:25830")
# Modify forest biomass
sf_for <- modify_forest_structure(x = sf_for, structure_map = biomass_map_ag, 
                                  var = "aboveground_tree_biomass", map_var = "CanopyBiomass_2021",
                                  biomass_function = IFNbiomass_medfate,
                                  biomass_arguments = list(fraction = "aboveground",level = "stand"), 
                                  SpParams = traits4models::SpParamsES,
                                  progress = TRUE)
#
############################## 6. ADD SOILS ####################################
# Add path
soilgrids_path = ("/home/rbalaguer/ForestDrought/emf/datasets/Soils/Global/SoilGrids/Spain/")
# Impute Soils
sf_for <- add_soilgrids(sf_for, soilgrids_path = soilgrids_path, progress = T)
# Fill mising
sf_for <- check_soils(sf_for,  missing_action = "default", 
                      default_values = c(clay = 25, sand = 25, bd = 1.5, rfc = 25))
#
############################## 7. CORRECT SOILS  ###############################
# Censored soil depth (cm)
bdricm<- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/Soils/Global/SoilDepth_Shangguan2017/BDRICM_M_250m_ll.tif")
#
# Probability of bedrock within first 2m [0-100]
bdrlog <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/Soils/Global/SoilDepth_Shangguan2017/BDRLOG_M_250m_ll.tif")
#
# Absolute depth to bedrock (cm)
bdticm <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/Soils/Global/SoilDepth_Shangguan2017/BDTICM_M_250m_ll.tif")
#
############# CROP
x_vect <- terra::vect(sf::st_transform(sf::st_geometry(sf_for), terra::crs(bdricm)))
x_ext <- terra::ext(x_vect)
bdricm <- terra::crop(bdricm, x_ext, snap = "out")
bdrlog <- terra::crop(bdrlog, x_ext, snap = "out")
bdticm <- terra::crop(bdticm, x_ext, snap = "out")
# Soil depth in MEDFATE units
soil_depth_mm <- (bdricm$BDRICM_M_250m_ll*10)*(1 - (bdrlog$BDRLOG_M_250m_ll/100))
# Bed rock in MEDFATE units
depth_to_bedrock_mm <- bdticm*10
# Modify soils
sf_for <- modify_soils(sf_for, soil_depth_map = soil_depth_mm, depth_to_bedrock_map = depth_to_bedrock_mm,
                       progress = T)
#
###############################  STORE SF OBJECT  ###############################
# Store
saveRDS(sf_for, "/home/rbalaguer/ForestDrought/emf/products/ForestInitialized/sf_for_P15.rds") # Store each province sf object
r$value <- TRUE
terra::writeRaster(r, "/home/rbalaguer/ForestDrought/emf/products/ForestInitialized/sf_for_P15.tif", overwrite=TRUE) # Store each province forest locations raster
#

