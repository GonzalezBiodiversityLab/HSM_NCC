
# Habitat Suitability Models (HSMs)
# Nikol Dimitrov, Richard Scuster and Juan Zuloaga
# Basic script

# version.string R version 3.6.3 (2020-02-29)
R.Version()

######### START PIPELINE ######################

# 0. Packages required -----------

list.of.packages <- c("devtools", "rgbif", "raster", 'dismo', 'ENMeval', 'dplyr', 'adehabitatHR', "rgeos", "sf", "WorldClimTiles", "virtualspecies")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]

devtools::install_github("kapitzas/WorldClimTiles") # to load and merge BIOCLIM tiles
                                                    # (https://github.com/kapitzas/WorldClimTiles/blob/master/README.md)


if(length(new.packages)) install.packages(new.packages)

lapply(list.of.packages, library, character.only =TRUE) 

# 1. Settings ----------

# 1.1. Creating main folder

  # Checking of folder exists
    if(!dir.exists("C:/HSM_NCC")){
      dir.create("C:/HSM_NCC")
      print("dir created")
    }else{
      print("dir exists")
    }

  # Setting main folder as a default
    setwd("C:/HSM_NCC")


# 1.3. Creating a directory to save temporary files that will be deleted after process
  
    if(!dir.exists("./temp_HMs_to_REMOVE")){
      dir.create("./temp_HMs_to_REMOVE")
      print("dir created")
    }else{
      print("dir exists")
    }

# 1.4. Setting temp directory
  rasterOptions(tmpdir=file.path("./temp_HMs_to_REMOVE"))

  
# 1.5. Setting Projection to preserve area for all files 
  
  # Lon-Lat 
   # wgs84 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0 "
    wgs84 <- "+proj=longlat +datum=WGS84 +no_defs"
  # Albers Equal Area Conic
  #[See:](https://spatialreference.org/ref/esri/102001/proj4/) 
    aeac="+proj=aea +lat_1=50 +lat_2=70 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"




# 2. Species -----------
  myspecies <- c("Nestotus macleanii")


# 3.Occurrences ------------

# 3.1. Let's see how many occurrences GBIF has.
  #using 'key' number instead of the name (because there are getting synonyms too)

  key <- name_suggest(q = myspecies, rank='species')$data$key[1] 
  occ_search(taxonKey=key, limit=2)

  
# 3.2. Loading data from GBIF (https://www.gbif.org/)
  Obs_gbif_data <- occ_data(scientificName = myspecies,
                          hasCoordinate = TRUE,
                          limit=5000)         # Important here to set number of observations requiered.
                                              # GBIF has a maximum of 100,000.
                                              # If the species has more than 100,000 occ we need to ask GBIF for a zipfile


# 3.4. Creating spatial features (points)
  
  Obs_gbif_data_sp <- data.frame(cbind(Obs_gbif_data$data$decimalLongitude, Obs_gbif_data$data$decimalLatitude))%>%
    sp::SpatialPoints(proj4string=CRS(wgs84))
  
  # create data.frame
  Obs_gbif_data_df <- data.frame(Obs_gbif_data_sp)
  
  # Transform for plotting
  Obs_gbif_data_sf <- st_as_sf(Obs_gbif_data_sp)%>%
    st_transform(aeac)
  
# 4. Area of study -------------
  
# 4.1. Creating box extent to download predictors

  # Several options here:
    # Geographic range: not for many species
    # Ecoregions
    # ArbitraRy polygon (Ontario, Canada, etc)
    # MinImum convex polygon with buffer
  
  # MinImum convex polygon (mcp) with buffer  
  
    box_extent_analysis <- mcp(Obs_gbif_data_sp, percent = 100)%>%
     st_as_sf()%>%
      st_transform(crs=aeac)
    
    # Buffering box extent
      box_extent_analysis_bf <-  st_buffer(box_extent_analysis, dist =  100000)%>%
        st_transform(crs=wgs84)

    # Tranform for plotting
      box_extent_analysis_bf_aeac <- st_as_sf(box_extent_analysis_bf)%>%
        st_transform(aeac)

     

