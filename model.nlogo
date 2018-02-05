extensions [ gis nw cf ]

globals [
  bounds-dataset
  landuse-dataset
  outer-bounds-dataset
  envelope-dataset

  openspace-patches
  tradearea-patches
  industry-patches
  facility-patches
  residential-patches
  workarea-patches

  working-agent
  moving-agent
  home-agent
  agent-on-traffic

  minute
  hour
  day

  minutes-per-ticks
]

undirected-link-breed [ streets street ]
breed [ peoples people ]
breed [ nodes node ]

peoples-own [
  location-record
  current-location

  activity
  occupation
  home-location
  work-location

  route-counter
  route
  target

  speed
  car-ahead

  working-time
  preparation-time
  trip-length
  trip-time
]

patches-own [ city landuse district ]
nodes-own [ route-length nodes-route use occupied? ]


;;;;;;;;;;;;;;;;;;
;;Main Procedure;;
;;;;;;;;;;;;;;;;;;


to setup
  clear-all

  setup-gis
  setup-globals
  setup-time
  setup-environment
  setup-roads
  setup-peoples

  ask peoples [
    setup-route
  ]

  count-by-activity
  reset-ticks
end


to go
  time-update

  ask peoples [
    run-schedule
    ;update-location
  ]

  count-by-activity

  if day > 0 [ stop ]

  tick
end



;;;;;;;;;;;;;;;;;;;;;;;;;
;;Environment Procedure;;
;;;;;;;;;;;;;;;;;;;;;;;;;


to setup-gis
  ;; Membaca shapefile
  set bounds-dataset                    gis:load-dataset "shapefile/bounds.shp"
  set landuse-dataset                   gis:load-dataset "shapefile/landuse.shp"
  set outer-bounds-dataset              gis:load-dataset "shapefile/outer-bounds.shp"
  set envelope-dataset                  gis:load-dataset "shapefile/box.shp"

  ;; Mengatur batasan tampilan kota
  gis:set-world-envelope (gis:envelope-of envelope-dataset)

  ;; Menerapkan atribut “guna-lahan” dan “kota” ke masing-masing patch
  gis:apply-coverage landuse-dataset "LANDUSE" landuse
  gis:apply-coverage bounds-dataset "KECAMATAN" district
end


to setup-globals
  set openspace-patches   patches with [landuse = "openspace"]
  set tradearea-patches   patches with [landuse = "commercial"]
  set industry-patches    patches with [landuse = "industrial"]
  set facility-patches    patches with [landuse = "facility"]
  set residential-patches patches with [landuse = "residential"]
  set workarea-patches    (patch-set tradearea-patches industry-patches facility-patches)
end


to setup-environment
  ;; Mengatur tampilan warna patch berdasarkan atribut guna lahan
  ask patches [set pcolor white]
  ask openspace-patches   [ set pcolor lime + 1    set landuse "Ruang Terbuka" ]
  ask facility-patches    [ set pcolor pink + 2    set landuse "Fasilitas Umum" ]
  ask industry-patches    [ set pcolor magenta + 1 set landuse "Industri" ]
  ask tradearea-patches   [ set pcolor red + 1     set landuse "Perdagangan dan Jasa"]
  ask residential-patches [ set pcolor yellow + 1  set landuse "Permukiman" ]

  ;; Menggambar batas administrasi
  gis:set-drawing-color black        gis:draw outer-bounds-dataset 1
end

to-report meters-per-patch
  let world gis:world-envelope ;
  let x-meters-per-patch (item 1 world - item 0 world) / (max-pxcor - min-pxcor)
  let y-meters-per-patch (item 3 world - item 2 world) / (max-pycor - min-pycor)
  report mean list x-meters-per-patch y-meters-per-patch
end


;;;;;;;;;;;;;;;;;;;
;;Roads Procedure;;
;;;;;;;;;;;;;;;;;;;

to setup-roads
  nw:set-context nodes streets
  nw:load "data/setup-roads.gdf" nodes streets
  ask nodes [street-setup]
  create-local-street
end

to create-local-street
  ask workarea-patches
  [
    sprout-nodes 1 [
      create-street-with min-one-of other nodes [distance myself]
      street-setup
      set use "work"
    ]
  ]
  ask n-of num-peoples residential-patches
  [
    sprout-nodes 1 [
      create-street-with min-one-of other nodes [distance myself]
      street-setup
      set use "home"
    ]
  ]
