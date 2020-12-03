#structural diversity tutorial
#https://www.neonscience.org/structural-diversity-discrete-return

library(lidR)
library(gstat)
library(neondiversity)

############### Set working directory ######
#set the working of the downloaded data
wd <- "/Users/rana7082/Documents/research/forest_structural_diversity/data/"
setwd(wd)

############ Read in LiDAR data ###########
#SJER <- readLAS(paste0(wd,"NEON_D17_SJER_DP1_255000_4110000_classified_point_cloud_colorized.laz"))
SJER <- readLAS(paste0(wd,"NEON_D17_SJER_DP1_255000_4110000_classified_point_cloud_colorized.laz"),
                filter = "-drop_z_below 187 -drop_z_above 616")
summary(SJER)
#plot(SJER)


#set center of plot based on extent
x <- ((max(SJER$X) - min(SJER$X))/2)+ min(SJER$X)
y <- ((max(SJER$Y) - min(SJER$Y))/2)+ min(SJER$Y)

#x <- 255500 #easting 
#y <- 4110500 #northing

data.200m <- lasclipRectangle(SJER, 
                              xleft = (x - 100), ybottom = (y - 100),
                              xright = (x + 100), ytop = (y + 100))

dtm <- grid_terrain(data.200m, 1, kriging(k = 10L))

data.200m <- lasnormalize(data.200m, dtm)

data.40m <- lasclipRectangle(data.200m, 
                             xleft = (x - 20), ybottom = (y - 20),
                             xright = (x + 20), ytop = (y + 20))
data.40m@data$Z[data.40m@data$Z <= .5] <- 0  
plot(data.40m)
#not sure if this looks right


#Zip up all the code we previously used and write function to 
#run all 13 metrics in a single function. 
structural_diversity_metrics <- function(data.40m) {
  chm <- grid_canopy(data.40m, res = 1, dsmtin()) 
  mean.max.canopy.ht <- mean(chm@data@values, na.rm = TRUE) 
  max.canopy.ht <- max(chm@data@values, na.rm=TRUE) 
  rumple <- rumple_index(chm) 
  top.rugosity <- sd(chm@data@values, na.rm = TRUE) 
  cells <- length(chm@data@values) 
  chm.0 <- chm
  chm.0[is.na(chm.0)] <- 0 
  zeros <- which(chm.0@data@values == 0) 
  deepgaps <- length(zeros) 
  deepgap.fraction <- deepgaps/cells 
  cover.fraction <- 1 - deepgap.fraction 
  vert.sd <- cloud_metrics(data.40m, sd(Z, na.rm = TRUE)) 
  sd.1m2 <- grid_metrics(data.40m, sd(Z), 1) 
  sd.sd <- sd(sd.1m2[,3], na.rm = TRUE) 
  Zs <- data.40m@data$Z
  Zs <- Zs[!is.na(Zs)]
  entro <- entropy(Zs, by = 1) 
  gap_frac <- gap_fraction_profile(Zs, dz = 1, z0=3)
  GFP.AOP <- mean(gap_frac$gf) 
  LADen<-LAD(Zs, dz = 1, k=0.5, z0=3) 
  VAI.AOP <- sum(LADen$lad, na.rm=TRUE) 
  VCI.AOP <- VCI(Zs, by = 1, zmax=100) 
  out.plot <- data.frame(
    matrix(c(x, y, mean.max.canopy.ht,max.canopy.ht, 
             rumple,deepgaps, deepgap.fraction, 
             cover.fraction, top.rugosity, vert.sd, 
             sd.sd, entro, GFP.AOP, VAI.AOP,VCI.AOP),
           ncol = 15)) 
  colnames(out.plot) <- 
    c("easting", "northing", "mean.max.canopy.ht.aop",
      "max.canopy.ht.aop", "rumple.aop", "deepgaps.aop",
      "deepgap.fraction.aop", "cover.fraction.aop",
      "top.rugosity.aop","vert.sd.aop","sd.sd.aop", 
      "entropy.aop", "GFP.AOP.aop",
      "VAI.AOP.aop", "VCI.AOP.aop") 
  print(out.plot)
}

SJER_structural_diversity <- structural_diversity_metrics(data.40m)



#####################################
#diversity data
devtools::install_github("admahood/neondiversity")

# load packages
library(neonUtilities)
library(geoNEON)
library(dplyr, quietly=T)
library(downloader)
library(ggplot2)
library(tidyr)
library(doBy)
library(sf)
library(sp)
library(devtools)
library(neondiversity)

#no cover data at this site
coverS <- loadByProduct (dpID = "DP1.10058.001", site = 'SJER')

coverDivS <- coverS[[2]]

unique(coverDivS$divDataType)

cover2S <- coverDivS %>%
  filter(divDataType=="plantSpecies")

all_SR <-length(unique(cover2S$scientificName))

summary(cover2S$nativeStatusCode)

#subset of invasive only
inv <- cover2S %>%
  filter(nativeStatusCode=="I")

exotic_SR <-length(unique(inv$scientificName))


SJER_table <- cbind(SJER_structural_diversity, all_SR, exotic_SR)

SJER_table <- SJER_table %>%
  mutate(Site.ID = "SJER")


SJER_table <- SJER_table %>%
  select(-easting, -northing)

SJER_table <- SJER_table %>%
  left_join(veg_types)


combo6 <- rbind(combo5, SJER_table)
combo6

write.table(combo6, file = "prelim_results.csv", sep = ",", row.names = FALSE)

library(ggplot2)
ggplot(combo6, aes(x = mean.max.canopy.ht.aop, y = exotic_SR))+
  geom_point()

ggplot(combo6, aes(x = max.canopy.ht.aop, y = exotic_SR))+
  geom_point()

ggplot(combo6, aes(x = rumple.aop, y = exotic_SR))+
  geom_point()