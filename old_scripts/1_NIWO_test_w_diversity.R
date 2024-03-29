#structural diversity tutorial
#https://www.neonscience.org/structural-diversity-discrete-return

library(lidR)
library(gstat)
library(neondiversity)


wd <- "/Users/rana7082/Documents/research/forest_structural_diversity/data/"
setwd(wd)

###
#original code, random tile#
NIWO <- readLAS(paste0(wd,"NEON_D13_NIWO_DP1_454000_4425000_classified_point_cloud_colorized.laz"))
#NIWO <- readLAS(paste0(wd,"NEON_D13_NIWO_DP1_454000_4425000_classified_point_cloud_colorized.laz"),
                #filter = "-drop_z_below 2460 -drop_z_above 2947")

#remove outliers by classifying as noise, then removing noise
NIWO <- lidR::classify_noise(NIWO, sor(15,3))
NIWO <- filter_poi(NIWO, Classification != LASNOISE)

summary(NIWO)


#find center point of tile
x <- ((max(NIWO$X) - min(NIWO$X))/2)+ min(NIWO$X)
y <- ((max(NIWO$Y) - min(NIWO$Y))/2)+ min(NIWO$Y)

#x <- 454500 
#y <- 4425608

#subset to 200 m x 200 m (40,000m2) subtile
data.200m <- lasclipRectangle(NIWO, 
                              xleft = (x - 100), ybottom = (y - 100),
                              xright = (x + 100), ytop = (y + 100))

#creates rasterized digital terrain model
dtm <- grid_terrain(data.200m, 1, kriging(k = 10L))

#normalize the data based on the digital terrain model (correct for elevation)
data.200m <- lasnormalize(data.200m, dtm)

#might not need this step
#subset to a 40 m x 40 m (1600m2) subtile
data.40m <- lasclipRectangle(data.200m, 
                             xleft = (x - 20), ybottom = (y - 20),
                             xright = (x + 20), ytop = (y + 20))

#replaces really short veg with zeros
data.40m@data$Z[data.40m@data$Z <= .5] <- 0  
plot(data.40m)


#calculate structural diversity metrics 
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

NIWO_structural_diversity <- structural_diversity_metrics(data.40m)






#####################################
#diversity data
#devtools::install_github("admahood/neondiversity")

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
library(rgdal)

coverN <- loadByProduct (dpID = "DP1.10058.001", site = 'NIWO', check.size= FALSE)

#cover is measured in 1 m2 subplots
coverDivN <- coverN[[3]]

#OR could also get species richness from 10 m2 subplots, but no cover data#
coverDivN10 <- coverN[[2]]

#subplot info
locations1 <-unique(coverDivN1[c("plotID", "subplotID", "decimalLatitude", "decimalLongitude")])
locations10 <-unique(coverDivN10[c("plotID", "subplotID", "decimalLatitude", "decimalLongitude")])

#plot info
#33 plots for NIWO
plots <-unique(coverDivN1[c("plotID", "decimalLatitude", "decimalLongitude")])

#view plot locations
ggplot() + 
  geom_sf() +
  geom_point(data = plots, aes(x = decimalLongitude, y = decimalLatitude), size = 2, color = "darkred") 


unique(coverDivN$divDataType)

cover2N <- coverDivN %>%
  filter(divDataType=="plantSpecies")

cover2N$monthyear <- substr(cover2N$endDate,1,7)

dates <- unique(cover2N$monthyear)
dates

#extract data for monthyear combo of interest
#pull in list of monthyear combo by site
cover2N <- cover2N %>%
  filter(monthyear == '2018-08' | monthyear == '2019-08' | monthyear == '2020-08')

all_SR <- cover2N %>%
  group_by(monthyear, plotID) %>%
  summarize(all_SR =length(scientificName))

#all_SR <-length(unique(cover2N$scientificName))

summary(cover2N$nativeStatusCode)
#no 'I's...what are NIs?

#subset of invasive only; here zero invasives at NIWO
inv <- cover2N %>%
  filter(nativeStatusCode=="I")

#calculate SR of nonnatives
nonnative_SR <- inv %>%
  group_by(monthyear, plotID) %>%
  summarize(nonnative_SR =length(scientificName))

#total SR of exotics across all plots
#exotic_SR <-length(unique(inv$scientificName))

#mean percent cover of nonnatives by plot and monthyear
nonnative_cover <- inv %>%
  group_by(monthyear, plotID) %>%
  summarize(sumz = sum(percentCover, na.rm = TRUE)) %>%
  summarize(nonnative_cov = mean(sumz))

#need to make the table now to have spaces for each plot, monthyear combo
NIWO_table <- cbind(NIWO_structural_diversity, all_SR, nonnative_SR, nonnative_cover)

NIWO_table <- NIWO_table %>%
  mutate(Site.ID = "NIWO")

NIWO_table <- NIWO_table %>%
  select(-easting, -northing)

veg_types <- read.csv(file = '/Users/rana7082/Documents/research/forest_structural_diversity/data/field-sites.csv') %>%
  select(Site.ID, Dominant.NLCD.Classes)

NIWO_table <- NIWO_table %>%
  left_join(veg_types)

NIWO_table



#############################################
#calculate spectral reflectance as CV
#as defined here: https://www.mdpi.com/2072-4292/8/3/214/htm
f <- paste0(wd,"NEON_D13_NIWO_DP3_453000_4427000_reflectance.h5")


###
#for each of the 426 bands, I need to calculate the mean reflectance and the SD reflectance across all pixels 

myNoDataValue <- as.numeric(reflInfo$Data_Ignore_Value)

dat <- data.frame()

for (i in 1:426){
  #extract one band
  b <- h5read(f,"/NIWO/Reflectance/Reflectance_Data",index=list(i,1:nCols,1:nRows)) 
  
  # set all values equal to -9999 to NA
  b[b == myNoDataValue] <- NA
  
  #calculate mean and sd
  meanref <- mean(b, na.rm = TRUE)
  SDref <- sd(b, na.rm = TRUE)
  
  rowz <- cbind(i, meanref, SDref)
  
  dat <- rbind(dat, rowz)
}

dat

dat$calc <- dat$SDref/dat$meanref

CV <- sum(dat$calc)/426


NIWO_table$specCV <- CV






######################
#soil chem for NIWO
NIWO_soil_chem_0 <- read.csv(file = 'NEON.D13.NIWO.DP1.00097.001.mgc_perbiogeosample.2014-08.basic.20191014T212752Z.csv')
  

NIWO_soil_chem <- read.csv(file = 'NEON.D13.NIWO.DP1.00097.001.mgc_perbiogeosample.2014-08.basic.20191014T212752Z.csv') %>%
  select(siteID, carbonTot, horizonName) %>%
  rename(Site.ID = siteID) %>%
  mutate(horizon = ifelse(horizonName == "A1" | horizonName == "A2", "A", ifelse(horizonName == "Bw1" | horizonName == "Bw2", "B", "C")))


