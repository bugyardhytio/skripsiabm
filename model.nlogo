extensions [ gis nw ]

globals [ bounds-dataset
          landuse-dataset
          jabodetabek-dataset
          envelope-dataset

          openspace-patches
          tradearea-patches
          industry-patches
          facility-patches
          residential-patches
          workarea-patches

          city-list
          city-patches
          hinterland

          additional-roadnodes

          peoples-count-list

          n-working-agent
          n-moving-agent
          n-home-agent
          minute hour day
          minutes-per-ticks ]

undirected-link-breed [ streets street ]
breed [ peoples people ]
breed [ roadnodes roadnode ]

peoples-own [
  location-record
  current-location

  activity
  occupation
  home-location
  home-city
  work-location

  origin
  destination
  route
  route-counter
  target

  speed
  speed-limit
  speed-min

  working-time
  preparation-time
]

directed-link-breed [ spatiallinks spatiallink ]
breed [ spatialnodes spatialnode ]

patches-own [ city landuse occupied? ]
roadnodes-own [ nodes-route additional? ]
spatialnodes-own [ location peoples-count total-peoples m ]
spatiallinks-own [ current-flow ]



;;;;;;;;;;;;;;;;;;
;;Main Procedure;;
;;;;;;;;;;;;;;;;;;


to setup
  clear-all
  gis-environment-setup
  parameter-setup
  draw-environment
  time-setup

  nw:set-context spatialnodes spatiallinks
  nw:load "../data/setup-networks.gdf" spatialnodes spatiallinks

  nw:set-context roadnodes streets
  nw:load "../data/setup-roads.gdf" roadnodes streets

  roadnodes-hatch-at-work

  peoples-setup
  ask peoples [assign-workplace]

  roadnodes-hatch-at-home

  peoples-route-setup
  peoples-move

  display-network

  reset-ticks
end


to reset
  ask peoples [die]
  ask additional-roadnodes [die]
  clear-output
  clear-patches
  clear-all-plots
  reset-ticks

  draw-environment
  time-setup

  roadnodes-hatch-at-work

  peoples-setup
  ask peoples [assign-workplace]

  roadnodes-hatch-at-home
  set additional-roadnodes roadnodes with [additional? = 1]

  peoples-route-setup
  peoples-move

  display-network
end


to go
  time-update

  peoples-move
  peoples-location-update

  display-network
  network-update
  link-update

  if day > 0 [ stop ]

  tick
end



;;;;;;;;;;;;;;;;;;;;;;;;;
;;Environment Procedure;;
;;;;;;;;;;;;;;;;;;;;;;;;;


to gis-environment-setup
  ;; Membaca shapefile
  set bounds-dataset                    gis:load-dataset "../shapefile/bounds.shp"
  set landuse-dataset                   gis:load-dataset "../shapefile/tata_guna_lahan_dissolve.shp"
  set jabodetabek-dataset               gis:load-dataset "../shapefile/jabodetabek.shp"
  set envelope-dataset                  gis:load-dataset "../shapefile/box.shp"

  ;; Mengatur batasan tampilan kota
  gis:set-world-envelope (gis:envelope-of envelope-dataset)

  ;; Menerapkan atribut “guna-lahan” dan “kota” ke masing-masing patch
  gis:apply-coverage jabodetabek-dataset "KOTAADM" city
  gis:apply-coverage landuse-dataset "GUNA_LAHAN" landuse
end


to parameter-setup
  ;; Mengatur variabel global
  set peoples-count-list n-values length gis:feature-list-of bounds-dataset [0]

  set city-list []
  set city-patches []
  foreach gis:feature-list-of jabodetabek-dataset [ [i] ->
    set city-list lput (list (gis:property-value i "ID" - 1) (gis:property-value i "KOTAADM") ) city-list
  ]
  foreach city-list [ [l] ->
    let p patches with [city = item 1 l]
    set city-patches lput p city-patches
  ]

  set openspace-patches   patches with [landuse = "Tanah Kosong" or landuse = "Ruang Terbuka/Taman/Pemakaman" or landuse = "Situ/Waduk/Rawa/Tambak" or landuse = "Hutan Bakau/Hutan Suaka Alam" or landuse = "Pertanian/Peternakan"]
  set tradearea-patches   patches with [landuse = "Perkantoran/Perdagangan/Jasa"]
  set industry-patches    patches with [landuse = "Industri/Pergudangan"]
  set facility-patches    patches with [landuse = "Fasilitas Sosial" or landuse = "Prasarana Transportasi (Pelabuhan/Bandara)" or landuse = "Kawasan Pemerintahan"]
  set residential-patches patches with [landuse = "Permukiman Tidak Teratur" or landuse = "Permukiman Teratur"]
  set workarea-patches    (patch-set tradearea-patches industry-patches facility-patches)

  set hinterland patches with [city = "Bekasi" or city = "Depok" or city = "Tangerang" or city = "Bogor"]

  set additional-roadnodes roadnodes with [additional? = 1]
