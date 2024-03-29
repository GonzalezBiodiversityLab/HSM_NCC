# ***********************************************************************************************************
# utf8 encoding
# File Name:     Species_data_cleanup_functions.R
# Author:        Nikol Dimitrov & Juan Zuloaga
# Notes:         Species occurrences data cleanup 
# ***********************************************************************************************************

# load needed packages for species occurrence cleanup 
list.of.packages <- c("readr", "rgbif", "raster", 'dplyr', "ggplot2", "countrycode", "CoordinateCleaner", "sp", "spThin", "rnaturalearthdata")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]

if(length(new.packages)) install.packages(new.packages)

lapply(list.of.packages, library, character.only =TRUE) 


# Setting main folder as a default
setwd("C:/HSM_NCC")

# creating species folder 

if(dir.exists("c:/HSM_NCC/thinned_species_data")){
} else {
  out_species<-   dir.create("c:/HSM_NCC/thinned_species_data")}


# Projection for species coordinates 

# Lon-Lat 
wgs84 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0 "

### function format - to speed up processes and scale up to many species 

# FUNCTION 1 - Export data from gbif and store data into object 

export_gbif_data <- function(speciesName){
  Obs_gbif_data <- occ_data(scientificName = speciesName,
                            hasCoordinate = TRUE,
                            limit=5000, country = "CA") 
  if (is.null(Obs_gbif_data)) {
    stop("no species data available")
  } else {
    Obs_data <- Obs_gbif_data$data 
    return(Obs_data)
  }
}

# FUNCTION 2 - Clean up species dataset 

clean_gbif_data <- function(data, flagged.data = FALSE){ 
  # remove occurrences with incomplete coordinate information
  dat <- data %>% 
    filter(!is.na(decimalLatitude)) %>% 
    filter(!is.na(decimalLongitude))
  
  # convert country code from iso2c to iso3c
  dat$countryCode <- countrycode(dat$countryCode, origin = "iso2c", destination = "iso3c")
  
  # flag suspicious data 
  flag_data <- clean_coordinates(x = dat, 
                                 lon = "decimalLongitude", 
                                 lat = "decimalLatitude", 
                                 countries = "countryCode", 
                                 species = "scientificName", 
                                 tests = c("capitals", "centroids", "equal","gbif", 
                                           "institutions", "zeros", "countries", "outliers"),
                                 verbose = TRUE)
                                 
  # if parameter for flagged data is true return only flagged data (set to false by default)
  if (flagged.data == TRUE){                 
    # flagged records dataframe 
    data_fl <- dat[!flag_data$.summary,]
    return(data_fl)
  } else {
    # cleaned dataframe 
    data_cl <- dat[flag_data$.summary,]
    
    #remove occurrences with coordinate undertainty greater than 1km
    if ("coordinateUncertaintyInMeters" %in% colnames(data_cl)){
    data_cl <- data_cl %>% 
      filter(coordinateUncertaintyInMeters / 1000 <= 1 | is.na(coordinateUncertaintyInMeters))
    }
    
    #filter for records that are human observations or occurrences
    if ("basisOfRecord" %in% colnames(data_cl)){
    data_cl <- data_cl %>% 
      filter(basisOfRecord %in% c("HUMAN_OBSERVATION", "OCCURRENCE")) 
    }
    
    #remove suspicious individual counts (0 counts or really large counts > 99)
    if ("individualCount" %in% colnames(data_cl)){
    data_cl <- data_cl %>% 
      filter(individualCount > 0 | is.na(individualCount))%>%
      filter(individualCount < 99 | is.na(individualCount)) 
    } 
    return(data_cl)
  } 
}

# FUNCTION 3 -  plot the data 

plot_gbif_data <- function(data) { 
  if (dim(data)[1] == 0) {
    stop("no species data available")
  } else {
    w_b <- borders("world", colour = "gray50", fill = "gray50")
    ggplot() + coord_fixed() + w_b + 
      geom_point(data = data, aes(decimalLongitude, decimalLatitude),
                 colour = "red", size = 0.5) + 
      theme_bw() +
      xlim(min(data$decimalLongitude) - 20, max(data$decimalLongitude) + 20) + 
      ylim(min(data$decimalLatitude) - 20, max(data$decimalLatitude) + 20)
  }
}

# FUNCTION 4 - Spatial thinning alogrithm 

thin_data <- function(data, thinning_par = 1) {
  
  # run algorithm 
  Obs_data_thinned <- thin(data, lat.col = 'decimalLatitude', long.col = 'decimalLongitude', spec.col = 'scientificName', thin.par = thinning_par, 
       reps = 1,
       locs.thinned.list.return = TRUE,
       write.files = FALSE,
       write.log.file = FALSE)%>%
    data.frame()
  
  return(Obs_data_thinned)
}

# FUNCTION 5 - Convert to spatial points 

convert_spatial_points <- function(data){
  # make into spatial points
  
  Obs_data_sp <- data.frame(cbind(data$Longitude, data$Latitude))%>% 
    sp::SpatialPoints(proj4string = CRS(wgs84))
  
  return(Obs_data_sp)

}
