# read in raw data
library(readxl)

get_samples <- function(file) {
  dat <- read_excel(file)
  return(dat)
}

get_sites <- function(file) {
  dat <- read.csv(file, stringsAsFactors = F, colClasses = c(STAID = "character"))
  dat$STAID <- ifelse(nchar(dat$STAID) < 15, paste0('0', dat$STAID), dat$STAID)
  return(dat)
}

get_mke_data <- function() {
  sites <- c("040870377", "430213088063601", "040871474", "04087100",
                   "04087118", "04087147", "040871607", "0408703164", "04086949",
                   "04086898", "04086940", "04086953", "04087054",
                   "04087051", "04087072", "040871465", "04087040",
                   "040870182", "04087143", "040870837", "0408703101", "04087000",
                   "04087170", "04087012", "04086800", "431046087595401",
                   "04087060", "430907088002101", "430217088063101",
                   "430205088064101", "430904088004001", "425659088003901",
                   "425700088002601", "040872138", "040872118", "040872119",
                   "040872127", "040872139", "04087125", "040870851", "040870889",
                   "04087085631", "040871468", "040870195", "04087148", "040871488",
                   "04087119", "04087159", "040869415", "04087214", "04087088", "04087220",
                   "04087142", "04087120", "04087204", "04087070", "04087030",
                   "040870195", "04086600")
  
  pcodes <- c("64126", "91107", "90756", "64119", "64116", "64111", "64106", "64100",
                   "64095", "63187", "64142", "64120", "64118", "64141", "64136", "64134",
                   "64129", "64114", "64113", "64112", "64109", "64105", "64102", "64099",
                   "63194", "63180", "64140", "64130", "64125", "64124", "64121", "64104",
                   "63650", "63227", "63224", "63183", "63181", "64131", "64128", "64123",
                   "64115", "64103", "64097", "63631", "63220", "64139", "64137", "64127",
                   "64122", "90754", "63610", "64145", "64143", "64138", "64135", "64117",
                   "64108", "64107", "64101", "63208", "64146", "64144", "64133", "64132",
                   "90755", "63202", "63167", "00687","34223", "34524", "34384", "34323",
                   "34559", "34250", "34245", "34379", "34208", "34406", "34464", "34472", "34529", "34203", "34445", "62555")
  
  startDate <- '2014-04-01'
  endDate <- '2014-09-01'
  mke_pah <- getPAH(sites, pcodes, startDate, endDate)
  return(mke_pah)
}

get_glri6_data <- function(all_sites, all_samples) {
  # find pcodes for OWC schedule #5433
  url <- "http://nwqlqc/servlets_u/AnalyticalServicesGuide?srchStr=5433&srchType=sched&mCrit=exact&oFmt=xl"
  destfile <- "AnalyticalServicesGuide_srchStr_5433_srchType_sched_mCrit_exact_oFmt_xl.xls"
  curl::curl_download(url, destfile)
  schedule_5433 <- read_excel(destfile)
  # filter pcodes to include only those in Austin's list of pcodes (I am assuming)
  # this is complete - maybe verify this

  pcodes.keep1 <- filter(schedule_5433, `Parameter Code` %in% pah_pcodes) %>%
    select(`Parameter Code`, `Parameter Name`)
  
  pcodes.keep <- schedule_5433[grep('surrogate', schedule_5433$`Parameter Name`, ignore.case = T), ] %>%
    select(`Parameter Code`, `Parameter Name`) %>%
    bind_rows(pcodes.keep1)
  
  sites <- all_sites[['STAID']]
  test.site <- sites[26]
  startDate <- '2017-01-01'
  endDate <- '2017-12-31'
  glri6_pah <- getPAH(sites, pcodes = pcodes.keep[[1]], startDate, endDate)

  return(glri6_pah)
}