# 5. Predictors ------------

### Let's start with WORLDCLIM (we are going to use CHELSA)


# 5.2. Topographic heterogeneity
  
  # Vector_Ruggedness_Measure
  vrm <- raster("./Data/Topographic_Index/vrm_1KMmn_GMTEDmd.tif") %>%
    crop(box_extent_analysis_bf) 
  names(vrm) <- "Vector_Ruggedness_Measure"
  
  # Roughness
  roughness <- raster("./Data/Topographic_Index/roughness_1KMmn_GMTEDmd.tif") %>%
    crop(box_extent_analysis_bf)   %>%
    resample(vrm, method = "ngb")
  names(roughness) <- "Roughness"
  
  # Slope
  Slope <- raster("./Data/Topographic_Index/slope_1KMmn_GMTEDmd.tif") %>%
    crop(box_extent_analysis_bf)  %>%
    resample(vrm, method = "ngb")
  names(Slope) <- "Slope"
  
  
  # Eastness
  Eastness <- raster("./Data/Topographic_Index/eastness_1KMmn_GMTEDmd.tif") %>%
    crop(box_extent_analysis_bf)  %>%
    resample(vrm, method = "ngb")
  names(Eastness) <- "Eastness"
  
  # Northness
  Northness <- raster("./Data/Topographic_Index/northness_1KMmn_GMTEDmd.tif") %>%
    crop(box_extent_analysis_bf)  %>%
    resample(vrm, method = "ngb")
  names(Northness) <- "Northness"
  
  
# 5.2. Bioclim
  
  # Idenfitying tiles based on Area of study
  
  box_extent_bioclim <- tile_name(as(box_extent_analysis_bf, 'Spatial'), "worldclim") # determine which WorldClim tiles your study area intersects with.
  
  # Creating folder
  if(dir.exists("./bioclim_t")){
  }else{
    out_bioclim <-   dir.create("./bioclim_t")}
  
  # Loading tiles
  clim_tiles <- tile_get(box_extent_bioclim, name =  "worldclim", var="bio", path = "./bioclim_t") # for 0.5 arcmin worldclim tiles of 
  
  # Merging tiles
  clim_tiles_merge <- tile_merge(clim_tiles)
  
  
  
  # Agregagate (Let's try coarse resolution to speed up the process)!!!!!!!!!!!!!!!!
  clim_tiles_merge_agg <- raster::aggregate(clim_tiles_merge, fact=10, fun=mean) %>%
    resample(vrm, method = "ngb")
  
  
  
# 5.3. Productivity
  
  # Loading Dynamic Habitat Index  (all .tiff files)
    fpar_all <- list.files("./Data/fpar_can", pattern=".tif$", full.names = T)
  
  #  Band 1
      fpar_b1_mean <- lapply(fpar_all, raster, band=1) %>%           # Create raster
        stack()  %>%                                                 # Stack them
        crop(box_extent_analysis_bf)%>%                              # Crop to extent
        calc(mean)%>%                                                # Apply function to calculate mean
        resample(vrm, method = "ngb")                                # resample using previous raster
      names(fpar_b1_mean) <- "Cummulative_annual_productivity_b1"    # rename variable
  
  
  #  Band 2
      fpar_b2_mean <- lapply(fpar_all, raster, band=2) %>%           # Create raster
        stack()  %>%                                                 # Stack them
        crop(box_extent_analysis_bf)%>%                              # Crop to extent
        calc(mean)%>%                                                # Apply function to calculate mean
        resample(vrm, method = "ngb")                                # resample using previous raster
      names(fpar_b2_mean) <- "Minimum_annual_productivity_b2"        # rename variable
          
      
  #  Band 3
      fpar_b3_mean <- lapply(fpar_all, raster, band=3) %>%           # Create raster
        stack()  %>%                                                 # Stack them
        crop(box_extent_analysis_bf)%>%                              # Crop to extent
        calc(mean)%>%                                                # Apply function to calculate mean
        resample(vrm, method = "ngb")                                # resample using previous raster
      names(fpar_b3_mean) <- "Variation_annual_productivity_b3"      # rename variable

      