end

to draw-environment
  ;; Mengatur tampilan warna patch berdasarkan atribut guna lahan
  ask patches [set pcolor white]
  ask openspace-patches   [ set pcolor lime + 1    set landuse "Ruang Terbuka" ]
  ask facility-patches    [ set pcolor pink + 2    set landuse "Fasilitas Umum" ]
  ask industry-patches    [ set pcolor magenta + 1 set landuse "Industri" ]
  ask tradearea-patches   [ set pcolor red + 1     set landuse "Perdagangan dan Jasa"]
  ask residential-patches [ set pcolor yellow + 1  set landuse "Permukiman" ]

  ;; Memberikan nama kota/kab pada setiap patch
  foreach city-list [ [l] ->
    ask item item 0 l city-patches [ set city item 1 l ]
  ]

  ;; Menggambar batas administrasi
  gis:set-drawing-color black        gis:draw jabodetabek-dataset 1
end


to-report meters-per-patch
  let world gis:world-envelope ;
  let x-meters-per-patch (item 1 world - item 0 world) / (max-pxcor - min-pxcor)
  let y-meters-per-patch (item 3 world - item 2 world) / (max-pycor - min-pycor)
  report mean list x-meters-per-patch y-meters-per-patch
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Urban Structure Network Procedure;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to network-update
  ;; Secara berkala mengatur jumlah orang, ukuran dan warna dari masing-masing nodes
  ask spatialnodes [
    foreach gis:feature-list-of bounds-dataset [ [updatenodes] ->
      if gis:contained-by? self updatenodes [
        ask self [
          set m []
          set m lput peoples with [current-location = gis:property-value updatenodes "KECAMATAN"] m
          set m remove-duplicates m
          set peoples-count count peoples with [current-location = gis:property-value updatenodes "KECAMATAN"]
          set total-peoples length m

          let density peoples-count / num-peoples
          ifelse peoples-count = 0
            [set size 0.5 set color black]
            [set size 15 * sqrt density set color blue]
        ]
      ]
    ]
  ]
end


to link-update
  ask spatiallinks [
    let link-origin [location] of end1
    let link-destination [location] of end2
    set current-flow count peoples with [first location-record = [link-origin] of myself and last location-record = [link-destination] of myself]
    ifelse current-flow = 0 [hide-link][show-link]
  ]
end

to display-network
  ifelse toggle-network
    [ask spatialnodes [show-turtle] ask spatiallinks [show-link]]
    [ask spatialnodes [hide-turtle] ask spatiallinks [hide-link]]
end

;;;;;;;;;;;;;;;;;;;
;;Roads Procedure;;
;;;;;;;;;;;;;;;;;;;


to roadnodes-hatch-at-work
  ask workarea-patches [
    sprout-roadnodes 1 [ hatch-roadnodes-setup ]
  ]
  ;ask n-of 25 hinterland [
  ;  set pcolor magenta + 1
  ;  sprout-roadnodes 1 [ hatch-roadnodes-setup ]
  ;]
end

to roadnodes-hatch-at-home
  ask peoples [
    hatch-roadnodes 1 [ hatch-roadnodes-setup ]
    if (home-city = "Bekasi" or home-city = "Depok" or home-city = "Tangerang" or home-city = "Bogor") [
      ask patch-here [set pcolor yellow + 1]
    ]
  ]
end

to hatch-roadnodes-setup
  create-street-with min-one-of other roadnodes [distance myself]
  set additional? 1
  set color grey + 5
  set size 0.1
end


;;;;;;;;;;;;;;;;;;;;;
;;Peoples Procedure;;
;;;;;;;;;;;;;;;;;;;;;


to peoples-setup
  create-peoples num-peoples

  ask peoples [
    set color 92
    set size 1

    set home-location one-of residential-patches with [occupied? = 0]
    ask home-location [set occupied? 1]
    setxy [pxcor] of home-location [pycor] of home-location

    set activity "persiapan"
    set working-time jam-kerja * 60
    set preparation-time jam-berangkat * 60

    set speed 0.1 + random-float 0.9
    set speed-limit 1
    set speed-min 0

    set location-record []
  ]

  peoples-location-update
end