end

to street-setup
  set color grey + 5
  set size 0.05
  set shape "circle"
end


;;;;;;;;;;;;;;;;;;;;;
;;peoples Procedure;;
;;;;;;;;;;;;;;;;;;;;;

to setup-peoples
  create-peoples num-peoples

  ask peoples [
    set color blue
    set size 1

    set home-location one-of nodes with [use = "home" and occupied? = 0]
    ask home-location [set occupied? 1]
    setxy [pxcor] of home-location [pycor] of home-location
    assign-workplace

    set activity "persiapan"
    set working-time jam-kerja * 60
    set preparation-time jam-berangkat * 60

    set speed 0.1 + random-float 0.5

    set location-record []
  ]

  ;update-location
end

to assign-workplace
  let n-trade-worker    round (num-peoples * work-trade / 100)
  let n-industry-worker round (num-peoples * work-industry / 100)
  let n-service-worker  round (num-peoples * work-service / 100)
  let n-other-worker    (num-peoples - n-trade-worker - n-industry-worker - n-service-worker)

  let list-worker       (list n-service-worker n-industry-worker n-trade-worker n-other-worker)
  let list-work-patches (list facility-patches industry-patches tradearea-patches workarea-patches)
  let list-occupation   (list "public service" "industry" "trade" "others")

  (foreach list-worker list-work-patches list-occupation [ [a b c] ->
     ask n-of a peoples [
      set work-location one-of nodes-on b
      ask work-location [set occupied? occupied? + 1]
      set occupation c
    ]
  ])
end

to setup-route
  ask home-location [
    set nodes-route nw:turtles-on-path-to [work-location] of myself
    set route-length nw:distance-to [work-location] of myself
  ]
  ask nodes with [nodes-route != 0] [
    ask peoples-on self [
      set route-counter 0
      set route [nodes-route] of myself
      set target item 1 route
      set trip-length [route-length] of myself
    ]
  ]
end


; General movement procedure
to run-schedule
  cf:match ([activity] of self)
  cf:case [ [a] -> (a = "persiapan") ]
  [
    if (preparation-time <= 0) or (hour >= jam-berangkat)
    [
      set activity "berangkat"
      set route-counter 1
    ]
  ]
  cf:case [ [a] -> (a = "berangkat") ]
  [
    ifelse (patch-here != work-location)
    [ set color green
      face target
      if distance target = 0
      [ set route-counter route-counter + 1
        set trip-time trip-time + 1
        ifelse route-counter >= length route
        [ set activity "bekerja" ]
        [ set target item route-counter route
          face target ]
      ]
      ifelse distance target < 1
      [ move-to target ]
      [ move ]
    ]
    [ set activity "bekerja" ]
  ]
  cf:case [ [a] -> (a = "bekerja") ]
  [
    if (working-time > 0) or (hour >= jam-pulang)
    [
      set color red
      set activity "bekerja"
      set working-time working-time - minutes-per-ticks
    ]
    if working-time = 0 [ set activity "pulang" ]
  ]
  cf:case [ [a] -> (a = "pulang") ]
  [
    ifelse (patch-here != home-location)
    [ set color green
      face target
      if distance target = 0
      [ set route-counter route-counter - 1
        set trip-time trip-time + 1
        ifelse route-counter < 0
        [ set activity "istirahat" ]
        [ set target item route-counter route
          face target ]
      ]
      ifelse distance target < 1
      [ move-to target ]
      [ move ]
    ]
    [ set activity "istirahat" ]
  ]
  cf:else [ [a] -> set color blue ]
end

; Car Following Algorithm (Based on Traffic Basic Model)
to move
  set trip-time trip-time + 1
  set car-ahead one-of other moving-agent in-cone 1 30
  ifelse car-ahead != 0
    [ set car-ahead one-of other moving-agent in-cone 1 60 ]
    [ set car-ahead nobody ]
  ifelse car-ahead != nobody
    [ slow-down-car car-ahead
      if [car-ahead] of car-ahead = self
      [ set speed 0
        overturn ]
    ]
    [ speed-up-car ]

  if speed <= speed-min [ set speed speed-min ]
  if speed > speed-limit [ set speed speed-limit ]
  fd speed
