# Code adapted from Danczak et al. 2020, https://github.com/danczakre/Meta-Metabolome_Ecology

### Script to process FTICR-MS reports generated by Formularity (Tolić et al, 2017 - Anal. Chem.)
# RED 2020; robert.danczak@pnnl.gov; danczak.6@gmail.com

## Loading libraries 

library(tidyverse)

require(ftmsRanalysis) # package found at https://github.com/EMSL-Computing/ftmsRanalysis

Sample_Name = "Abisko" # Sample name for output
summary = T # This is a switch which will generate compound class and characteristics summary files


### Load in data ###

report = read_csv("input/Report_updated.csv")
  
#read metadata

metadata = read.csv("input/metadata_updated.csv") %>% 
  filter(Sampletype == "solid")# filtering only peat samples

##create a filtered metadata and match with the mass (this is a very important step, if mass are not filtered accordingly
## trees generated will be similar)

sub_report <- report %>% 
  select(Mass, C, H, O, N, C13, S, P, Na, El_comp, Class, NeutralMass,
         Error_ppm, Candidates, metadata$SampleID )

sub_report <- column_to_rownames(sub_report, var = 'Mass')

## Filtering masses

selected_masses <- sub_report %>% 
  select(metadata$SampleID)

selected_masses$sum <- rowSums(selected_masses)

selected_masses <- filter(selected_masses, sum > 0)

sub_report <- sub_report[rownames(sub_report) %in% rownames(selected_masses),]
sub_report <- rownames_to_column(sub_report, var = 'Mass')


# Separating molecular information and peak data

emeta = sub_report[, c("Mass", "C", "H", "O", "N", "C13", "S", "P", "Na", "El_comp", 
               "Class", "NeutralMass", "Error_ppm", "Candidates")]

edata = sub_report[,-which(colnames(sub_report) %in% c("C", "H", "O", "N", "C13", "S", "P", "Na", "El_comp", 
                                          "Class", "NeutralMass", "Error_ppm", "Candidates"))]
rm("sub_report") # Removing report

#### Creating empty factors data ####
fdata = data.frame(Sample_ID = colnames(edata)[-1], Location = "Somewhere")

### Convert data and remove isotopic peaks ###
peak_icr = as.peakData(e_data = edata, f_data = fdata, e_meta = emeta, edata_cname = "Mass", mass_cname = "Mass",
                          fdata_cname = "Sample_ID", c_cname = "C", h_cname = "H", o_cname = "O", n_cname = "N", s_cname = "S",
                          p_cname = "P", isotopic_cname = "C13", isotopic_notation = "1")

### Calculating derived statistics ####
peak_icr = compound_calcs(peak_icr)

### Assigning compound classes ###
peak_icr = assign_class(peak_icr, boundary_set = "bs1")
peak_icr = assign_class(peak_icr, boundary_set = "bs2")
peak_icr = assign_class(peak_icr, boundary_set = "bs3")

### Filtering peaks ###

filter_obj = mass_filter(peak_icr)

## Important options here:
### 1. Mass filtered between 200 and 900 
### 2. Minimum number of times each mass must be observed across samples = 2 (default)

peak_icr = applyFilt(filter_obj, peak_icr, min_mass = 200, max_mass = 900, min_num = 2)

## Write results ###
write.csv(peak_icr$e_data, paste0("output/Processed_", Sample_Name, "_Data.csv", sep = ""), quote = F, row.names = F)
write.csv(peak_icr$e_meta, paste0("output/Processed_", Sample_Name, "_Mol.csv", sep = ""), quote = F, row.names = F)


############### Summary generation ############### 

