library(tidyr)
library(stringr)
setwd("~/Documents/1. Tugas Akhir/Analisis/validasi-twitter/raw")
files <- list.files()
data <- data.frame()

for (i in files){
  data <- rbind(data, read.csv(i, na.strings = ""))
}

data <- data[complete.cases(data), ] # Clean NA from dataset
data$location <- sapply(data$location, toString) # Convert location column to string
data$location <- str_extract(data$location, "\\d+.\\d+..-\\d+.\\d+") # Remove unnecessary part from location column
data <- separate(data, location, into = c("xcor", "ycor"), sep = ", ") # Separate coordinate from location
write.csv(data, "data-final.csv")