# Initialisation of arbitrary polygons for medfateland

## What the workflow does?

+ Creates `sf` objects and raster definitions to be used in simulations with package **medfateland** for a given province or a polygon within it.

## Data dependencies

| Data source       | Data location    | Previous pipeline |
|-------------------|------------------|-------------------|
| PNOA MDT 25 m     |            `[emf_dataset_path]/Topography/Spain/PNOA_MDT25_PROVINCES_ETRS89/`    | |
| MFE 1:25000       | `[emf_dataset_path]/ForestMaps/Spain/MFE25/`    | |
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

+ `sf` objects and raster masks ready for **medfateland** simulations for the target area.


## Steps

  1. Define target forested area: If defined using National Forest Map (MFE25), then it will match step 5.
  2. Define raster at desired resolution (e.g. 200m, 250m or 500 m, depending on computational resources) over the forested area.
  3. Define target locations using intersection between (1) and (2). These will be treated as forest stands in a circular area of 25m-radius (like IFN plots).
  4. Use DEM at no less than 30 m resolution and function `add_topography()` to extract elevation and estimate slope and aspect.
  5. Take a forest map as source of forest classes. For that, the MFE25 has been modified to provide dominant/codominant species and abundance values into a single class to be used for imputation (needs to be done for the whole Spain).
  6. Load forest inventory data, as sf object for package medfateland.
  7. Use function `impute_forests()` to perform imputation using: (a) the target sf with topography; (b) forest inventory data; (c) the forest map and (d) the DEM.
  8. Load mean tree height raster (m). Options: 
        + Altura de vegetación LiDAR (2.5 m! Aggregation to 25 m: `terra::aggregate(x, fact = 10, fun = "mean", na.rm = TRUE))` https://centrodedescargas.cnig.es/CentroDescargas/modelo-digital-superficies-vegetacion-mdsnv2_5-primera-cobertura
        + Canopy height from PlanetScope product at 30 m (derived from 3m data): https://zenodo.org/records/8154445 
  9. Correct mean tree height using function `modify_forest_structure()`.
  10. Load aboveground tree biomass raster (Mg/m) from:
      + PlanetScope product: https://zenodo.org/records/8154445 
      + ALS-Sentinel product for the Iberian Peninsula (yrs. 2017-2021): https://zenodo.org/records/15032832 
  11. Define aboveground tree biomass function (using https://github.com/emf-creaf/IFNallometry) and correct tree density using function modify_forest_structure(). 
  12. Use function `add_soilgrids()` to draw soil information from SoilGrids 2.0 data
  13. Use global product at 250 m (Shangguan et al. 2017) and function `modify_soils()` to correct soil depth /rock fragment content.
  14. Store sf object 