end

to slow-down-car [ car-upfront ]
  set speed [ speed ] of car-upfront - deceleration
end

to speed-up-car
  set speed speed + acceleration
end

to overturn
  ;Menyingkir dari jalan
  rt 60
  fd 1
  lt 60
  lt 60
  fd 1
  ;Kembali ke jalan
  lt 60
  fd 1
  rt 60
end

;;;;;;;;;;;;;;;;;;
;;Time Procedure;;
;;;;;;;;;;;;;;;;;;

to setup-time
  set minute 0
  set hour 0
  set day 0
  set minutes-per-ticks 1
end

to time-update
  set minute minute + 1 * minutes-per-ticks
  if minute >= 60 [
    set hour hour + 1
    set minute minute - 60
  ]
  if hour >= 24 [
    set day day + 1
    set hour hour - 24
  ]
end


;;;;;;;;
;;Misc;;
;;;;;;;;

to update-location
  ask peoples [
    set current-location [district] of patch-here
    ; Nodes link update
    set location-record lput current-location location-record
    if length location-record > 2 [set location-record remove-item 0 location-record]
  ]
end

to count-by-activity
  set working-agent    peoples with [activity = "bekerja"]
  set moving-agent     peoples with [activity = "berangkat" or activity = "pulang"]
  set home-agent       peoples with [activity = "persiapan" or activity = "istirahat"]
  set agent-on-traffic moving-agent with [speed = 0]
end
@#$#@#$#@
GRAPHICS-WINDOW
90
20
494
425
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-49
49
-49
49
0
0
1
ticks
30.0

BUTTON
10
20
75
53
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
505
20
670
53
num-peoples
num-peoples
0
100
50.0
1
1
NIL
HORIZONTAL

BUTTON
10
55
75
88
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
90
75
123
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
395
430
492
475
meters/patch
meters-per-patch
2
1
11

MONITOR
15
335
80
380
NIL
hour
17
1
11

MONITOR
15
385
80
430
NIL
minute
17
1
11

MONITOR
15
285
80
330
NIL
day
17
1
11

PLOT
865
25
1195
230
Peoples by Activity 
Time (ticks)
Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"working" 1.0 0 -2674135 true "" "plot count working-agent"
"moving" 1.0 0 -13840069 true "" "plot count moving-agent"
"home" 1.0 0 -13791810 true "" "plot count home-agent"

SLIDER
505
105
670
138
work-industry
work-industry
0
100
14.0
1
1
%
HORIZONTAL

SLIDER
505
70
670
103
work-trade
work-trade
0
100
46.0
1
1
%
HORIZONTAL

SLIDER
505
140
670
173
work-service
work-service
0
100
24.0
1
1
%
HORIZONTAL

MONITOR
505
180
580
225
others (%)
100 - work-industry - work-trade - work-service
2
1
11