# 5.4. Water proximity
      
  # Percentage of lakes
      
    lakes_100m <- raster("./Data/Lakes/Lakes_100_wgs84.tif")%>% # Lakes North America 100m resolution
      crop(box_extent_analysis_bf)
    lakes_100m_agg <- aggregate(lakes_100m, fact=10, fun=sum)%>% # aggregating 100m cells into 1000m cells, using 'sum' function
      resample(vrm, method = "ngb")
    names(lakes_100m_agg) <- "Lakes_percentage"
    

# 5.5  Stacking Predictors ----------
    
    predictors <- stack(vrm,
                   roughness,
                   Slope,
                   Eastness,
                   Northness,
                   lakes_100m_agg,
                   if(maxValue(fpar_b1_mean) != 0 && minValue(fpar_b1_mean) !=0){fpar_b1_mean}else{},
                   if(maxValue(fpar_b2_mean) != 0 && minValue(fpar_b2_mean) !=0){fpar_b2_mean}else{},
                   if(maxValue(fpar_b3_mean) != 0 && minValue(fpar_b3_mean) !=0){fpar_b3_mean}else{},
                   clim_tiles_merge_agg, na.rm=T)
    
    
# 5.5. Removing collinear variables

# Calculating colinearity
    collinearity_test <- removeCollinearity(predictors,
                                             multicollinearity.cutoff = 0.70, 
                                             plot = F, select.variables = T, sample.points = FALSE)

  # Subsetting variables
    noncollinear_predictors <- stack(subset(predictors, collinearity_test))
    

# 6. Model fitting ------

# 6.1. Renaming observations columns
  occs <- dplyr::select(Obs_gbif_data_df, X1, X2) %>%
    dplyr::rename(longitude = X1,  latitude =  X2)


# 6.2 creating pseudo-absences
  bg_points <- dismo::randomPoints(clim_tiles_merge_agg$bio1_01, n = 5000) %>% as.data.frame()
  colnames(bg_points) <- colnames(occs)


# 6.3 Modeling (using Maxent in ENMeval) basic parameters
  model_species <- ENMeval::ENMevaluate(occs = occs, envs = noncollinear_predictors , bg = bg_points, 
                                        algorithm = 'maxent.jar',
                                        partitions = 'block',
                                        tune.args = list(fc = "L", rm = 1),
                                        parallel =  TRUE,
                                        updateProgress = TRUE,
                                        parallelType = "doParallel"
  )

# 7. Predictions -------

  model_species_prediction <- eval.predictions(model_species)
  
# 8.  Model uncertainty ---------

# let's run 10 models and calculate the coefficient of variance (the only think that will change is background points)

  # Modelling
    model_10 <- list()
    
    for(i in 1:10){
      cat(paste0("Testing background points_model_", i), '\n')
      
      library(dismo)
      bg_points <- dismo::randomPoints(clim_tiles_merge_agg$bio1_01, n = 5000) %>% as.data.frame()
      colnames(bg_points) <- colnames(occs)
      
      model_10[[i]] <- ENMevaluate(occs = occs, envs = clim_tiles_merge_agg , bg = bg_points, 
                                   algorithm = 'maxent.jar',
                                   partitions = 'block',
                                   tune.args = list(fc = "L", rm = 1),
                                   parallel =  TRUE,
                                   updateProgress = TRUE,
                                   parallelType = "doParallel"
      )
      
    }

  # Calcualting coeficient of variance
    model_10_predictions <- stack(lapply(model_10, eval.predictions))
    uncertainty <- cv(model_10_predictions)

# 9. Projecting outputs -----------
  # Projecting to aeac to preserve areas and allow calcualtions 
  model_species_prediction_p <- projectRaster(model_species_prediction, crs = aeac, res = 1000, method = "bilinear")
  uncertainty_p <- projectRaster(uncertainty, crs = aeac, res = 10000, method = "bilinear")

#############END PIPELINE ####################################
