# Initialisation of arbitrary polygons for medfateland

## What the workflow does?

+ Creates `sf` objects and raster definitions (*.tif* files) to be used in simulations with package **medfateland** for a given province or a polygon within it.

## Data dependencies

| Data source       | Data location    | Previous pipeline |
|-------------------|------------------|-------------------|
| Province limits   |     `[emf_dataset_path]/PoliticalBoundaries/Spain/Provincias_ETRS89_30N/`             | |
| PNOA MDT 25 m     |            `[emf_dataset_path]/Topography/Spain/PNOA_MDT25_PROVINCES_ETRS89/`    | |
| MFE 1:25000       | `[emf_dataset_path]/ForestMaps/Spain/MFE25/`    | |
| SIOSE 1:25000 (2014)  | `[emf_dataset_path]/LandCover/Spain/SIOSE_2014/` | |
| PNOA Canopy height 25 m | `[emf_dataset_path]/RemoteSensing/Spain/CanopyHeight/PNOA_NDSMV_1Cob_PROVINCES_ETRS89`| |
| Biomass in Iberian Peninsula (Su et al. 2025) | `[emf_dataset_path]/RemoteSensing/Spain/ForestBiomass/ForestBiomass_Su2025`| |
| IFN for medfateland     | `[emf_dataset_path]/ForestInventories/IFN_medfateland/`    | `emf_forestables_medfate` |
| SoilGrids 2.0     |  `[emf_dataset_path]/Soils/Global/SoilGrids/`  | |
| Soil depth data from Shangguan et al. (2017) | `[emf_dataset_path]/Soils/Global/SoilDepth_Shangguan2017/` | |

## EMF R packages dependencies

|  R package  |   Functionality provided  |
|-------------|------------------|
| **medfate** | Simulation control parameters |
| **medfateland** | Landscape initialisation routines, simulation routines for testing |
| **traits4models** | Dataset `SpParamsES` |
| **IFNallometry** | Biomass calculation for structure correction |

## Outputs

+ `sf` objects ready for **medfateland** simulations for the target area.
+ Raster definitions (*.tif* files) from which point coordinates have been defined.


## Steps

These are coded in function `init_spanish_forestland_medfateland()`:

  1. Check inputs and, if necessary, set the target polygon and the buffer zone.
  2. Determine the set of Spanish provinces touched by the target area or buffer zone.
  3. Determine National Forest Map (MFE25) polygons overlapping the target area or buffer zone.
  4. If not supplied as input, define raster at desired resolution (e.g. 100m, 200m or 500 m, depending on computational resources) over the target polygon.
  5. Define target locations over the forested area (set of MFE polygons in the target area ) or the whole area (if non-forest land cover are to be included).
  6. Use digital elevation model (DEM) for touched provinces and function `add_topography()` to extract elevation and estimate slope and aspect.
  7. Define land cover type 
  7. Load forest inventory data for touched provinces, as sf objects for package medfateland.
  8. Use polygons in 3, DEM and function `impute_forests()` to perform imputation using: (a) the target sf with topography; (b) forest inventory data; (c) the forest map and (d) the DEM.
  9. Load mean tree height raster (m) and correct mean tree height using function `modify_forest_structure()`.
  10. Load aboveground tree biomass raster (Mg/m) from ALS-Sentinel product for the Iberian Peninsula (yrs. 2017-2021): https://zenodo.org/records/15032832 
  11. Define aboveground tree biomass function (using https://github.com/emf-creaf/IFNallometry) and correct tree density using function modify_forest_structure(). 
  12. Use function `add_soilgrids()` to draw soil information from SoilGrids 2.0 data
  13. Use global product at 250 m (Shangguan et al. 2017) and function `modify_soils()` to correct soil depth /rock fragment content.
  14. Store sf object 

## Alternative data sources

  + Canopy height from PlanetScope product at 30 m (derived from 3m data): https://zenodo.org/records/8154445 
  + PlanetScope product: https://zenodo.org/records/8154445 


## Processing functions


|  R script  |   Functionality provided  |
|-------------|------------------|
| `Catalunya_counties.R` | Forested landscapes for counties in Catalunya  |
| `Spanish_provinces.R` | Forested landscapes for Spanish provinces |
