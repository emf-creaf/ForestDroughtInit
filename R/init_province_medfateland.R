#' Initialize spanish forested landscape
#' 
#' Initializes inputs for a target forested area for simulations with medfateland 
#' The target should be contained (or include the whole of) a Spanish province
#'
#' @param emf_dataset_path Path to the dataset folder
#' @param province_code String with the code of the province containing the target polygon
#' @param target_polygon Target polygon for the study area. If missing the whole province is taken
#' @param ifn_imputation_source String indicating the forest inventory version to use in forest stand imputation ("IFN2", "IFN3" or "IFN4")
#' @param res Spatial resolution (in m) of the study area.
#' @param crs_out String of the CRS 
#' @param height_correction Logical flag to try tree height correction
#' @param biomass_correction Logical flag to try tree biomass_correction
#' @param verbose Logical flag for console output
#' 
#' @author Rodrigo Balaguer Romano
#' @author Miquel De Cáceres
#' 
#' @returns A list composed of a sf object for medfateland and a raster definition
#' @export
#'
#' @examples
init_province_medfateland <- function(emf_dataset_path,
                                      province_code,
                                      target_polygon  = NULL,
                                      ifn_imputation_source = "IFN4",
                                      res = 500, 
                                      crs_out = "EPSG:25830", 
                                      height_correction = TRUE,
                                      biomass_correction = TRUE,
                                      soil_correction = TRUE,
                                      verbose = TRUE) {
  province_code <- as.character(province_code)
  province_code <- match.arg(province_code ,c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
                                              as.character(11:50)))
  province_utm_fuse <- "30" # Peninsular spain
  if(province_code %in% c(35, 38)) province_utm_fuse <- "28" #Canarias
  
  if(!is.numeric(res)) cli::cli_abort("`res` should be numeric")

  if(verbose) cli::cli_progress_step(paste0("Read MFE25 for province ", province_code))
  sf_mfe <- sf::read_sf(paste0(emf_dataset_path, "ForestMaps/Spain/MFE25/MFE_PROVINCES/MFE_", province_code, "_class.gpkg"))
  sf_mfe <- sf::st_make_valid(sf_mfe)
  # If target polygon not supplied, use the whole province
  if(is.null(target_polygon)) {
    if(verbose) cli::cli_progress_step("Setting whole province as target polygon")
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
  } else {
    # TODO check if target polygon is contained within province limits
  }
  if(verbose) cli::cli_progress_step("Crop forests within target polygon limits")
  for_poly <- sf::st_intersection(sf_mfe, target_polygon) |>
    na.omit() |> # Clean NA locations to just leave FOREST AREAS as a spatial vector
    terra::vect()
  if(verbose) cli::cli_progress_step(paste0("Rasterize forest areas at ", res ,"m resolution"))
  r_for <-terra::rast(terra::ext(for_poly), resolution = c(res,res), crs = crs_out)
  if(verbose) cli::cli_progress_step(paste0("Create sf object with forest locations at pixel locations"))
  sf_for <- terra::intersect(terra::as.points(r_for), for_poly) |>
    sf::st_as_sf(for_poly)
  sf_for <- sf_for[,"geometry", drop = FALSE]
  rm(for_poly)
  gc()
  if(verbose) cli::cli_progress_step(paste0("Load DEM for province ", province_code))
  dem <- terra::rast(paste0(emf_dataset_path, "Topography/Spain/PNOA_MDT25_PROVINCES_ETRS89/PNOA_MDT25_P", 
                            province_code ,"_ETRS89_H", 
                            province_utm_fuse, ".tif")) # Same number as province
  if(verbose) cli::cli_progress_step(paste0("Add topography to sf (and filter locations with missing topography)"))
  sf_for <- medfateland::add_topography(sf_for, dem = dem) |>
    medfateland::check_topography(sf_for, missing_action = "filter", verbose = FALSE)
  
  if(verbose) cli::cli_progress_step(paste0("Define land cover for ", nrow(sf_for) , " locations"))
  sf_for$land_cover_type <- "wildland"  
  
  if(verbose) cli::cli_progress_step(paste0("Load ", ifn_imputation_source, " imputation source"))
  ifn_file <- paste0(emf_dataset_path, "ForestInventories/IFN_medfateland/medfateland_",
                     tolower(ifn_imputation_source), "_",province_code,"_soilmod_WGS84.rds")
  if(!file.exists(ifn_file)) cli::cli_abort(paste0("IFN imputation source file '", ifn_file, "' does not exist!"))
  sf_nfi <- readRDS(ifn_file) |>
    sf::st_as_sf() |>
    medfateland::check_topography(missing_action = "filter", verbose = FALSE)|>
    medfateland::check_forests(missing_action = "filter", verbose = FALSE)
  
  if(verbose) cli::cli_progress_step(paste0("Forest imputation for ", nrow(sf_for) , " locations"))
  forest_map <- terra::vect(sf_mfe)
  sf_for <- medfateland::impute_forests(sf_for, sf_fi = sf_nfi, dem = dem, forest_map = forest_map, progress = FALSE)
  # Fill missing (missing tree or shrub codes should be dealt with before launching simulations)
  if(verbose) cli::cli_progress_step(paste0("Check missing forests"))
  sf_for <- medfateland::check_forests(sf_for, default_forest = medfate::emptyforest(), verbose = verbose) 
  
  if(height_correction) {
    if(verbose) cli::cli_progress_step(paste0("Load vegetation height for province"))
    height_map <- terra::rast(paste0(emf_dataset_path,"RemoteSensing/Spain/CanopyHeight/PNOA_NDSMV_1Cob_PROVINCES_ETRS89/PNOA_NDSMV_cm_P",
                                     province_code,"_ETRS89H", province_utm_fuse, "_25m.tif")) # Same number as province
    # Modify forest height
    if(verbose) cli::cli_progress_step(paste0("Correct tree height"))
    sf_for <- medfateland::modify_forest_structure(x = sf_for, structure_map =  height_map,
                                                   variable = "mean_tree_height",
                                                   map_var = "NDSM-Vegetacion-ETRS89-H29-0184-COB1", progress = verbose)
  }
  
  if(biomass_correction) {
    if(verbose) cli::cli_progress_step(paste0("Correct forest aboveground tree biomass"))
    biomass_map <- terra::rast(paste0(emf_dataset_path,"RemoteSensing/Spain/CanopyBiomass/CanopyBiomass_Su2025/CanopyBiomass_2021.tif"))
    r_biomass_map <- terra::resample(biomass_map, r_for) # Change CRS
    sf_for <- medfateland::modify_forest_structure(x = sf_for, structure_map = r_biomass_map,
                                                   var = "aboveground_tree_biomass", map_var = "CanopyBiomass_2021",
                                                   biomass_function = IFNallometry::IFNbiomass_medfate,
                                                   biomass_arguments = list(fraction = "aboveground",level = "stand"),
                                                   SpParams = traits4models::SpParamsES,
                                                   progress = verbose)
  }
  
  if(verbose) cli::cli_progress_step(paste0("Read soil data from SoilGrids2.0 for ", nrow(sf_for), " locations."))
  soilgrids_path = paste0(emf_dataset_path, "Soils/Global/SoilGrids/Spain/")
  sf_for <- medfateland::add_soilgrids(sf_for, soilgrids_path = soilgrids_path, progress = verbose)
  if(verbose) cli::cli_progress_step(paste0("Fill missing soil data with defaults"))
  sf_for <- medfateland::check_soils(sf_for,  missing_action = "default", 
                        default_values = c(clay = 25, sand = 25, bd = 1.5, rfc = 25), verbose = FALSE)
  if(verbose) cli::cli_progress_done()
  
  if(soil_correction) {
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
    sf_for <- medfateland::modify_soils(sf_for, soil_depth_map = soil_depth_mm, depth_to_bedrock_map = depth_to_bedrock_mm,
                                        progress = FALSE)
  }
  r_for$value <- TRUE
  return(list(sf = sf_for, r = r_for))
}

provinces <- c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
                                            as.character(11:50))
res <- 2000
emf_dataset_path <- "~/OneDrive/EMF_datasets/"
for(province_code in provinces) {
  cli::cli_h1(paste0("Processing province ", province_code))
  ifn_imputation_source <- "IFN4"
  ifn_file <- paste0(emf_dataset_path, "ForestInventories/IFN_medfateland/medfateland_",
                     tolower(ifn_imputation_source), "_",province_code,"_soilmod_WGS84.rds")
  if(!file.exists(ifn_file)) ifn_imputation_source = "IFN3"
  l <- init_province_medfateland(province_code = province_code,
                                 emf_dataset_path = emf_dataset_path,
                                 res = res,
                                 ifn_imputation_source = ifn_imputation_source,
                                 height_correction = FALSE)
  
  saveRDS(l$sf, paste0("data/medfateland_", province_code, "_sf.rds"))
  terra::writeRaster(l$r, paste0("data/medfateland_", province_code, "_raster.tif"), overwrite = TRUE)
}
