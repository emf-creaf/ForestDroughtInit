#' Title
#'
#' @param emf_dataset_path 
#' @param province_code 
#' @param province_utm_fuse 
#' @param target_polygon 
#' @param ifn_imputation_source 
#' @param res 
#' @param crs_out 
#'
#' @returns
#' @export
#'
#' @examples
init_province_medfateland <- function(emf_dataset_path,
                                      province_code,
                                      province_utm_fuse = "30",
                                      target_polygon  = NULL,
                                      ifn_imputation_source = "IFN4",
                                      res = 500, 
                                      crs_out = "EPSG:25830", verbose = TRUE) {
  if(verbose) cli::cli_progress_step("Read MFE25 for target province")
  sf_mfe <- sf::read_sf(paste0(emf_dataset_path, "ForestMaps/Spain/MFE25/MFE_PROVINCES/MFE_", province_code, "_class.gpkg"))
  sf_mfe <- sf::st_make_valid(sf_mfe)
  # If target polygon not supplied, use the whole province
  if(is.null(target_polygon)) {
    if(verbose) cli::cli_progress_step("Set whole province as target polygon")
    sf_all_provinces <- sf::read_sf(paste0(emf_dataset_path, "PoliticalBoundaries/Spain/Provincias_ETRS89_30N/Provincias_ETRS89_30N.gpkg"))
    sf_all_provinces <- sf::st_make_valid(sf_all_provinces)
    target_polygon <- sf_all_provinces |>
      dplyr::filter(Codigo == province_code) |>
      sf::st_as_sfc()
    # Transform CRS if necessary
    if(sf::st_crs(target_polygon) != sf::st_crs(sf_mfe)) {
      target_polygon <- target_polygon |>
        sf::st_transform(target_polygon, crs = sf::st_crs(sf_mfe))
    }
  }
  if(verbose) cli::cli_progress_step("Crop forests within target polygon limits")
  a <- sf::st_intersection(sf_mfe, target_polygon) |>
    na.omit() |> # Clean NA locations to just leave FOREST AREAS as a spatial vector
    terra::vect()
  if(verbose) cli::cli_progress_step(paste0("Rasterize forest areas at ", res ,"m resolution"))
  r <-terra::rast(terra::ext(a), resolution = c(res,res), crs = crs_out)
  if(verbose) cli::cli_progress_step(paste0("Create sf object with forest locations at ", res ,"m resolution"))
  # Sf object with target FOREST LOCATIONS at the established resolution
  v <- terra::intersect(terra::as.points(r), a)
  sf_for <- sf::st_as_sf(v)[,"geometry", drop = FALSE]
  rm(v)
  rm(a)
  gc()
  if(verbose) cli::cli_progress_step(paste0("Load DEM for province"))
  dem <- terra::rast(paste0(emf_dataset_path, "Topography/Spain/PNOA_MDT25_PROVINCES_ETRS89/PNOA_MDT25_P", 
                            province_code ,"_ETRS89_H", 
                            province_utm_fuse, ".tif")) # Same number as province
  if(verbose) cli::cli_progress_step(paste0("Add topography to sf"))
  sf_for <- add_topography(sf_for, dem = dem)
  sf_for <- check_topography(sf_for, missing_action = "filter", verbose = verbose)
  
  if(verbose) cli::cli_progress_step(paste0("Define land cover"))
  sf_for$land_cover_type <- "wildland"  
  
  if(verbose) cli::cli_progress_step(paste0("Load IFN imputation source"))
  ifn_file <- paste0("~/OneDrive/mcaceres_work/model_initialisation/medfate_initialisation/IFN2medfate/",
                     "data/SpParamsES/", ifn_imputation_source, "/nosoilmod/",
                     "IFN4_",province_code,"_nosoilmod_WGS84.rds")
  if(!file.exists(ifn_file)) cli::cli_abort(paste0("IFN imputation source file '", ifn_file, "' does not exist!"))
  sf_nfi <- readRDS(ifn_file) # Same number as province
  
  if(verbose) cli::cli_progress_step(paste0("Forest imputation for ", nrow(sf_for) , " locations"))
  forest_map <- terra::vect(sf_mfe) # Vectorize forest map
  sf_for <- medfateland::impute_forests(sf_for, sf_fi = sf_nfi, dem = dem, forest_map = forest_map, progress = FALSE)
  # Fill missing (missing tree or shrub codes should be dealt with before launching simulations)
  if(verbose) cli::cli_progress_step(paste0("Check missing forests"))
  sf_for <- check_forests(sf_for, default_forest = emptyforest(), verbose = verbose) 
  
  # ######################## 5. CORRECT FOREST OBJECTS STRUCTURES  #######################
  # ######### 5.1 CORRECT TREE HEIGHT
  # height_map <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/RemoteSensing/Spain/CanopyHeight/PNOA_1Cob_PROVINCES_ETRS89/PNOA_CanopyHeight_P15_ETRS89H30_25_cm.tif") # Same number as province
  # # Agrregate
  # height_map<- terra::aggregate(height_map, fact = 20, fun = "mean", na.rm = TRUE) 
  # # Modify forest height
  # sf_for <- modify_forest_structure(x = sf_for, structure_map =  height_map, 
  #                                   variable = "mean_tree_height", map_var = "NDSM-Vegetacion-ETRS89-H29-0184-COB1", progress = T)
  # ######### 5.1 CORRECT ABOVEGORUND TREE BIOMASS
  # biomass_map <- terra::rast("/home/rbalaguer/ForestDrought/emf/datasets/RemoteSensing/Spain/CanopyBiomass/CanopyBiomass_Su2025/CanopyBiomass_2021.tif")
  # # Resample/Agrregate
  # biomass_map_ag<- terra::aggregate(biomass_map, fact = 10, fun = "mean", na.rm = TRUE) #Define aggregation needed
  # # Change CRS
  # biomass_map_ag <- project(biomass_map_ag, "EPSG:25830")
  # # Modify forest biomass
  # sf_for <- modify_forest_structure(x = sf_for, structure_map = biomass_map_ag, 
  #                                   var = "aboveground_tree_biomass", map_var = "CanopyBiomass_2021",
  #                                   biomass_function = IFNbiomass_medfate,
  #                                   biomass_arguments = list(fraction = "aboveground",level = "stand"), 
  #                                   SpParams = traits4models::SpParamsES,
  #                                   progress = TRUE)
  # #
  
  if(verbose) cli::cli_progress_step(paste0("Read soil data from SoilGrids2.0"))
  soilgrids_path = paste0(emf_dataset_path, "Soils/Global/SoilGrids/Spain/")
  sf_for <- add_soilgrids(sf_for, soilgrids_path = soilgrids_path, progress = verbose)
  if(verbose) cli::cli_progress_step(paste0("Check missing soil data"))
  sf_for <- check_soils(sf_for,  missing_action = "default", 
                        default_values = c(clay = 25, sand = 25, bd = 1.5, rfc = 25))
  if(verbose) cli::cli_progress_done()
  
  if(verbose) cli::cli_progress_step(paste0("Modify soil depth using data from Shangguan et al. 2017"))
  # Censored soil depth (cm)
  bdricm<- terra::rast(paste0(emf_dataset_path, "Soils/Global/SoilDepth_Shangguan2017/BDRICM_M_250m_ll.tif"))
  # Probability of bedrock within first 2m [0-100]
  bdrlog <- terra::rast(paste0(emf_dataset_path, "Soils/Global/SoilDepth_Shangguan2017/BDRLOG_M_250m_ll.tif"))
  # Absolute depth to bedrock (cm)
  bdticm <- terra::rast(paste0(emf_dataset_path, "Soils/Global/SoilDepth_Shangguan2017/BDTICM_M_250m_ll.tif"))
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
                         progress = FALSE)
  
  return(list(sf = sf_for, r = r))
}

l <- init_province_medfateland(province_code = "02",
                          province_utm_fuse = "30",
                          emf_dataset_path = "~/OneDrive/EMF_datasets/",
                          target_polygon  = NULL,
                          ifn_imputation_source = "IFN4",
                          res <- 1000, # Define spatial resolution (500m)
                          crs_out <- "EPSG:25830")




