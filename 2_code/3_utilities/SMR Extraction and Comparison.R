# This script extracts raw SMR (physical model) data that matches 
#  dates and coordinates to the existing NDRE/Soil Moisture data.
#  In addition, it calculates errors between the SMR results and
#  the in-ground soil moisture.


# Local working directory path 
setwd("C:/Users/Samir Patel/Desktop/Data 590 - Capstone I/HydroSatML/")

# Import libraries
library(raster)
library(stringr)
library(lubridate)
library(data.table)

# Open file with coordinates for field sites
coords <- read.csv("data/sensor_coords/SCF_TierII_site_coords.csv")

# List of Fields where SMR data is available...W and J sites not at the moment
fields <- c("AES", "OD")

# Local path where SMR data is stored
smrpath <- "C:/Users/Samir Patel/Desktop/Data 590 - Capstone I/
                                    Hydrologic Model/SMR 2-7-18/SMR/"

# Subset actual NDRE sm prediction data for relevant columns
sensors <- read.csv("data/data_for_models/final_join.csv")
sensors.subset <- sensors[c("date", "field", "sensor",
                            "depth_1", "depth_2", "depth_3")]
sensors.subset <- unique(sensors.subset)
sensors.subset <- sensors.subset[order(sensors.subset$sensor), ]
sensors.subset$field <- as.character(sensors.subset$field)

# Create dataframe with unique dates and fields to iterate through for SMR extract
actual.dates <- sensors[c("date", "field")]
actual.dates <- unique(actual.dates)

# Pull list of ASCII SMR file names for AES and OD field sites
aes_path <- paste(smrpath, fields[1], "/", sep = "")
aes_list <- list.files(path = aes_path)
od_path <- paste(smrpath, fields[2], "/", sep = "")
od_list <- list.files(path = od_path)

aes_list <- data.frame(aes_list, c("AES"))
names(aes_list) <- c("filename", "field")
od_list <- data.frame(od_list, c("OD"))
names(od_list) <- c("filename", "field")

# Subsetting SMR files with rz prefix
aes_list <- subset(aes_list, grepl("rz", filename))
od_list <- subset(od_list, grepl("rz", filename))

# Creating dataframe with all field site files and extracting date from filename
ascii.files <- rbind(aes_list, od_list)
ascii.files$DOY <- str_extract_all(pattern = "(?<=_)(.*)(?=.a)",
                                   ascii.files$filename)

# Unlist DOY column
ascii.files <- transform(ascii.files, DOY = unlist(DOY))


# Create day (out of 365) and year columns using Lubridate
sensors.subset$year <- year(sensors.subset$date)
sensors.subset$day <- yday(sensors.subset$date)
sensors.subset$sm_mean <- rowMeans(subset(sensors.subset,
                                          select = c(depth_1, depth_2, depth_3)),
                                          na.rm = TRUE)

actual.dates$year <- year(actual.dates$date)
actual.dates$day <- yday(actual.dates$date)

# combine day and year into DOY
sensors.subset$DOY <- paste(sensors.subset$day, sensors.subset$year, sep = "")
actual.dates$DOY <- paste(actual.dates$day, actual.dates$year, sep = "")



# Extracting SMR data into smr_output dataframe
smr_output <- data.frame()

for (j in 1:length(fields)){
  # Determine coordinates by field site
  if (fields[j] == "AES"){
    coords_field <- coords[1:12, 1:2]
  } else if (fields[j] == "J") {
    coords_field <- coords[13:24, 1:2]
  } else if (fields[j] == "OD") {
    coords_field <- coords[25:36, 1:2]
  } else if (fields[j] == "W") {
    coords_field <- coords[37:48, 1:2]
  }

  # Iterate through specific NDRE/Actual SM dates
  for (i in 1:nrow(actual.dates)){
    # If Matching Fields and DOY exist in SMR folder
    if (fields[j] %in% ascii.files$field && actual.dates$DOY[i] %in% ascii.files$DOY) {
      # Find testfile name from ascii.files with match
      testfile <- subset(ascii.files, DOY == actual.dates$DOY[i] & field == fields[j])$filename[1]
      print(testfile)
      smr <- raster(paste(smrpath, fields[j], "/", testfile, sep = ""))
      raw_smr <- raster::extract(smr, coords_field)
      temp <- data.frame(raw_smr)
      temp$sensor <- c(1:12)
      temp$field <- c(fields[j])
      temp$DOY <- c(actual.dates$DOY[i])
      temp$filename <- testfile
      smr_output <- rbind(smr_output, temp)
    }
  }
}

# Remove any duplicates
smr_output <- unique(smr_output)
smr_output[order(smr_output$filename), ]

# Join the new smr_output dataframe to the sensor.subset (actual SM) data
merge_sm <- merge(smr_output, sensors.subset, c("DOY", "field", "sensor"))
merge_sm <- merge_sm[order(merge_sm$sensor), ]
merge_sm


#ERROR CALCULATIONS

# Set Actual and Predicted data
actual <- merge_sm$sm_mean
predicted <- merge_sm$raw_smr

# Calculate error
error <- actual - predicted
merge_sm$error <- abs(error)

# Root Mean Squared Error
rmse <- sqrt(mean(error ^ 2, na.rm = TRUE))

# Mean Absolute Error
mae <- mean(abs(error), na.rm = TRUE)
rmse
mae

#Save final CSV of merged SM data locally
write.csv(merge_sm, file <- "C:/Users/Samir Patel/Desktop/Data 590 -
          Capstone I/Hydrologic Model/SMR 2-7-18/SMR/merge_sm.csv",
          row.names = FALSE)



# Counting uniques as a double check
nrow(unique(merge_sm[c("date", "field")]))

nrow(unique(actual.dates))

nrow(subset(actual.dates, field == "AES" | field == "OD"))

subset(actual.dates, field == "AES" | field == "OD")

sm.unique <- subset(actual.dates, field == "AES" | field == "OD")
sm.unique <- sm.unique[order(sm.unique$DOY), ]

nrow(sm.unique)
View(sm.unique)