if(summary == T){
  # Setting peak_icr objects and row names
  edata = peak_icr$e_data
  emeta = peak_icr$e_meta
  
  row.names(edata) = edata$Mass; edata = edata[,-which(colnames(edata) %in% "Mass")]
  row.names(emeta) = emeta$Mass; emeta = emeta[,-which(colnames(emeta) %in% "Mass")]
  
  #### Compound class summary
  # Finding unique compound classes
  uniq.comp = unique(peak_icr$e_meta$bs2_class)
  
  # Looping through each sample to obtain some summary categoreies
  classes = matrix(nrow = ncol(edata), ncol = length(uniq.comp)) # Creating empty matrix to store stats
  colnames(classes) = uniq.comp
  row.names(classes) = colnames(edata)
  
  name.temp = NULL
  
  for(i in 1:ncol(edata)){
    temp = edata[which(edata[,i] > 0), i, drop = F] # Need to keep names, looking at columns
    temp = emeta[row.names(temp),]
    
    for(j in 1:length(uniq.comp)){
      classes[i,j] = length(which(temp$bs2 %in% uniq.comp[j]))
    }
    
    name.temp = c(name.temp, colnames(edata)[i])
  } # I'm not sure how to do this without the for-loop, but I'm simply just finding the mean/median for peak stats
  
  classes = as.data.frame(classes)
  
  write.csv(classes, paste("output/", Sample_Name, "_Compound_Class_Summary.csv", sep = ""), quote = F)
  
  
  #### Characteristics summary
  # Looping through each sample to obtain some summary stats of the peaks
  characteristics = data.frame(AI.mean = rep(NA, length(colnames(edata))), AI.median = NA, AI.sd = NA,
                               AI_Mod.mean = NA, AI_Mod.median = NA, AI_Mod.sd = NA,
                               DBE.mean = NA, DBE.median = NA, DBE.sd = NA,
                               DBE_O.mean = NA, DBE_O.median = NA, DBE_O.sd = NA,
                               KenMass.mean = NA, KenMass.median = NA, KenMass.sd = NA,
                               KenDef.mean = NA, KenDef.median = NA, KenDef.sd = NA,
                               NOSC.mean = NA, NOSC.median = NA, NOSC.sd = NA,
                               Gibbs.mean = NA, Gibbs.median = NA, Gibbs.sd = NA, 
                              row.names = colnames(edata))
  
  for(i in 1:ncol(edata)){
    temp = edata[which(edata[,i] > 0), i, drop = F] # Need to keep names, looking at columns
    temp = emeta[row.names(temp),]
    
    # AI
    characteristics$AI.mean[i] = mean(temp$AI, na.rm = T)
    characteristics$AI.median[i] = median(temp$AI, na.rm = T)
    characteristics$AI.sd[i] = sd(temp$AI, na.rm = T)
    
    # AI_Mod
    characteristics$AI_Mod.mean[i] = mean(temp$AI_Mod, na.rm = T)
    characteristics$AI_Mod.median[i] = median(temp$AI_Mod, na.rm = T)
    characteristics$AI_Mod.sd[i] = sd(temp$AI_Mod, na.rm = T)
    
    # DBE
    characteristics$DBE.mean[i] = mean(temp$DBE, na.rm = T)
    characteristics$DBE.median[i] = median(temp$DBE, na.rm = T)
    characteristics$DBE.sd[i] = sd(temp$DBE, na.rm = T)
    
    # DBE-O
    characteristics$DBE_O.mean[i] = mean(temp$DBE_O, na.rm = T)
    characteristics$DBE_O.median[i] = median(temp$DBE_O, na.rm = T)
    characteristics$DBE_O.sd[i] = sd(temp$DBE_O, na.rm = T)
    
    # Kendrick Mass
    characteristics$KenMass.mean[i] = mean(temp$kmass, na.rm = T)
    characteristics$KenMass.median[i] = median(temp$kmass, na.rm = T)
    characteristics$KenMass.sd[i] = sd(temp$kmass, na.rm = T)
    
    # Kendrick Defect
    characteristics$KenDef.mean[i] = mean(temp$kdefect, na.rm = T)
    characteristics$KenDef.median[i] = median(temp$kdefect, na.rm = T)
    characteristics$KenDef.sd[i] = sd(temp$kdefect, na.rm = T)
    
    # NOSC
    characteristics$NOSC.mean[i] = mean(temp$NOSC, na.rm = T)
    characteristics$NOSC.median[i] = median(temp$NOSC, na.rm = T)
    characteristics$NOSC.sd[i] = sd(temp$NOSC, na.rm = T)
    
    # Gibbs Free Energy
    characteristics$Gibbs.mean[i] = mean(temp$GFE, na.rm = T)
    characteristics$Gibbs.median[i] = median(temp$GFE, na.rm = T)
    characteristics$Gibbs.sd[i] = sd(temp$GFE, na.rm = T)
    
  } # I'm not sure how to do this without the for-loop, but I'm simply just finding the mean/median for peak stats
  
  write.csv(characteristics, paste("output/",Sample_Name, "_MolInfo_Summary.csv", sep = ""), quote = F)
  
}
