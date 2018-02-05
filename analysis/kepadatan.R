library(tidyverse)
library(stringr)

kepadatan <- read.csv("data/kepadatan.csv")
kepadatan <- as.tibble(kepadatan)

kepadatan <- select(kepadatan, NAMA.KABUPATEN.KOTA:NAMA.KECAMATAN, LUAS.WILAYAH..KM2.:KEPADATAN..JIWA.KM2.)
names(kepadatan) <- c("kotamadya", "kecamatan", "luas", "kepadatan")

kepadatan$kecamatan <- kepadatan$kecamatan %>%
                       str_replace_all(" ", ".") %>%
                       str_to_lower()     

kepadatan$kotamadya <- kepadatan$kotamadya %>%
                       str_replace_all(" ", ".") %>%
                       str_to_lower()

y <- vector()
for (j in kotamadya.name) {
  x <- filter(kepadatan, kotamadya == j)
  y <- rbind(y, x)
}
kepadatan <- y

kepadatan.kec <- kepadatan %>%
                 group_by(kecamatan, kotamadya) %>% 
                 summarise(luas = sum(luas), kepadatan = sum(kepadatan)) %>%
                 arrange(kotamadya)


join <- data %>%
  left_join(kepadatan.kec, by = "kecamatan") %>%
  mutate(model_kepadatan = populasi / luas)

join.summary <- data.summary %>%
  left_join(kepadatan.kec, by = "kecamatan") %>%
  mutate(model_kepadatan = populasi / luas)


join %>%
  transform(kecamatan=factor(kecamatan,levels=c(jakut, jaktim, jaksel, jakpus, jakbar))) %>%
  ggplot(aes(x = hour, y = model_kepadatan)) +
  geom_line(aes(color = kotamadya.x)) +
  facet_wrap(~ kecamatan) 