get_qa_data <- function(qa_type) {
  
  # get files from raw_data folder
  file.loc <- "1_get_raw_data/raw_data"
  sample.files <- list.files(file.loc)
  sample.files <- grep("S17", sample.files, value = T)
  sample.files <- grep(".xlsx", sample.files, value = T)
  
  all_dat <- data.frame()
  if (qa_type == 'mspikes'){
    for (i in sample.files) {
      # matrix spike recovery
      temp_dat <- read_excel(file.path(file.loc, i), sheet = "MS", 
                             skip = 21, col_names = T)
      temp_dat_filt <- temp_dat[,c(1, grep('recovery', names(temp_dat), ignore.case = T), grep('qualifier', names(temp_dat), ignore.case = T))]
      temp_dat_filt <- temp_dat_filt[grep("^Naphthalene$", temp_dat_filt[[1]]):grep("perylene", temp_dat_filt[[1]]),]
      # get rid of estimates in samples where the matrix spike was 
      # < 5x greater than the sample conc
      temp_dat_filt$`% Recovery` <- ifelse(temp_dat_filt$Qualifier %in% "n", NA, temp_dat_filt$`% Recovery`)
      
      all_dat <- bind_rows(temp_dat_filt, all_dat)
    }
    names(all_dat) <- c('compound', 'pct_recovery', 'qualifier')
  } else if (qa_type == 'labcontrol') {
    for (i in sample.files) {
      # lab control samples recovery
      temp_dat <- read_excel(file.path(file.loc, i), sheet = "LCS", 
                             skip = 21, col_names = T)
      temp_dat_filt <- temp_dat[,c(1, grep('recovery', names(temp_dat), ignore.case = T), grep('qualifier', names(temp_dat), ignore.case = T))]
      temp_dat_filt <- temp_dat_filt[grep("^Naphthalene$", temp_dat_filt[[1]]):grep("perylene", temp_dat_filt[[1]]),]
      
      # put into long format
      rec <- temp_dat_filt[, c(1, grep('recovery', names(temp_dat_filt), ignore.case = T))]
      rec <- gather(rec, key = 'column', value = 'pct_recovery', -"Units")
     
      all_dat <- bind_rows(rec, all_dat)
    }
    
    all_dat <- select(all_dat, -column) %>%
      rename(compound = Units)
  } else if (qa_type == 'pblanks') {
    for (i in sample.files) {
      # procedural blank samples recovery
      temp_dat <- read_excel(file.path(file.loc, i), sheet = "PB", 
                             skip = 23, col_names = F)
      
      col_names <- read_excel(file.path(file.loc, i), sheet = "PB", 
                              skip = 8, col_names = T)
      col_names <- names(col_names)
      col_comp <- grep('client', col_names, ignore.case = T)
      col_vals <- grep('blank', col_names, ignore.case = T)
      col_codes <- col_vals + 1
      
      rows_keep <- grep("^Naphthalene$", temp_dat[[1]]):grep("perylene", temp_dat[[1]])
      
      temp_vals_dat <- temp_dat[rows_keep, c(col_comp, col_vals)]
      names(temp_vals_dat) <- c('compound', paste0('value', 1:(ncol(temp_vals_dat)-1)))
      long_vals_dat <- gather(temp_vals_dat, key = old_column, value = value, -compound)
      
      temp_code_dat <- temp_dat[rows_keep, c(col_comp, col_codes)]
      names(temp_code_dat) <- c('compound', paste0('value', 1:(ncol(temp_code_dat)-1)))
      long_code_dat <- gather(temp_code_dat, key = old_column, value = code, -compound)
      
      return_dat <- data.frame(compounds = long_vals_dat$compound, 
                               values = long_vals_dat$value,
                               codes = long_code_dat$code)
      
      all_dat <- bind_rows(all_dat, return_dat)
    }
    } else if (qa_type == 'labdups') {
      
      for (i in sample.files) {
        # procedural blank samples recovery
        temp_dat <- read_excel(file.path(file.loc, i), sheet = "DUP", 
                               skip = 23, col_names = F, na = c('', 'NA'))
        
        col_names <- read_excel(file.path(file.loc, i), sheet = "DUP", 
                                skip = 21, col_names = T)
        col_names <- names(col_names)
        col_keep <- grep('units|rpd|qualifier', col_names, ignore.case = T)

        
        rows_keep <- grep("^Naphthalene$", temp_dat[[1]]):grep("perylene", temp_dat[[1]])
        
        temp_dat_clean <- temp_dat[rows_keep, col_keep]
        names(temp_dat_clean) <- c('compound', 'RPD', 'qualifier')
        
        all_dat <- bind_rows(all_dat, temp_dat_clean)
      }
    
    
  }
  return(all_dat)
}
  