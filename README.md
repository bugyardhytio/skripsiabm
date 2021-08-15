# Paper

[Publikasi](https://ejournal3.undip.ac.id/index.php/pwk/article/viewFile/20507/19550) yang menjelaskan model ini, atau [link alternatif](https://www.researchgate.net/publication/327968547_Model_Simulasi_Aktivitas_Pergerakan_Penduduk_Berbasis_Agen_Studi_Kasus_Provinsi_DKI_Jakarta).

Gunakan versi NetLogo 6.0.1 untuk run model.

# Pengembangan

Asumsi awal model dibuat untuk mensimulasikan struktur kota berdasarkan dinamika pergerakan penduduk. Tapi berdasarkan [reel pada post ini](https://www.instagram.com/reel/CSll_hunCD0/?utm_source=ig_web_copy_link), model kemungkinan bisa digunakan untuk generate data pergerakan harian penduduk pada daerah-daerah yang tidak dilayani ride-hailing semisal uber movement. Namun untuk mencapai hal tersebut ada beberapa perbaikan yang perlu dilakukan:
- Update untuk bisa di-run pada NetLogo versi terbaru. Hasil uji mengindikasikan tidak bisa dilakukan run pada NetLogo versi selain 6.0.1.
- Pemetaan guna lahan dan jaringan jalan untuk validasi dengan data Uber Movement. Ini yang penting. Agar valid (model bisa digunakan di kota manapun), perlu dilakukan pemetaan ulang pada kota-kota yang dilayani Uber Movement sebagai data test.
- Reproduksi model pada bahasa pemrograman/software lain. Repositori ini adalah toy model (model hanya untuk kepentingan studi akademis). Salah satu kendala dari model ini adalah jumlah maksimual penduduk sebesar 1000. Agar bisa memenuhi skala yang lebih besar dan kebutuhan bisnis (repurposing) dibutuhkan usaha untuk mengaplikasikan algoritma dengan bahasa/software lain.
- Perbaikan referensi. Mengingat kebutuhan awal model untuk kelulusan studi S1, keterbatasan waktu dan kemampuan pada waktu menyusun menyisakan beberapa line algoritma yang tidak tereferensi dengan baik. Hal ini bisa mencederai integritas akademis penulis, sehingga disarankan untuk mereferensi ulang algoritma pihak ketiga yang digunakan. Terutama pada aplikasi Djikstra, pergerakan turtle pada line dan scraping twitter.

# Kontak
Selain pada halaman github ini, penulis bisa dikontak pada [tautan berikut](https://linktr.ee/bugyardhytio)
