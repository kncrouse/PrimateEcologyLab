extensions [sound]
globals []

breed [primates primate]
breed [groups group]

groups-own []

; TO DO: dispersal

primates-own [
  sex
  body-size
  age
  energy
  cycle-tick
  my-group
  mother
  father
  chromosomeI
  chromosomeII
  generation
]

patches-own [
  penergy
  fertile?
  terminal-growth
]

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: SETUP ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to setup
  clear-all
  setup-patches
  setup-groups
  reset-ticks
end

to setup-patches
  ask patches [ set fertile? false set penergy 0 ] ; initialize
  ask n-of (patch-abundance * count patches) patches [ set fertile? true ] ; abundance
  ask n-of (patch-patchiness * count patches) patches [ ifelse count neighbors with [fertile?] > 3 [ set fertile? true ] [ set fertile? false ] ] ; patchiness
  ask patches with [fertile?] [ set terminal-growth 1 + random patch-max-energy - 1  set penergy terminal-growth] ; energy
  ask patches [ set-patch-color ] ; color
end

to setup-groups
  repeat group-count [ add-group ]
end

to add-group
  create-groups 1 [
    set color random 13 * 10 + 5
    set hidden? true
    move-to one-of patches
    hatch-primates group-size [
      initialize-primate nobody nobody myself patch-here
      set size ifelse-value (sex = "female") [1.5] [2.0]
      set body-size ifelse-value (sex = "female") [1.5] [2.0]
      set hidden? false
      set energy random 1000
      set age get-age-at-adulthood
      if sex = "female" [ set label "o" ]
      set color scale-color [color] of my-group age get-longevity 0 ]
  ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: INITIALIZE PRIMATE FUNCTIONS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to initialize-primate [m f g startPatch]
  ifelse (m != nobody and f != nobody)
    [ set-chromosomes m f
      set generation [generation] of m + 1 ]
    [ initialize-chromosomes
      set generation 0 ]
  set sex ifelse-value (random-float 1.0 < sex-ratio) ["male"] ["female"]
  set shape ifelse-value (sex = "female") ["circle"] ["triangle"]
  set hidden? true
  set label-color white
  set age 0
  set body-size 0 set size 0
  set my-group g
  set xcor [pxcor] of startPatch + random 5 - random 5
  set ycor [pycor] of startPatch + random 5 - random 5
  set energy 100
  set color scale-color [color] of my-group age get-longevity 0
  ;print (word "baby " self)
end

to initialize-chromosomes
  set chromosomeI [ ]
  set chromosomeII [ ]
  repeat 270 [ set chromosomeI lput (random-float 1.0 - random-float 1.0) chromosomeI ]
  repeat 270 [ set chromosomeII lput (random-float 1.0 - random-float 1.0) chromosomeII ]

  ; stop adults from growing:
  set chromosomeI replace-item 12 chromosomeI 0
  set chromosomeI replace-item 13 chromosomeI 0
  set chromosomeII replace-item 12 chromosomeII 0
  set chromosomeII replace-item 13 chromosomeII 0
end

to set-chromosomes [m f]
  let i 0;
  while [i < 270] [ ifelse random 100 < 50
  [ set chromosomeI replace-item i chromosomeI item i [chromosomeI] of m ]
  [ set chromosomeI replace-item i chromosomeI item i [chromosomeI] of f ]
  set i i + 1 ]
  while [i < 270] [ ifelse random 100 < 50
  [ set chromosomeII replace-item i chromosomeII item i [chromosomeII] of m ]
  [ set chromosomeII replace-item i chromosomeII item i [chromosomeII] of f ]
  set i i + 1 ]
  mutate-genes
  set mother m
  set father f
end

to mutate-genes
  repeat 270 [
    if random-float 1.0 < mutation-rate [
      let index random 270
      ifelse random-float 1.0 < 0.5
      [ set chromosomeI replace-item index chromosomeI (random-float 1.0 - random-float 1.0) ]
      [ set chromosomeII replace-item index chromosomeII (random-float 1.0 - random-float 1.0) ]
    ]
  ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go
  if count primates = 0 [ stop ]
  clear-links
  ask groups [ ifelse count primates with [my-group = myself] = 0 [ die ] [ groups-wander ] ]
  ask patches [ grow-patches set-patch-color ]
  ask primates [ eat ]
  ask primates [ move ]
  ask primates [ compete ]
  ask primates [ mate ]
  ask primates [ grow ]
  ask primates [ basal-metabolism ]
  ask primates [ update-life-history ]
  tick
end

to groups-wander
  set xcor mean [xcor] of primates with [ my-group = myself ]
  set ycor mean [ycor] of primates with [ my-group = myself ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: PRIMATE FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

; GROW IN SIZE
to grow
  let growth get-growth
  set body-size body-size + growth
  update-energy ( - cost-per-growth-unit * growth )
  set size body-size
end

; MAINTAIN BODY SIZE
to basal-metabolism
  let bmr-cost ( body-size ^ 0.762 ) * cost-per-bmr
  update-energy ( - bmr-cost )
end

; CHOOSE WHERE TO MOVE
to move
  ; FETUS & INFANT
  if get-life-history = "fetus" or get-life-history = "infant" and mother != nobody  [
    move-to mother rt random 360 fd random-float 1.0 ]

  ; JUVENILE, ADULT, elderly, PREGNANT, LACTATING, OVULATING, CYCLING
  if get-life-history != "fetus" and get-life-history != "infant" [

    let ME self
    let X-magnitude 0.1
    let Y-magnitude 0.1

    ; HOME RANGE
    let home-angle atan ([ycor] of my-group - ycor - 0.0001) ([xcor] of my-group - xcor + 0.0001)
    let home-magnitude get-home-weight * ( distance my-group ^ 2 )
    set X-magnitude X-magnitude + (home-magnitude * sin home-angle)
    set Y-magnitude Y-magnitude + (home-magnitude * cos home-angle)

    ; FOOD - hunger?
    foreach [self] of other patches with [distance myself <= perception-range  and distance myself > 0.1] [
      let food-angle atan ([pycor] of ? - [ycor] of ME) ([pxcor] of ? - [xcor] of ME)
      let food-magnitude ( get-food-weight * [penergy] of ? ) / (distance ? ^ 2)
      set X-magnitude X-magnitude + food-magnitude * sin food-angle
      set Y-magnitude Y-magnitude + food-magnitude * cos food-angle
    ]

    ;CONSPECIFIC: in-female, in-male, out-female, out-male
    foreach [self] of primates with [distance myself <= perception-range  and distance myself > 0.1] [
      let conspecific-angle atan ([ycor] of ? - ycor) ([xcor] of ? - xcor)
      let tolerance-magnitude get-tolerance-magnitude ?
      let conspecific-magnitude 0
      ifelse tolerance-magnitude > 0
      [ ifelse sex = [sex] of ?
        ; FRIEND: tolerance * friend-weight
        [ set conspecific-magnitude tolerance-magnitude * get-friend-weight ]
      ; MATE: tolerance * mate-weight
        [ set conspecific-magnitude tolerance-magnitude * get-mate-weight ]]
      ; ENEMY: intolerance * likelihood of winning fight * enemy-weight
      [ set conspecific-magnitude ( 1 - tolerance-magnitude ) * get-winning-likelihood ? * get-enemy-weight ]
      set X-magnitude X-magnitude + ((conspecific-magnitude / (distance ? ^ 2)) * sin conspecific-angle)
      set Y-magnitude Y-magnitude + ((conspecific-magnitude / (distance ? ^ 2)) * cos conspecific-angle)
    ]

    move-to-patch X-magnitude Y-magnitude
  ]
end

; MOVE IN DIRECTION
to move-to-patch [x y]
  set heading atan y x
  forward 1
  update-energy ( - cost-per-unit-step )
end

; ENERGY INTAKE
to eat

  ; FETUS
  if get-life-history = "fetus" and mother != nobody [
    let nutrients [get-placental-energy] of mother ; P/O Conflict?
    update-energy nutrients
    ask mother [ update-energy ( - nutrients ) ]
  ]

  ; INFANT
  if get-life-history = "infant" and mother != nobody [
    let nutrients [get-lactation-energy] of mother ; P/O Conflict?
    update-energy nutrients
    ask mother [ update-energy ( - nutrients ) ]
  ]

  ; JUVENILE, ADULT, elderly, PREGNANT, LACTATING, OVULATING, CYCLING
  if get-life-history != "fetus" and get-life-history != "infant" [
    let food-eaten 0
    ifelse penergy > food-eaten-per-step
    [ set food-eaten food-eaten-per-step ]
    [ set food-eaten penergy ]
    set energy energy + food-eaten
    set penergy penergy - food-eaten
  ]
end

; COMPETE WITH ENEMY here that is easiest to beat in fight
to compete
  let enemy min-one-of other primates-here with [ [get-tolerance-magnitude self] of myself < 0 ] [ get-winning-likelihood myself ]
  if enemy != nobody [
    ifelse random-float 1.0 < get-winning-likelihood enemy
    [ ask enemy [ update-energy ( - cost-per-attack ) ] ]
    [ update-energy ( - cost-per-attack ) ]]
end

; MATE WITH FRIEND here of opposite sex
to mate
  let ME self
  ifelse count my-in-links > 0 ; suitor available
  [ let suitor [other-end] of max-one-of my-in-links [ [get-tolerance-magnitude self] of myself ]
    ifelse sex = "female" [ copulate suitor ] [ ask suitor [ copulate ME ]]]
  [ let potential-mate max-one-of other primates-here with [ sex != [sex] of myself ] [ [get-tolerance-magnitude self] of myself ]
    if potential-mate != nobody [ create-link-to potential-mate ]]
end

; Female COPULATE with Male partner
to copulate [partner]
  if ([get-life-history] of partner = "adult" or [get-life-history] of partner = "elderly") and get-life-history = "ovulating" [
    if random-float 1.0 < conception-rate [
      hatch-primates 1 [ initialize-primate myself partner [my-group] of myself patch-here ]
      update-fertility "p" ]]
end

to update-life-history
  set age age + 1
  set cycle-tick cycle-tick + 1
  if age = get-age-at-birth [ set hidden? false if mother != nobody [ask mother [  update-fertility "l" ]]]
  if age = get-age-at-weaning [ if mother != nobody [ask mother [  update-fertility "c" ]]]
  if age >= get-age-at-senescence [ update-fertility "" ]
  if get-life-history = "cycling" and cycle-tick = get-cycle-length [ update-fertility "o" ]
  if get-life-history = "ovulating" and cycle-tick = get-ovulation-length [  update-fertility "c" ]
  if age > get-longevity [ make-dead ]
  set color scale-color [color] of my-group age get-longevity 0
end

to check-death
  if energy <= 0 or my-group = 0 [ make-dead ]
end

to make-dead
  if get-life-history = "fetus" and mother != nobody  [ ask mother [ update-fertility "c" ]]
  if get-life-history = "infant" and mother != nobody  [ ask mother [ update-fertility "c" ]]
  if get-life-history = "pregnant" [
    if one-of primates with [ mother = myself and get-life-history = "fetus"] != nobody [
    ask one-of primates with [ mother = myself and get-life-history = "fetus" ][ make-dead ]]]
  die
end

to update-energy [update]
  set energy energy + update
  check-death
end

to update-fertility [update]
  set label update
  set cycle-tick 0
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;::::: PRIMATE CALCULATATIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to-report get-chromosome [index]
  report (( item index chromosomeI + item index chromosomeII ) / 2 )
end

to-report get-age-at-birth report (ceiling ( abs get-chromosome 0  * max-longevity) + 1) end
to-report get-age-at-weaning report ( ceiling (( abs get-chromosome 0 + abs get-chromosome 1) * max-longevity) + 1) end
to-report get-age-at-adulthood report ( ceiling (( abs get-chromosome 0 + abs get-chromosome 1 + abs get-chromosome 2) * max-longevity)  + 1) end
to-report get-age-at-senescence report ( ceiling (( abs get-chromosome 0 +  abs get-chromosome 1 +  abs get-chromosome 2 +  abs get-chromosome 3) * max-longevity) + 1) end
to-report get-longevity report ceiling (( abs get-chromosome 0 +  abs get-chromosome 1 +  abs get-chromosome 2 +  abs get-chromosome 3 +  abs get-chromosome 4) * max-longevity) end

to-report get-cycle-length report ceiling ( abs get-chromosome 5 * max-longevity ) end
to-report get-ovulation-length report ceiling ( abs get-chromosome 6 * max-longevity ) end
to-report get-estrus-cycle-length report (get-cycle-length + get-ovulation-length) end
to-report get-pregnancy-length report ceiling ( abs get-chromosome 7 * max-longevity ) end
to-report get-lacation-length report ceiling ( abs get-chromosome 8 * max-longevity ) end

to-report get-placental-energy report ( abs get-chromosome 16 * food-eaten-per-step) end
to-report get-lactation-energy report ( abs get-chromosome 17 * food-eaten-per-step) end

to-report get-growth report abs (get-chromosome (9 + get-age-index)) end
to-report get-dispersion report get-chromosome (18 + get-status-index) end

to-report get-home-weight report get-chromosome (27 + get-status-index) end
to-report get-food-weight report get-chromosome (36 + get-status-index) end
to-report get-friend-weight report get-chromosome (45 + get-status-index) end
to-report get-mate-weight report get-chromosome (54 + get-status-index) end
to-report get-enemy-weight report get-chromosome (63 + get-status-index) end

to-report get-IFI-tolerance report get-chromosome (72 + get-status-index) end
to-report get-IFJ-tolerance report get-chromosome (81 + get-status-index) end
to-report get-IFP-tolerance report get-chromosome (90 + get-status-index) end
to-report get-IFO-tolerance report get-chromosome (99 + get-status-index) end
to-report get-IFC-tolerance report get-chromosome (108 + get-status-index) end
to-report get-IFL-tolerance report get-chromosome (117 + get-status-index) end
to-report get-IFE-tolerance report get-chromosome (126 + get-status-index) end

to-report get-IMI-tolerance report get-chromosome (135 + get-status-index) end
to-report get-IMJ-tolerance report get-chromosome (144 + get-status-index) end
to-report get-IMA-tolerance report get-chromosome (153 + get-status-index) end
to-report get-IME-tolerance report get-chromosome (162 + get-status-index) end

to-report get-OFI-tolerance report get-chromosome (171 + get-status-index) end
to-report get-OFJ-tolerance report get-chromosome (180 + get-status-index) end
to-report get-OFP-tolerance report get-chromosome (189 + get-status-index) end
to-report get-OFO-tolerance report get-chromosome (198 + get-status-index) end
to-report get-OFC-tolerance report get-chromosome (207 + get-status-index) end
to-report get-OFL-tolerance report get-chromosome (216 + get-status-index) end
to-report get-OFE-tolerance report get-chromosome (225 + get-status-index) end

to-report get-OMI-tolerance report get-chromosome (234 + get-status-index) end
to-report get-OMJ-tolerance report get-chromosome (243 + get-status-index) end
to-report get-OMA-tolerance report get-chromosome (252 + get-status-index) end
to-report get-OME-tolerance report get-chromosome (261 + get-status-index) end

to-report get-status-index
  let index get-age-index
  if sex = "female" and index = 4 [ set index get-fertility-index ]
  report index
end

to-report get-winning-likelihood [enemy]
  report ( size / ( size + [size] of enemy))
end

to-report get-tolerance-magnitude [alter]
  let reporter 0
  ifelse [my-group] of alter = my-group
  [ ifelse [sex] of alter = "female" [

    ; INGROUP FEMALE
    ask alter [ if get-life-history = "infant" [ set reporter get-IFI-tolerance ]]
    ask alter [ if get-life-history = "juvenile" [ set reporter get-IFJ-tolerance ]]
    ask alter [ if get-life-history = "pregnant" [ set reporter get-IFP-tolerance ]]
    ask alter [ if get-life-history = "ovulating" [ set reporter get-IFO-tolerance ]]
    ask alter [ if get-life-history = "cycling" [ set reporter get-IFC-tolerance ]]
    ask alter [ if get-life-history = "lactating" [ set reporter get-IFL-tolerance ]]
    ask alter [ if get-life-history = "elderly" [ set reporter get-IFE-tolerance ]]]

  [ ; INGROUP MALE
    ask alter [ if get-life-history = "infant" [ set reporter get-IMI-tolerance ]]
    ask alter [ if get-life-history = "juvenile" [ set reporter get-IMJ-tolerance ]]
    ask alter [ if get-life-history = "adult" [ set reporter get-IMA-tolerance ]]
    ask alter [ if get-life-history = "elderly" [ set reporter get-IME-tolerance ]]]]

  [ ifelse [sex] of alter = "female" [

    ; OUTGROUP FEMALE
    ask alter [ if get-life-history = "infant" [ set reporter get-OFI-tolerance ]]
    ask alter [ if get-life-history = "juvenile" [ set reporter get-OFJ-tolerance ]]
    ask alter [ if get-life-history = "pregnant" [ set reporter get-OFP-tolerance ]]
    ask alter [ if get-life-history = "ovulating" [ set reporter get-OFO-tolerance ]]
    ask alter [ if get-life-history = "cycling" [ set reporter get-OFC-tolerance ]]
    ask alter [ if get-life-history = "lactating" [ set reporter get-OFL-tolerance ]]
    ask alter [ if get-life-history = "elderly" [ set reporter get-OFE-tolerance ]]]

  [ ; OUTGROUP MALE
    ask alter [ if get-life-history = "infant" [ set reporter get-OMI-tolerance ]]
    ask alter [ if get-life-history = "juvenile" [ set reporter get-OMJ-tolerance ]]
    ask alter [ if get-life-history = "adult" [ set reporter get-OMA-tolerance ]]
    ask alter [ if get-life-history = "elderly" [ set reporter get-OME-tolerance ]]]]

  report reporter
end

; REPORT LIFE HISTORY STATUS
; MALE: fetus, infant, juvenile, adult, elderly
; FEMALE: fetus, infant, juvenile, cycling, ovulating, pregnant, lactating, elderly
to-report get-life-history
  let age-index get-age-index
  let life-history ""
  if age-index = 0 [ set life-history "fetus" ]
  if age-index = 1 [ set life-history "infant" ]
  if age-index = 2 [ set life-history "juvenile" ]
  if age-index = 3 [ set life-history "adult" ]
  if age-index >= 4 [ set life-history "elderly" ]
  if sex = "female" and life-history = "adult" [
     let fertility-index get-fertility-index
     if fertility-index = 5 [ set life-history "cycling" ]
     if fertility-index = 6 [ set life-history "ovulating" ]
     if fertility-index = 7 [ set life-history "pregnant" ]
     if fertility-index = 8 [ set life-history "lactating" ]
  ]
  report life-history
end

to-report get-age-index
  let index 0
  if age >= get-age-at-birth [ set index 1 ]
  if age >= get-age-at-weaning [ set index 2 ]
  if age >= get-age-at-adulthood [ set index 3 ]
  if age >= get-age-at-senescence [ set index 4 ]
  report index
end

; FERTILITY INDEX
; 5 = CYCLING 6 = OVULATING 7 = PREGNANT 8 = LACTATING
to-report get-fertility-index
  let index 0
  if label = "c" [ set index 5 ]
  if label = "o" [ set index 6 ]
  if label = "p" [ set index 7 ]
  if label = "l" [ set index 8 ]
  report index
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: PATCH FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to grow-patches
  ifelse fertile? [ if penergy + patch-growth-rate < terminal-growth [ set penergy penergy + patch-growth-rate ]] [ set penergy 0 ]
end

to set-patch-color
  set pcolor scale-color green penergy (patch-max-energy + 20) -10;
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GRAPHING FUNCTIONS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to update-group-food-graph
  ;  set-current-plot "Group v Food";
  ;  foreach [self] of groups [
  ;    let foodValue sum [food-eaten] of primates with [my-group = ?] / count primates with [my-group = ?]
  ;    plotxy [size] of ? foodValue
  ;    plot-pen-down
  ;    plot-pen-up
  ;  ]
end

to update-group-predation-graph
  ;  set-current-plot "Group v Predation";
  ;  foreach [self] of groups [
  ;    if [predation-count] of ? > 0 [
  ;      plotxy [size] of ? [predation-count] of ?
  ;      plot-pen-down
  ;      plot-pen-up
  ;    ]
  ;  ]
end

to update-competition-food-graph
  ;  set-current-plot "Female Food Competition";
  ;  foreach [self] of females [
  ;    plotxy [fighting-ability] of ? [food-eaten] of ?
  ;    plot-pen-down
  ;    plot-pen-up
  ;  ]
end

to update-competition-mates-graph
  ;  set-current-plot "Male Mate Competition";
  ;  foreach [self] of males [
  ;    plotxy [fighting-ability] of ? [mate-number] of ?
  ;    plot-pen-down
  ;    plot-pen-up
  ;  ]
end

















































;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::



;to-report degree-relatedness [ego kin]
;  let kinPoints 0;
;  let i 0;
;  ifelse [genes] of ego = 0 or [genes] of kin = 0 [ report 0 ] [
;    while [i < 16] [
;      if item i [genes] of ego = item i [genes] of kin [ set kinPoints kinPoints + 1 ]
;      set i i + 1 ]
;    report kinPoints / 16 ]
;end
;

;to-report within-group-relatedness
;  let relatedness 0;
;
;  foreach [self] of primates with [breed = males or breed = females] [
;     let meprimate ?;
;     foreach [self] of other primates with [(breed = males or breed = females) and my-group = [my-group] of meprimate] [
;       set relatedness relatedness + degree-relatedness meprimate ?;
;     ]
;  ]
;
;  report relatedness / ( count primates with [breed = males or breed = females] ^ 2);
;end
;
;to-report between-group-relatedness
;  let relatedness 0;
;
;  foreach [self] of primates with [breed = males or breed = females] [
;     let meprimate ?;
;     foreach [self] of other primates with [(breed = males or breed = females) and my-group != [my-group] of meprimate] [
;       set relatedness relatedness + degree-relatedness meprimate ?;
;     ]
;  ]
;
;  report relatedness / ( count primates with [breed = males or breed = females] ^ 2);
;end
;
;
;; go
;  ;ask males [ count-mates ]
;  ;check-add-predator
;  ;ask predators [ move-predators ]
;
;  ;update-life-history
;
;
;to count-mates
;  ask males [ set mate-number 0 set mate-number count females-on neighbors + count females-here ]
;end
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; PREDATOR FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;to check-add-predator
;  if random 100 < predation-rate * 100 [
;    create-predators 1 [
;      set size 3;
;      set shape "face sad";
;      set color red;
;      set xcor random 50 - random 50;
;      set ycor random 50 - random 50;
;      set predator-age 0;
;    ]
;  ]
;end
;
;to move-predators
;  set predator-age predator-age + 1
;  rt random-float 20
;  lt random-float 20
;  fd 1
;  ask males-here [ set energy energy - predation-cost ask my-group [ set predation-count predation-count + 1] ]
;  ask females-here [ set energy energy - predation-cost ask my-group [ set predation-count predation-count + 1] ]
;  if predator-age > predation-duration [ die ]
;end
;



to check-transfer
  ;  if (breed = males and male-transfer?) or (breed = females and female-transfer?) [
  ;    set my-group [my-group] of one-of primates with [my-group != [my-group] of myself]
  ;    set home-base [home-base] of one-of primates with [my-group = [my-group] of myself]
  ;  ]
end
;
;
@#$#@#$#@
GRAPHICS-WINDOW
351
53
878
601
30
30
8.48
1
14
1
1
1
0
1
1
1
-30
30
-30
30
0
0
1
ticks
30.0

SLIDER
7
63
163
96
sex-ratio
sex-ratio
0
1
0.5
.01
1
M/F
HORIZONTAL

BUTTON
494
10
563
43
setup
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

BUTTON
576
10
643
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
7
380
210
566
Population Change
Time
Population
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"males" 1.0 0 -13791810 true "" "plot count primates with [sex = \"male\"]"
"females" 1.0 0 -5825686 true "" "plot count primates with [sex = \"female\"]"

MONITOR
219
427
334
472
# Groups
count groups
3
1
11

MONITOR
219
474
335
519
# Primates
count primates
3
1
11

TEXTBOX
177
10
317
29
Primate Settings
13
0.0
0

TEXTBOX
9
136
161
154
Patch Settings
13
0.0
0

SLIDER
7
225
164
258
patch-growth-rate
patch-growth-rate
0
10
10
.01
1
NIL
HORIZONTAL

SLIDER
7
155
163
188
patch-abundance
patch-abundance
0
1
1
.01
1
NIL
HORIZONTAL

SLIDER
7
190
163
223
patch-patchiness
patch-patchiness
0
1
1
0.01
1
NIL
HORIZONTAL

SLIDER
7
260
165
293
patch-max-energy
patch-max-energy
0
100
100
1
1
NIL
HORIZONTAL

SLIDER
7
28
163
61
group-count
group-count
1
50
30
1
1
NIL
HORIZONTAL

TEXTBOX
11
10
161
28
Initial Settings
13
0.0
1

SLIDER
175
192
335
225
food-eaten-per-step
food-eaten-per-step
0
50
50
1
1
NIL
HORIZONTAL

SLIDER
175
262
336
295
cost-per-unit-step
cost-per-unit-step
0
100
1
1
1
NIL
HORIZONTAL

SLIDER
175
332
335
365
cost-per-attack
cost-per-attack
0
100
49
1
1
NIL
HORIZONTAL

PLOT
885
10
1242
309
Evolution of Tolerance
Time
Tolerance Level
0.0
1.0
-1.0
1.0
true
true
"" ""
PENS
"Female-IN-Female" 1.0 0 -2064490 true "" "plot mean [get-IFC-tolerance] of primates with [sex = \"female\"]"
"Female-IN-Male" 1.0 0 -11221820 true "" "plot mean [get-IMA-tolerance] of primates with [sex = \"female\"]"
"Female-OUT-Female" 1.0 0 -5825686 true "" "plot mean [get-OFC-tolerance] of primates with [sex = \"female\"]"
"Female-OUT-Male" 1.0 0 -8630108 true "" "plot mean [get-OMA-tolerance] of primates with [sex = \"female\"]"
"Male-IN-Female" 1.0 0 -13840069 true "" "plot mean [get-IFC-tolerance] of primates with [sex = \"male\"]"
"Male-IN-Male" 1.0 0 -13791810 true "" "plot mean [get-IMA-tolerance] of primates with [sex = \"male\"]"
"Male-OUT-Female" 1.0 0 -955883 true "" "plot mean [get-OFC-tolerance] of primates with [sex = \"male\"]"
"Male-OUT-Male" 1.0 0 -2674135 true "" "plot mean [get-OMA-tolerance] of primates with [sex = \"male\"]"

MONITOR
219
380
334
425
Average Group Size
count primates / count groups
1
1
11

TEXTBOX
178
174
328
192
Energy Costs & Gains
11
0.0
1

PLOT
1250
10
1522
195
Evolution of Body Size
Time
Body Size
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"males" 1.0 0 -13791810 true "" "plot mean [size] of primates with [sex = \"male\"]"
"females" 1.0 0 -5825686 true "" "plot mean [size] of primates with [sex = \"female\"]"

PLOT
1530
10
1802
197
Relatedness
Time
Relatedness
0.0
10.0
0.0
0.25
true
true
"" ""
PENS
"within" 1.0 0 -7500403 true "" ";plot within-group-relatedness"
"between" 1.0 0 -16777216 true "" ""

PLOT
2014
327
2300
521
Group v Food
Group Size
Food Acquired
0.0
100.0
0.0
20.0
true
false
"" ""
PENS
"pen-0" 1.0 2 -7500403 true "" ""

PLOT
2008
224
2302
416
Group v Predation
Group Size
Predation Risk
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 2 -7500403 true "" ""

PLOT
2007
11
2303
211
Female Food Competition
Fighting Ability
Food Acquired
0.0
1.0
0.0
50.0
true
false
"" ""
PENS
"default" 1.0 2 -12087248 true "" ""

PLOT
2013
116
2300
316
Male Mate Competition
Fighting Ability
Mates Acquired
0.0
1.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 2 -5298144 true "" ""

SLIDER
7
98
163
131
group-size
group-size
0
100
20
1
1
NIL
HORIZONTAL

SLIDER
176
29
337
62
perception-range
perception-range
0
10
2
1
1
cells
HORIZONTAL

SLIDER
176
99
338
132
conception-rate
conception-rate
0
1.0
1
.01
1
NIL
HORIZONTAL

SLIDER
175
297
336
330
cost-per-growth-unit
cost-per-growth-unit
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
176
64
338
97
mutation-rate
mutation-rate
0
1.0
0.03
.01
1
NIL
HORIZONTAL

MONITOR
219
521
335
566
Generation
median [generation] of primates
17
1
11

SLIDER
175
227
336
260
cost-per-bmr
cost-per-bmr
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
176
134
338
167
max-longevity
max-longevity
0
100000
1360
10
1
ticks
HORIZONTAL

BUTTON
657
11
757
44
NIL
add-group
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1252
201
1523
389
Life History
time
ticks
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"gestation" 1.0 0 -8330359 true "" "plot mean [get-age-at-birth] of primates"
"infant" 1.0 0 -723837 true "" "plot mean [get-age-at-weaning] of primates"
"juvenile" 1.0 0 -2139308 true "" "plot mean [get-age-at-adulthood] of primates"
"adulthood" 1.0 0 -817084 true "" "plot mean [get-age-at-senescence] of primates"
"longevity" 1.0 0 -6459832 true "" "plot mean [get-longevity] of primates"

@#$#@#$#@
## WHAT IS IT?

This model explores the stability of predator-prey ecosystems. Such a system is called unstable if it tends to result in extinction for one or more species involved.  In contrast, a system is stable if it tends to maintain itself over time, despite fluctuations in population sizes.

## HOW IT WORKS

There are two main variations to this model.

In the first variation, wolves and sheep wander randomly around the landscape, while the wolves look for sheep to prey on. Each step costs the wolves energy, and they must eat sheep in order to replenish their energy - when they run out of energy they die. To allow the population to continue, each wolf or sheep has a fixed probability of reproducing at each time step. This variation produces interesting population dynamics, but is ultimately unstable.

The second variation includes grass (green) in addition to wolves and sheep. The behavior of the wolves is identical to the first variation, however this time the sheep must eat grass in order to maintain their energy - when they run out of energy they die. Once grass is eaten it will only regrow after a fixed amount of time. This variation is more complex than the first, but it is generally stable.

The construction of this model is described in two papers by Wilensky & Reisman referenced below.

## HOW TO USE IT

1. Set the GRASS? switch to TRUE to include grass in the model, or to FALSE to only include wolves (red) and sheep (white).
2. Adjust the slider parameters (see below), or use the default settings.
3. Press the SETUP button.
4. Press the GO button to begin the simulation.
5. Look at the monitors to see the current population sizes
6. Look at the POPULATIONS plot to watch the populations fluctuate over time

Parameters:
INITIAL-NUMBER-SHEEP: The initial size of sheep population
INITIAL-NUMBER-WOLVES: The initial size of wolf population
SHEEP-GAIN-FROM-FOOD: The amount of energy sheep get for every grass patch eaten
WOLF-GAIN-FROM-FOOD: The amount of energy wolves get for every sheep eaten
SHEEP-REPRODUCE: The probability of a sheep reproducing at each time step
WOLF-REPRODUCE: The probability of a wolf reproducing at each time step
GRASS?: Whether or not to include grass in the model
GRASS-REGROWTH-TIME: How long it takes for grass to regrow once it is eaten
SHOW-ENERGY?: Whether or not to show the energy of each animal as a number

Notes:
- one unit of energy is deducted for every step a wolf takes
- when grass is included, one unit of energy is deducted for every step a sheep takes

## THINGS TO NOTICE

When grass is not included, watch as the sheep and wolf populations fluctuate. Notice that increases and decreases in the sizes of each population are related. In what way are they related? What eventually happens?

Once grass is added, notice the green line added to the population plot representing fluctuations in the amount of grass. How do the sizes of the three populations appear to relate now? What is the explanation for this?

Why do you suppose that some variations of the model might be stable while others are not?

## THINGS TO TRY

Try adjusting the parameters under various settings. How sensitive is the stability of the model to the particular parameters?

Can you find any parameters that generate a stable ecosystem that includes only wolves and sheep?

Try setting GRASS? to TRUE, but setting INITIAL-NUMBER-WOLVES to 0. This gives a stable ecosystem with only sheep and grass. Why might this be stable while the variation with only sheep and wolves is not?

Notice that under stable settings, the populations tend to fluctuate at a predictable pace. Can you find any parameters that will speed this up or slow it down?

Try changing the reproduction rules -- for example, what would happen if reproduction depended on energy rather than being determined by a fixed probability?

## EXTENDING THE MODEL

There are a number ways to alter the model so that it will be stable with only wolves and sheep (no grass). Some will require new elements to be coded in or existing behaviors to be changed. Can you develop such a version?

## NETLOGO FEATURES

Note the use of breeds to model two different kinds of "turtles": wolves and sheep. Note the use of patches to model grass.

Note use of the ONE-OF agentset reporter to select a random sheep to be eaten by a wolf.

## RELATED MODELS

Look at Rabbits Grass Weeds for another model of interacting populations with different rules.

## CREDITS AND REFERENCES

Wilensky, U. & Reisman, K. (1999). Connected Science: Learning Biology through Constructing and Testing Computational Theories -- an Embodied Modeling Approach. International Journal of Complex Systems, M. 234, pp. 1 - 12. (This model is a slightly extended version of the model described in the paper.)

Wilensky, U. & Reisman, K. (2006). Thinking like a Wolf, a Sheep or a Firefly: Learning Biology through Constructing and Testing Computational Theories -- an Embodied Modeling Approach. Cognition & Instruction, 24(2), pp. 171-209. http://ccl.northwestern.edu/papers/wolfsheep.pdf


## HOW TO CITE

If you mention this model in a publication, we ask that you include these citations for the model itself and for the NetLogo software:

* Wilensky, U. (1997).  NetLogo Wolf Sheep Predation model.  http://ccl.northwestern.edu/netlogo/models/WolfSheepPredation.  Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.
* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2000.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
true
0
Circle -7500403 true true 0 0 300

pentagon
true
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

square
true
0
Rectangle -7500403 true true 30 30 270 270

star
true
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

triangle
true
0
Polygon -7500403 true true 150 30 15 255 285 255

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
setup
set grass? true
repeat 75 [ go ]
@#$#@#$#@
@#$#@#$#@
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
0
@#$#@#$#@
