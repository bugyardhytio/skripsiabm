#Script ini berisi rangkaian analisis dalam penelitian saya
#Penjelasan lebih lanjut bisa dilihat di laporannya

library(tidyverse)

jakut  <- c("cilincing", "koja", "kelapa.gading", "tanjung.priok", "pademangan", "penjaringan")
jaktim <- c("cipayung", "ciracas", "makasar", "pasar.rebo", "duren.sawit", "kramat.jati", "cakung", "jatinegara", "pulo.gadung", "matraman")
jaksel <- c("tebet", "pasar.minggu", "pancoran", "mampang.prapatan", "setiabudi", "cilandak", "kebayoran.baru", "kebayoran.lama", "pesanggrahan", "jagakarsa")
jakpus <- c("menteng", "gambir", "senen", "cempaka.putih", "kemayoran", "tanah.abang", "johar.baru", "sawah.besar")
jakbar <- c("taman.sari", "tambora", "palmerah", "grogol.petamburan", "kalideres", "kembangan", "cengkareng", "kebon.jeruk")

kotamadya <- list(jakut, jaktim, jaksel, jakpus, jakbar)
kotamadya.name <-c("jakarta.utara", "jakarta.timur", "jakarta.selatan", "jakarta.pusat", "jakarta.barat")


#Buka file
data <- read.csv(file.choose(), skip = 26)
raw <- data 

#Delete column gak kepake
data[, c(1, 4, 47, 48, 49, 50)] <- NULL
data <- as.tibble(data)
names(data) <- c("minute", "hour", jakut, jaktim, jaksel, jakpus, jakbar) 

#Make tidy data
data <- data %>%
  gather(-hour, -minute, key = "kecamatan", value = "populasi") %>%
  group_by(hour, kecamatan) %>%
  summarise(populasi = mean(populasi)) #Aggregate by hour 

# Enrichment ---------------------------------------------------------


y <- vector()
for (i in seq_along(kotamadya)){
  for (j in kotamadya[[i]]) {
    x <- data %>%
         filter(kecamatan == j) %>%
         mutate(kotamadya = kotamadya.name[i])
    y <- rbind(y, x)   
  }
}
data <- y[, c(1,2,4,3)]

data <- data %>%
  left_join(kepadatan.kec, by = "kecamatan") %>%
  mutate(model.kepadatan = populasi / luas * 100)

# Ploting ---------------------------------------------------------------


data %>%
  transform(kecamatan=factor(kecamatan,levels=c(jakut, jaktim, jaksel, jakpus, jakbar))) %>%
  ggplot(aes(x = hour, y = model.kepadatan)) +
  geom_line(aes(color = kotamadya.x)) +
  facet_wrap(~ kecamatan) 
ggsave("timeseries.png", width = 11.78, height = 7.86)


#Gak tau jam berapa mulai turun naik pergerakaannya
activity.data <- read.csv("data/eksperimen/Mei/29 Mei/activity.csv", skip = 19)
activity.data <- as.tibble(activity.data)
activity.data <- activity.data[, c(1,2,6,10)]
names(activity.data) <- c("ticks", "work", "move", "home")
activity.data <- gather(activity.data, -ticks, key = "activity", value = "num.agents")

i <- seq(0,59)
j <- seq(0,23)
for (k in j) {
  for (l in i) {
    mutate(activity.data, minute = i[l])
  }
  mutate(activity.data, hour = j[k])
}

ggplot(activity.data) + geom_col(aes(x = ticks, y = num.agents, fill = activity))

#Gak terlihat mana kecamatan yang meningkat dan yang menurun
data %>%
  filter(hour > 7 && hour < 18) %>%
  group_by(kecamatan, kotamadya.x) %>%
  summarise(model.kepadatan = mean(model.kepadatan)) %>%
  transform(kecamatan=factor(kecamatan,levels=c(jakut,jaktim,jaksel,jakpus,jakbar))) %>%
  ggplot() + 
  geom_col(aes(x = kecamatan, y = model.kepadatan, fill = kotamadya.x)) +
  coord_flip()