to assign-workplace
  let n-trade-worker    round (num-peoples * work-trade / 100)
  let n-industry-worker round (num-peoples * work-industry / 100)
  let n-service-worker  round (num-peoples * work-service / 100)
  let n-other-worker    (num-peoples - n-trade-worker - n-industry-worker - n-service-worker)

  let trade "trade"
  let industry "industry"
  let service "public service"
  let others "others"

  let list-worker       (list n-trade-worker n-industry-worker n-service-worker n-other-worker)
  let list-work-patches (list tradearea-patches industry-patches facility-patches workarea-patches)
  let list-occupation   (list "trade" "industry" "public service" "others")

  (foreach list-worker list-work-patches list-occupation [ [a b c] ->
     ask n-of a peoples [
      set work-location one-of b with [count roadnodes-on self = 1]
      set occupation c
    ]
  ])
end

to-report at-most-n-of [ n agentset ]
  ifelse count agentset > n [
    report n-of n agentset
  ] [
    report agentset
  ]
end

to peoples-route-setup
  ask peoples [
    set origin one-of roadnodes-on home-location
    set destination one-of roadnodes-on work-location
    ask origin [
      set nodes-route nw:turtles-on-path-to [destination] of myself
    ]
    ask roadnodes with [nodes-route != 0] [
      ask peoples-on self [
        set route-counter 0
        set route [nodes-route] of myself
        set target item (route-counter + 1) route
      ]
    ]
  ]
end

to peoples-location-update
  ; Nodes size update
  ask peoples [
    foreach gis:feature-list-of bounds-dataset [ [i] ->
    set peoples-count-list replace-item (gis:property-value i "DID" - 1) peoples-count-list (count peoples with [current-location = gis:property-value i "KECAMATAN"])
    if gis:contained-by? self i [
      ask self [
          set current-location gis:property-value i "KECAMATAN"
          ]
       ]
    ]
    if member? patch-here hinterland [
      ask self [
        set current-location 0
        right 180
      ]
    ]
    ; Nodes link update
    set location-record lput current-location location-record
    if length location-record > 2 [set location-record remove-item 0 location-record]
  ]

  ; Change global variable
  count-by-activity
end


; General move procedure
to peoples-move
  ask peoples [
    face target
    ifelse not (preparation-time <= 0) or not (hour >= jam-berangkat)
      [ ;set label preparation-time
        set preparation-time preparation-time - minutes-per-ticks ]
      [ ifelse activity = "persiapan"
        [ set route-counter 1
          set activity "berangkat" ]
        [ ifelse patch-here != work-location and activity = "berangkat"
          [ set color red
            if distance target = 0
            [ set route-counter route-counter + 1
              set target item route-counter route
              face target ] ]
          [ ifelse not (working-time <= 0) or not (hour >= jam-pulang)
            [ set color blue
              set activity "bekerja"
              set working-time working-time - minutes-per-ticks ]
            [ set activity "pulang"
              face target
              ifelse patch-here != home-location and activity = "pulang"
                [ set color red
                  if distance target = 0
                    [ set route-counter route-counter - 1
                      set target item route-counter route
                      face target ] ]
                [ set color 92
                  set activity "istirahat" ]
            ]
          ]
        ]
        ifelse distance target < 1
          [ move-to target ]
          [ car-following ]
      ]
  ]
end

to count-by-activity
  set n-working-agent count peoples with [activity = "bekerja"]
  set n-moving-agent  count peoples with [activity = "berangkat" or activity = "pulang"]
  set n-home-agent    count peoples with [activity = "persiapan" or activity = "istirahat"]
end


; Car Following Algorithm (Based on Traffic Basic Model)
to car-following
  let car-ahead nobody
  ifelse any? peoples-on patch-ahead 5
    [ set car-ahead one-of peoples-on patch-ahead 5 ]
    [ set car-ahead nobody ]
  ifelse car-ahead != nobody
    [ slow-down-car car-ahead ]
    [ speed-up-car ] ;; otherwise, speed up
  ;; don't slow down below speed minimum or speed up beyond speed limit
  if speed < speed-min [ set speed speed-min ]
  if speed > speed-limit [ set speed speed-limit ]
  fd speed
end
to slow-down-car [ car-ahead ] ;; turtle procedure
  ;; slow down so you are driving more slowly than the car ahead of you
  set speed [ speed ] of car-ahead - deceleration
end
to speed-up-car ;; turtle procedure
  set speed speed + acceleration
end


;;;;;;;;;;;;;;;;;;
;;Time Procedure;;
;;;;;;;;;;;;;;;;;;


to time-setup
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
