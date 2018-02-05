library(tidyverse)
library(stringr)

twitter <- read.csv("data/twitter.csv")
twitter <- as.tibble(twitter)
names(twitter) <- c("kecamatan", "kotaadm", "did", "numpoints", "persentase")
twitter$kecamatan <- twitter$kecamatan %>%
  str_to_lower() %>%
  str_replace_all("_", ".")

twitter$kotaadm <- twitter$kotaadm %>%
  str_to_lower() %>%
  str_replace_all("_", ".")

join.twit <- twitter %>%
  left_join(kepadatan.kec, by = "kecamatan") %>%
  mutate(twitter_kepadatan = numpoints / luas)
write.csv(join.twit, "output/join.twit.csv")

join.all <- left_join(join.twit, join.summary)
join.all[, c(5, 6, 10, 12)] <- NULL
names(join.all) <- c("kecamatan", "kotaadm", "id", "twit.populasi", "kec.luas", "kec.kepadatan", "twit.kepadatan", "model.populasi", "model.kepadatan")
join.all <- join.all[, c(3,1,2,5,8,4,6,9,7)]
join.all <- join.all %>%
  mutate(model.persen = model.populasi / sum(model.populasi) * 100,
         twit.persen = twit.populasi / sum(twit.populasi) * 100,
         model.kepadatan.persen = model.kepadatan / sum(model.kepadatan) * 100,
         twit.kepadatan.persen = twit.kepadatan / sum(twit.kepadatan) * 100,
         validasi = model.kepadatan.persen / twit.kepadatan.persen)
write.csv(join.all, "output/join.all.csv")



join.twit %>%
  transform(kecamatan=factor(kecamatan,levels=c(jakut, jaktim, jaksel, jakpus, jakbar))) %>%
  ggplot(aes(twitter_kepadatan)) +
  geom_line(aes(color = kotaadm)) +
  facet_wrap(~ kecamatan) 


t.test(join.all$model.kepadatan, join.all$twit.kepadatan)
var.test(join.all$model.kepadatan, join.all$twit.kepadatan)

t.test(join.all$model.kepadatan.persen, join.all$twit.kepadatan.persen)
var.test(join.all$model.kepadatan.persen, join.all$twit.kepadatan.persen)




png("histogram_twitter.png")
hist(difference$twitter_NUMPOINTS)
dev.off()

png("histogram_model.png")
hist(difference$result_populasi)
dev.off()

png("pmf_twitter.png")
hist(difference$twitter_percentage)
dev.off()

png("pmf_model.png")
hist(difference$persentase)
dev.off()