MONITOR
680
120
755
165
n-industry
count peoples with [occupation = \"industry\"]
17
1
11

MONITOR
760
120
835
165
n-ver-industry
work-industry / 100 * num-peoples
0
1
11

MONITOR
680
70
755
115
n-trade
count peoples with [occupation = \"trade\"]
17
1
11

MONITOR
760
70
835
115
n-ver-trade
num-peoples * work-trade / 100
0
1
11

MONITOR
680
170
755
215
n-service
count peoples with [occupation = \"public service\"]
2
1
11

MONITOR
760
170
835
215
n-ver-service
work-service / 100 * num-peoples
0
1
11

MONITOR
760
220
835
265
n-ver-other
num-peoples - (num-peoples * work-trade / 100) - (work-industry / 100 * num-peoples) - (work-service / 100 * num-peoples)
0
1
11

MONITOR
680
220
755
265
n-others
count peoples with [occupation = \"others\"]
2
1
11

SLIDER
680
285
845
318
acceleration
acceleration
0
0.0990
0.0251
0.0001
1
NIL
HORIZONTAL

SLIDER
505
280
670
313
jam-kerja
jam-kerja
1
8
8.0
1
1
NIL
HORIZONTAL

SLIDER
505
315
670
348
jam-berangkat
jam-berangkat
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
505
350
670
383
jam-pulang
jam-pulang
13
24
16.0
1
1
NIL
HORIZONTAL

SLIDER
680
320
845
353
deceleration
deceleration
0
.099
0.056
.001
1
NIL
HORIZONTAL

SLIDER
680
355
845
388
speed-limit
speed-limit
0
1
0.6
0.05
1
NIL
HORIZONTAL

MONITOR
680
430
797
475
Real speed limit
speed-limit * meters-per-patch
2
1
11

MONITOR
1090
235
1195
280
Agent on Traffic
count agent-on-traffic
2
1
11

MONITOR
865
235
925
280
working
count working-agent
2
1
11

MONITOR
990
235
1050
280
moving
count moving-agent
2
1
11

MONITOR
930
235
987
280
home
count home-agent
2
1
11

PLOT
865
305
1025
475
Travel Time
Travel Time
Count
0.0
10.0
0.0
10.0
true
false
"" "set-plot-y-range 0 1\n  set-plot-x-range 0 (max [ trip-time ] of peoples + 1)"
PENS
"test" 1.0 1 -16777216 true "" "histogram [trip-time] of peoples"

PLOT
1035
305
1195
475
Travel Length
Length (m)
Count
0.0
10.0
0.0
10.0
true
false
"" "set-plot-y-range 0 1\n  set-plot-x-range 0 (max [ trip-length ] of peoples + 1)"
PENS
"default" 1.0 1 -16777216 true "" "histogram [trip-length] of peoples"

SLIDER
680
390
845
423
speed-min
speed-min
0
0.5
0.1
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

Model ini berusaha mempelajari struktur ruang kota harian berdasarkan aktivitas penduduk.
## HOW IT WORKS

Model ini memuat dua macam agen. Agen manusia (peoples) dan node struktur ruang (placenodes)obfuscated. Agen manusia adalah penduduk DKI Jakarta. Agen jaringan-lokasi merupakan node masing-masing kecamatan. Node ini berfungsi merekam jumlah penduduk dan atribut-atributnya pada masing-masing kecamatan. Link masing-masing node berfungsi merekam penduduk yang berpindah antar kecamatan.

Analisis node didasarkan pada submodel indeks sentralitas (Zhong, 2015).

Agen terbagi ke dalam 3 kelompok aktivitas: kerja, istirahat, transportasi. Aktivitas kerja meliputi seluruh kegiatan yang menghasilkan nilai tambah secara ekonomi, sosial, lingkungan. Termasuk didalamnya bekerja dan bersekolah. Aktivitas istirahat meliputi seluruh kegiatan yang memulihkan kembali energi agen. Aktivitas transportasi merupakan yang paling sentral dalam model ini. Meliputi seluruh pergerakan yang dilakukan penduduk sejak keluar dari rumah, pulang dari tempat kerja atau sekadar berjalan-jalan. Aktivitas lain seperti beribadah, meskipun juga menghasilkan nilai tambah secara holistik, tidak dimasukkan ke dalam model ini.

Aktivitas bekerja umumnya dilakukan di kantor. Meskipun tidak menutup kemungkinan ada agen yang beristirahat di kantor (tidak produktif). Kemungkinan ini dimasukkan dalam parameter produktivitas-kerja, yang terbagi ke dalam rentang nilai 0 sampai 1. Nilai 0 menunjukkan ketidakproduktivitas ekstrim (tidak ada yang bekerja pada waktu yang seharusnya bekerja). Nilai 1 menunjukkan Aktivitas kerja selanjutnya dibagi lagi kedalam masing-masing sektor sesuai mata pencaharian. Terdapat 9 mata pencaharian yang ditempatkan sesuai masing-masing guna lahan. Pekerjaan diluar guna lahan disesuaikan dengan data ketersediaan lapangan pekerjaan per masing-masing sektor pada setiap Kotamadya.

Aktivitas beristirahat umumnya dilakukan di rumah. Meskipun tidak menutup kemungkinan ada agen yang beristirahat di kantor (tidak produktif). Kemungkinan ini didasarkan pada jumlah penduduk dengan mata pencaharian yang mungkin dilakukan di rumah. Aktivitas ini juga bisa dilakukan di tempat rekreasi. Agen memilih untuk berekreasi sesuai tingkat kejenuhan, ketersediaan waktu dan biaya. Rekreasi dilakukan secara individu sebagaimana aktivitas bekerja, kemungkinan rekreasi dilakukan dalam grup tidak dimasukkan dalam model ini.

Aktivitas pergerakan dilakukan di jaringan jalan. Tidak terdapat perbedaan moda dalam model ini. Penduduk diasumsikan hanya bergerak menggunakan kendaraan pribadi. Hal ini dikarenakan masih minimnya persentase penggunaan kendaraan bermotor di DKI Jakarta, keterbatasan waktu dan kapasitas komputasi, serta fokus dari model ini yang berada pada persebaran aktivitas, bukan pilihan moda. Aktivitas pergerakan dibagi ke dalam dua kelompok, lancar dan tersendat. Pembagian kedua kelompok ini didasarkan pada nilai parameter batas-kecepatan.

Masalah transportasi bukan cuma masalah moda, tetapi juga persebaran aktivitas.

## HOW TO USE IT

Tombol setup mempersiapkan agen

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>reset</setup>
    <go>go</go>
    <metric>day</metric>
    <metric>hour</metric>
    <metric>minute</metric>
    <metric>item 0 peoples-count-list</metric>
    <metric>item 1 peoples-count-list</metric>
    <metric>item 2 peoples-count-list</metric>
    <metric>item 3 peoples-count-list</metric>
    <metric>item 4 peoples-count-list</metric>
    <metric>item 5 peoples-count-list</metric>
    <metric>item 6 peoples-count-list</metric>
    <metric>item 7 peoples-count-list</metric>
    <metric>item 8 peoples-count-list</metric>
    <metric>item 9 peoples-count-list</metric>
    <metric>item 10 peoples-count-list</metric>
    <metric>item 11 peoples-count-list</metric>
    <metric>item 12 peoples-count-list</metric>
    <metric>item 13 peoples-count-list</metric>
    <metric>item 14 peoples-count-list</metric>
    <metric>item 15 peoples-count-list</metric>
    <metric>item 16 peoples-count-list</metric>
    <metric>item 17 peoples-count-list</metric>
    <metric>item 18 peoples-count-list</metric>
    <metric>item 19 peoples-count-list</metric>
    <metric>item 20 peoples-count-list</metric>
    <metric>item 21 peoples-count-list</metric>
    <metric>item 22 peoples-count-list</metric>
    <metric>item 23 peoples-count-list</metric>
    <metric>item 24 peoples-count-list</metric>
    <metric>item 25 peoples-count-list</metric>
    <metric>item 26 peoples-count-list</metric>
    <metric>item 27 peoples-count-list</metric>
    <metric>item 28 peoples-count-list</metric>
    <metric>item 29 peoples-count-list</metric>
    <metric>item 30 peoples-count-list</metric>
    <metric>item 31 peoples-count-list</metric>
    <metric>item 32 peoples-count-list</metric>
    <metric>item 33 peoples-count-list</metric>
    <metric>item 34 peoples-count-list</metric>
    <metric>item 35 peoples-count-list</metric>
    <metric>item 36 peoples-count-list</metric>
    <metric>item 37 peoples-count-list</metric>
    <metric>item 38 peoples-count-list</metric>
    <metric>item 39 peoples-count-list</metric>
    <metric>item 40 peoples-count-list</metric>
    <metric>item 41 peoples-count-list</metric>
    <enumeratedValueSet variable="work-government">
      <value value="46"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="toggle-network">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-peoples">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minutes-per-ticks">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-trade">
      <value value="34"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.0045"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-industry">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-farm">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.056"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment 6/51/17 23.25" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>day</metric>
    <metric>hour</metric>
    <metric>minute</metric>
    <metric>item 0 peoples-count-list</metric>
    <metric>item 1 peoples-count-list</metric>
    <metric>item 2 peoples-count-list</metric>
    <metric>item 3 peoples-count-list</metric>
    <metric>item 4 peoples-count-list</metric>
    <metric>item 5 peoples-count-list</metric>
    <metric>item 6 peoples-count-list</metric>
    <metric>item 7 peoples-count-list</metric>
    <metric>item 8 peoples-count-list</metric>
    <metric>item 9 peoples-count-list</metric>
    <metric>item 10 peoples-count-list</metric>
    <metric>item 11 peoples-count-list</metric>
    <metric>item 12 peoples-count-list</metric>
    <metric>item 13 peoples-count-list</metric>
    <metric>item 14 peoples-count-list</metric>
    <metric>item 15 peoples-count-list</metric>
    <metric>item 16 peoples-count-list</metric>
    <metric>item 17 peoples-count-list</metric>
    <metric>item 18 peoples-count-list</metric>
    <metric>item 19 peoples-count-list</metric>
    <metric>item 20 peoples-count-list</metric>
    <metric>item 21 peoples-count-list</metric>
    <metric>item 22 peoples-count-list</metric>
    <metric>item 23 peoples-count-list</metric>
    <metric>item 24 peoples-count-list</metric>
    <metric>item 25 peoples-count-list</metric>
    <metric>item 26 peoples-count-list</metric>
    <metric>item 27 peoples-count-list</metric>
    <metric>item 28 peoples-count-list</metric>
    <metric>item 29 peoples-count-list</metric>
    <metric>item 30 peoples-count-list</metric>
    <metric>item 31 peoples-count-list</metric>
    <metric>item 32 peoples-count-list</metric>
    <metric>item 33 peoples-count-list</metric>
    <metric>item 34 peoples-count-list</metric>
    <metric>item 35 peoples-count-list</metric>
    <metric>item 36 peoples-count-list</metric>
    <metric>item 37 peoples-count-list</metric>
    <metric>item 38 peoples-count-list</metric>
    <metric>item 39 peoples-count-list</metric>
    <metric>item 40 peoples-count-list</metric>
    <metric>item 41 peoples-count-list</metric>
    <enumeratedValueSet variable="toggle-network">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-pulang">
      <value value="17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-service">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-peoples">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-trade">
      <value value="46"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.0046"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-industry">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-kerja">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.056"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-berangkat">
      <value value="7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>minute</metric>
    <metric>hour</metric>
    <metric>day</metric>
    <metric>count jakut-cilincing</metric>
    <metric>count jakut-koja</metric>
    <metric>count jakut-kelapagading</metric>
    <metric>count jakut-tanjungpriok</metric>
    <metric>count jakut-pademangan</metric>
    <metric>count jakut-penjaringan</metric>
    <metric>count jaktim-cipayung</metric>
    <metric>count jaktim-ciracas</metric>
    <metric>count jaktim-makasar</metric>
    <metric>count jaktim-pasarrebo</metric>
    <metric>count jaktim-durensawit</metric>
    <metric>count jaktim-kramatjati</metric>
    <metric>count jaktim-cakung</metric>
    <metric>count jaktim-jatinegara</metric>
    <metric>count jaktim-pulogadung</metric>
    <metric>count jaktim-matraman</metric>
    <metric>count jaksel-tebet</metric>
    <metric>count jaksel-pasarminggu</metric>
    <metric>count jaksel-pancoran</metric>
    <metric>count jaksel-mampangprapatan</metric>
    <metric>count jaksel-setiabudi</metric>
    <metric>count jaksel-cilandak</metric>
    <metric>count jaksel-kebayoranbaru</metric>
    <metric>count jaksel-kebayoranlama</metric>
    <metric>count jaksel-pesanggrahan</metric>
    <metric>count jaksel-jagakarsa</metric>
    <metric>count jakpus-menteng</metric>
    <metric>count jakpus-gambir</metric>
    <metric>count jakpus-senen</metric>
    <metric>count jakpus-cempakaputih</metric>
    <metric>count jakpus-kemayoran</metric>
    <metric>count jakpus-tanahabang</metric>
    <metric>count jakpus-joharbaru</metric>
    <metric>count jakpus-sawahbesar</metric>
    <metric>count jakbar-tamansari</metric>
    <metric>count jakbar-tambora</metric>
    <metric>count jakbar-palmerah</metric>
    <metric>count jakbar-grogolpetamburan</metric>
    <metric>count jakbar-kalideres</metric>
    <metric>count jakbar-kembangan</metric>
    <metric>count jakbar-cengkareng</metric>
    <metric>count jakbar-kebonjeruk</metric>
    <metric>count working-agent</metric>
    <metric>count moving-agent</metric>
    <metric>count home-agent</metric>
    <metric>count agent-on-traffic</metric>
    <enumeratedValueSet variable="num-peoples">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-pulang">
      <value value="17"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-trade">
      <value value="46"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-service">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.0251"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="work-industry">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-min">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-kerja">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.056"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="jam-berangkat">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
