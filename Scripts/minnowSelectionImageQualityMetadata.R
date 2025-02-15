# selection of minnow images for the workflow
# Meghan Balk 
# balk@battelleecology.org

library(stringr)
library(tidyr)
library(dplyr)
library(ggplot2)

####LOAD DATA----

##image metadata and image quality metadata from Yasin
image.data <- read.csv("Image_Metadata_v1_20211206_151152.csv", header = TRUE) #images with metadata
image.quality <- read.csv("Image_Quality_Metadata_v1_20211206_151204.csv", header = TRUE)

##combing metadata
#link on image.data$file_name and image.quality$image_name
#must have "original_file_name" for snakemake

#extract just the minnows
minnow.quality <-  image.quality[image.quality$family == "Cyprinidae",]
nrow(minnow.quality) #20510
length(unique(minnow.quality$scientific_name)) #166

minnow.keep <- minnow.quality[minnow.quality$specimen_viewing == "left" & #facing left
                              minnow.quality$straight_curved == "straight"&
                              minnow.quality$brightness == "normal" &
                              minnow.quality$color_issues == "none" &
                              minnow.quality$has_ruler == "True" &
                              minnow.quality$if_overlapping == "False" &
                              minnow.quality$if_focus == "True" &
                              minnow.quality$if_missing_parts == "False" &
                              minnow.quality$if_parts_visible == "True" &
                              minnow.quality$fins_folded_oddly == "False",] 

nrow(minnow.keep) #10312
length(unique(minnow.keep$scientific_name)) #115

#we lose a lot of species when we include this
nrow(minnow.keep[minnow.keep$if_background_uniform == "True",]) #3533
length(unique(minnow.keep$scientific_name[minnow.keep$if_background_uniform == "True"])) #99

#merge subset of image quality metadata with the image metadata
images.minnows <- merge(image.data, minnow.keep, by.x = "original_file_name", by.y = "image_name")

#get rid of dupes!! image metadata has multiple users, so duplicates per fish
images.minnows.clean <- images.minnows[!duplicated(images.minnows$original_file_name),]
nrow(images.minnows.clean) #7811

#only INHS, UWZM
institutions <- c("INHS", "UWZM") #no uwzm
images.minnows.trim <- images.minnows.clean[images.minnows.clean$institution %in% institutions,]
nrow(images.minnows.trim) #6482
length(unique(images.minnows.trim$scientific_name.x)) #93

unique(images.minnows.trim$fish_number) 
#should be 1; don't want multiple fish per images because currently don't have a good way to keep metadata

##ask if url is empty and remove if it is
#1) see if url resolves
#2) see if file is empty
#3) if resolves & not empty, keep the path
#4) remove all other paths

#from stack overflow: https://stackoverflow.com/questions/52911812/check-if-url-exists-in-r
valid_url <- function(url_in,t=2){
  con <- url(url_in)
  check <- suppressWarnings(try(open.connection(con,open="rt",timeout=t),silent=T)[1])
  suppressWarnings(try(close.connection(con),silent=T))
  ifelse(is.null(check),TRUE,FALSE)
}
#test; images.minnows.trim$path[1]
valid_url(images.minnows.trim$path[1])

#from stack overflow: https://stackoverflow__com.teameo.ca/questions/63852146/how-to-determine-online-file-size-before-download-in-r
download_size <- function(url){
  as.numeric(httr::HEAD(url)$headers$`content-length`)
}
#test; images.minnows.trim$path[1]
download_size(images.minnows.trim$path[1])

test1 <- images.minnows.trim[1:10,]
#known url that doesn't work
##http://www.tubri.org/HDR/INHS/INHS_FISH_65294.jpg
##INHS_FISH_33814.jpg
test2 <- images.minnows.trim[images.minnows.trim$original_file_name == "INHS_FISH_33814.jpg" |
                             images.minnows.trim$path == "http://www.tubri.org/HDR/INHS/INHS_FISH_65294.jpg",]
  
empty <- c()
for(i in 1:nrow(images.minnows.trim)){
  if(!isTRUE(valid_url(images.minnows.trim$path[i]))){
    empty <- c(empty, images.minnows.trim$path[i])
  }
  else if(isTRUE(download_size(images.minnows.trim$path[i]) < 1048576)){
    empty <- c(empty, images.minnows.trim$path[i])
  }
  else{
    next
  }
}

images.minnows.resolve <- images.minnows.trim[!(images.minnows.trim$path %in% empty),]

#get sample size (number of images per species)
table.sp <- images.minnows.resolve %>%
  group_by(scientific_name.x) %>%
  summarise(sample.size = n())
nrow(table.sp) #93 sp

#retain only species for which there are 10 images
table.sp.10 <- table.sp$scientific_name.x[table.sp$sample.size >= 10]
length(table.sp.10) #41 sp

#trim dataset to match species with at least 10 species
images.minnows.10 <- images.minnows.resolve[images.minnows.resolve$scientific_name.x %in% table.sp.10,]
nrow(images.minnows.10) #6300

table.gen <- images.minnows.10 %>%
  group_by(genus.x) %>%
  summarise(sample.size = n())
nrow(table.gen) #4
unique(images.minnows.10$genus.x)

#write dataset without index
write.csv(images.minnows.10, "minnow.filtered.from.imagequalitymetadata_DATE.csv", row.names = FALSE)
