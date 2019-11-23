extensions [sound]

globals [
  initial-chromosome
  initial-group-count
  initial-group-size
  initial-predator-count
  initial-predator-size
  boldness
]

breed [primates primate]
breed [groups group]
breed [predators predator]

groups-own [
  group-size
  group-radius
  group-density
]

primates-own [
  sex
  body-size
  age
  life-stage
  energy
  cycle-tick
  my-group
  mother
  father
  chromosomeI
  chromosomeII
  generation
  parasites
]

predators-own [
  predator-age
  victim ]

patches-own [
  penergy
  fertile?
  terminal-growth
]

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: SETUP ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to setup-world
  clear-all
  setup-parameters
  setup-patches
  setup-primates
  if parasites? [ setup-predators ]
  reset-ticks
end

to setup-primates
  clear-turtles
  load-chromosome
  setup-groups
end

to setup-parameters
  set initial-chromosome []
  set initial-group-count 5
  set initial-group-size 8
  set boldness 1
  set initial-predator-count 100
  set initial-predator-size 0.12
end

to setup-predators
  create-predators initial-predator-count [ initialize-predator ]
end

to setup-patches
  ask patches [ set fertile? false set penergy 0 ] ; initialize
  ask n-of patch-count patches [ ask patches in-radius (patch-radius * 1.25) [ if random-float 1.0 > ( distance myself / patch-radius ) ^ 3 [ set fertile? true ]]] ; abundance
  ask patches with [fertile?] [ set penergy patch-max-energy ]
  diffuse penergy ( patch-radius / ( patch-radius + 1 ))
  ask patches [ if penergy > 0 [ set terminal-growth penergy set fertile? true ]]
  ask patches [ set-patch-color ] ; color
end

to setup-groups
  repeat initial-group-count [ add-group ]
end

to add-group
  create-groups 1 [
    initialize-group
    move-to one-of patches
    hatch-primates initial-group-size [
      initialize-primate nobody nobody myself patch-here
      set hidden? false
      set energy random food-eaten-per-step * 100
      set age random get-age-at-senescence
      set size ifelse-value (age > get-age-at-adulthood) [ 1 ][ age / get-age-at-adulthood ]
      set body-size size
      if sex = "female" and age < get-age-at-senescence and age > get-age-at-adulthood [ update-fertility "c" ]
      set cycle-tick random get-cycle-length
      set life-stage get-life-history
      set color scale-color [color] of my-group age get-longevity 0
  ]]
end

;:::: INITIALIZE ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to initialize-group
  set color random 13 * 10 + 5
  set hidden? true
end

to initialize-primate [m f g startPatch]
  ifelse (m != nobody and f != nobody)
    [ set-chromosomes m f
      set generation [generation] of m + 1 ]
    [ initialize-chromosomes
      set generation 0 ]
  set sex ifelse-value (random-float 1.0 < get-sex-ratio) ["male"] ["female"]
  set shape ifelse-value (sex = "female") ["circle"] ["triangle"]
  set hidden? true
  set label-color grey
  set label ""
  set age 0
  set life-stage "fetus"
  set body-size 0
  set size 0
  set my-group g
  set xcor [pxcor] of startPatch + random 5 - random 5
  set ycor [pycor] of startPatch + random 5 - random 5
  set energy food-eaten-per-step
  set color scale-color [color] of my-group age get-longevity 0
  set parasites predators with [ victim = myself ]
end

to initialize-predator
  set label ""
  set hidden? false
  set shape "monster"
  set xcor random-xcor
  set ycor random-ycor
  set color black
  set size initial-predator-size
  set victim nobody
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go
  if count primates with [ sex = "female" ] = 0 or count primates with [ sex = "male" ] = 0 [ stop ]
  clear-links
  ask groups [ ifelse count primates with [my-group = myself] = 0 [ die ]
    [ groups-wander update-group-size update-group-radius update-group-density ]]
  ask patches [ grow-patches set-patch-color ]
  ask predators [ predator-wander predator-reproduce ]
  ask primates [ update-group-fidelity ]
  ask primates [ move ]
  ask primates [ compete ]
  ask primates [ mate ]
  ask primates [ groom ]
  ask primates [ eat ]
  ask primates [ grow ]
  ask primates [ basal-metabolism ]
  ask primates [ update-life-history ]
  if ceiling ( ticks / 10000 ) = (ticks / 10000) [ export-world (word "4329_20161019_05 G" median [generation] of primates ".csv")]
  tick
end

;:::: PREDATOR FUNCTIONS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to predator-wander
  ifelse victim = nobody
  [ right random 90
    left random 90
    fd 1 ]
  [ ask victim [ update-energy ( - parasite-cost-per-step * size ) ]]
  attempt-attack
end

to attempt-attack
  let current-victim victim
  ask primates-on patch-here [
    ask myself [ set victim myself ]
    set parasites predators with [ victim = myself ]
  ]
  if current-victim != victim and current-victim != nobody [ ask current-victim [ set parasites predators with [ victim = myself ]]]
end

to predator-reproduce
  if random-float 1.0 < ( 1 / (10000 * ( size ^ 3))) and victim != nobody [
    hatch-predators 1 [
      initialize-predator
      move-to myself
      set victim [victim] of myself ]]
end

;:::: GROUP FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to groups-wander
  set xcor mean [xcor] of primates with [ my-group = myself ]
  set ycor mean [ycor] of primates with [ my-group = myself ]
end

to update-group-size
  set group-size count primates with [ my-group = myself ]
end

to update-group-radius
  let ME self
  let members primates with [ my-group = myself ]
  let sorted-members sort-by [ distance ?1 < distance ?2 ] members
  let sublist-sorted-members sublist sorted-members 0 ( length sorted-members * 0.8 )
  set group-radius distance (item ( length sorted-members * 0.8 ) sorted-members) + 1
end

to update-group-density
  set group-density group-size / ( (pi * ( group-radius ^ 2 ) ) + 0.00001)
end

to-report get-group-members
  report primates with [ my-group = myself ]
end

;:::: PATCH FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to grow-patches
  ifelse fertile? [ ifelse penergy + patch-growth-rate > terminal-growth [ set penergy terminal-growth ] [ set penergy penergy + patch-growth-rate ]] [ set penergy 0 ]
end

to set-patch-color
  ifelse fertile?
  [ set pcolor scale-color green penergy (patch-max-energy * 1.2 ) 0 ]
  [ set pcolor ( brown + 4 ) ]
end

;:::: PRIMATE FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to update-group-fidelity
  let my-opinion 0
  let others-opinion 0
  let ME self
  ifelse count other [get-group-members] of my-group = 0
  ; CHECK IF SHOULD JOIN GROUP
  [ ask groups in-radius get-perception-range with [ self != [my-group] of ME ]
    [ if count get-group-members > 0 [
      set my-opinion mean [get-enemy-tolerance-magnitude ME] of get-group-members
      set others-opinion mean [get-tolerance-magnitude ME] of get-group-members
      if mean (list my-opinion others-opinion) > 0 [ ask ME [ join-group myself ]]]]]
  [ ; CHECK IF SHOULD LEAVE GROUP
    set my-opinion mean [get-enemy-tolerance-magnitude myself] of other [get-group-members] of my-group
    set others-opinion mean [get-tolerance-magnitude myself] of other [get-group-members] of my-group
    if mean (list my-opinion others-opinion) < 0 [ leave-group ]
  ]
end

to join-group [join]
  set my-group join
end

to leave-group
  let me-group nobody
  let ME self
  ask my-group [ hatch-groups 1 [
      initialize-group
      move-to [patch-here] of ME
      set me-group self
  ]]
  set my-group me-group
end

; GROW IN SIZE
to grow
  if get-life-history = "fetus" or get-life-history = "infant" or get-life-history = "juvenile" [
    let growth get-growth
    set body-size body-size + growth
    update-energy ( - cost-per-growth-unit * growth )
    set size ifelse-value (body-size > 1) [ body-size ^ (1 / 3) ] [ body-size ]
  ]
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

  ; JUVENILE, ADULT, ELDERLY, PREGNANT, LACTATING, OVULATING, CYCLING
  if get-life-history != "fetus" and get-life-history != "infant" [

    let ME self
    let X-magnitude 0.1
    let Y-magnitude 0.1

    ; HOME RANGE
    if distance my-group <= get-perception-range [
      let home-angle atan ([ycor] of my-group - ycor - 0.0001) ([xcor] of my-group - xcor + 0.0001)
      let home-magnitude get-home-weight * ( distance my-group ^ 2 )
      set X-magnitude X-magnitude + (home-magnitude * sin home-angle)
      set Y-magnitude Y-magnitude + (home-magnitude * cos home-angle)
    ]

    ; FOOD
    foreach [self] of other patches with [distance myself <= [get-perception-range] of myself and distance myself > 0.1] [
      let food-angle atan ([pycor] of ? - [ycor] of ME) ([pxcor] of ? - [xcor] of ME)
      let food-magnitude ( get-food-weight * [penergy] of ? ) / (distance ? ^ 2)
      set X-magnitude X-magnitude + food-magnitude * sin food-angle
      set Y-magnitude Y-magnitude + food-magnitude * cos food-angle
    ]

    ;CONSPECIFIC: in-female, in-male, out-female, out-male
    foreach [self] of primates with [distance myself <= [get-perception-range] of myself and distance myself > 0.1] [
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
      [ set conspecific-magnitude ( abs tolerance-magnitude ) * get-winning-likelihood ? * get-enemy-weight ]
      set X-magnitude X-magnitude + ((conspecific-magnitude / (distance ? ^ 2)) * sin conspecific-angle)
      set Y-magnitude Y-magnitude + ((conspecific-magnitude / (distance ? ^ 2)) * cos conspecific-angle)
    ]

    move-to-patch X-magnitude Y-magnitude
  ]
end

; MOVE IN DIRECTION
to move-to-patch [x y]
  set heading atan y x
  forward size
  ask parasites [
    move-to victim
    rt random 360
    fd random-float [size] of victim / 2 ]
  update-energy ( - cost-per-unit-step * size )
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
  let enemy min-one-of other primates in-radius 1 with [ get-life-history != "fetus" and get-enemy-tolerance-magnitude myself < 0 ] [ get-winning-likelihood myself ]
  if enemy != nobody [
    ifelse random-float 1.0 < get-winning-likelihood enemy
    [ ask enemy [ update-energy ( - cost-per-attack * [body-size] of myself ) set heading heading + 180 fd (2 * size) ] ]
    [ update-energy ( - cost-per-attack * [body-size] of enemy ) set heading heading + 180 fd (2 * size) ]]
end

; MATE WITH FRIEND here of opposite sex
to mate
  let ME self
  ifelse count my-in-links > 0 ; suitor available
  [ let suitor [other-end] of max-one-of my-in-links [ [get-tolerance-magnitude self] of myself ]
    ifelse sex = "female" [ copulate suitor ] [ ask suitor [ copulate ME ]]]
  [ let potential-mate max-one-of other primates in-radius 1 with [ get-life-history != "fetus" and sex != [sex] of myself ] [ [get-tolerance-magnitude self] of myself ]
    if potential-mate != nobody [ create-link-to potential-mate [ set hidden? true ] ]]
end

; Female COPULATE with Male partner
to copulate [partner]
  if ([get-life-history] of partner = "adult" or [get-life-history] of partner = "elderly") and get-life-history = "ovulating" [
    if random-float 1.0 < mean (list get-conception-rate [get-conception-rate] of partner) [
      hatch-primates 1 [ initialize-primate myself partner [my-group] of myself patch-here ]
      update-fertility "p" ]]
end

; GROOM
to groom
  let partner max-one-of other primates in-radius 1 with [ get-life-history != "fetus" ] [ get-enemy-tolerance-magnitude myself ]
  if partner != nobody [
    face partner
    ask parasites [ die ]
    ask partner [
      face myself
      ask parasites [ die ]]
  ]
end

; UPDATE LIFE HISTORY
to update-life-history
  set age age + 1
  set cycle-tick cycle-tick + 1

  if mother != nobody ; BIRTH UPDATES
  [ if age = floor mean (list get-age-at-birth [get-pregnancy-length] of mother) [
    set hidden? false
    ask mother [  update-fertility "l" ]]]

  if mother != nobody ; WEANING UPDATES
  [ if age = floor mean (list get-age-at-weaning [get-lactation-length] of mother) [ ask mother [  update-fertility "c" ]]]

  if age = get-age-at-adulthood and sex = "female" [ ; FEMALE ADULT UPDATES
    update-fertility "c" ]

  if age >= get-age-at-senescence and get-life-history != "pregnant" and get-life-history != "lactating" [ ; SENESCENCE UPDATES
    update-fertility "" ]

  ; ESTRUS CYCLE
  if get-life-history = "cycling" and cycle-tick = get-cycle-length [ update-fertility "o" ]
  if get-life-history = "ovulating" and cycle-tick = get-ovulation-length [  update-fertility "c" ]

  ; DEATH FROM OLD AGE
  if age > get-longevity [ make-dead ]

  set life-stage get-life-history
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
;::::: CHROMOSOME CALCULATIONS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to-report get-chromosome [index]
  let valueI item index chromosomeI
  let valueII item index chromosomeII
  report mean ( list valueI valueII )
end

to-report get-winning-likelihood [enemy]
  report (( body-size / ( body-size + [body-size] of enemy + 0.0000001)) ^ boldness )
end

to-report get-enemy-winning-likelihood [enemy]
  report [get-winning-likelihood myself] of enemy
end

to set-chromosomes [m f]
  set mother m
  set father f

  let i 0;
  while [i < length [chromosomeI] of m ] [ ifelse random 100 < 50
  [ set chromosomeI replace-item i chromosomeI item i [chromosomeI] of m ]
  [ set chromosomeI replace-item i chromosomeI item i [chromosomeI] of f ]
  set i i + 1 ]

  set i 0;
  while [i < length [chromosomeII] of m ] [ ifelse random 100 < 50
  [ set chromosomeII replace-item i chromosomeII item i [chromosomeII] of m ]
  [ set chromosomeII replace-item i chromosomeII item i [chromosomeII] of f ]
  set i i + 1 ]

  mutate-genes get-mutation-rate
end

to mutate-genes [rate]
  repeat length chromosomeI * 2 [
    if random-float 1.0 < rate [
      let index random length chromosomeI
      ifelse random-float 1.0 < 0.5
      [ let itemI ( item index chromosomeI / 10 )
        set chromosomeI replace-item index chromosomeI ((item index chromosomeI + random-float itemI - random-float itemI) * ifelse-value (random-float 1.0 < 0.5) [ -1 ][ 1 ]) ]
      [ let itemII item index chromosomeII
        set chromosomeII replace-item index chromosomeII ((item index chromosomeII + random-float itemII - random-float itemII) * ifelse-value (random-float 1.0 < 0.5) [ -1 ][ 1 ]) ]]]
end

; AGE INDEX
to-report get-age-index
  let index 0
  if age >= get-age-at-birth [ set index 1 ]
  if age >= get-age-at-weaning [ set index 2 ]
  if age >= get-age-at-adulthood [ set index 3 ]
  if age >= get-age-at-senescence [ set index 4 ]
  report index
end

; FERTILITY INDEX: 5 = CYCLING 6 = OVULATING 7 = PREGNANT 8 = LACTATING
to-report get-fertility-index
  let index 0
  if label = "c" [ set index 5 ]
  if label = "o" [ set index 6 ]
  if label = "p" [ set index 7 ]
  if label = "l" [ set index 8 ]
  report index
end

; LIFE HISTORY STATUS INDEX
to-report get-status-index
  let index get-age-index
  if sex = "female" and index = 3 [ set index get-fertility-index ]
  report index
end

; LIFE HISTORY STATUS
to-report get-life-history
  let status get-status-index
  let life-history ""
  if status = 0 [ set life-history "fetus" ]
  if status = 1 [ set life-history "infant" ]
  if status = 2 [ set life-history "juvenile" ]
  if status = 3 [ set life-history "adult" ]
  if status = 4 [ set life-history "elderly" ]
  if status = 5 [ set life-history "cycling" ]
  if status = 6 [ set life-history "ovulating" ]
  if status = 7 [ set life-history "pregnant" ]
  if status = 8 [ set life-history "lactating" ]
  report life-history
end

to initialize-chromosomes
  ifelse (empty? initial-chromosome)
  [
    set chromosomeI []
    set chromosomeII []
    repeat 300 [ set chromosomeI lput (random-float 1.0 - random-float 1.0) chromosomeI ]
    repeat 300 [ set chromosomeII lput (random-float 1.0 - random-float 1.0) chromosomeII ]
  ][
    set chromosomeI initial-chromosome
    set chromosomeII initial-chromosome
  ]
  set mother nobody
  set father nobody
  mutate-genes get-mutation-rate
end

; GET CHROMOSOMES: must be modified if the chromosome file changes
; LIFE HISTORY
to-report get-age-at-birth let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report ceiling (abs get-chromosome ( 0 + index )) end
to-report get-age-at-weaning let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report ceiling abs get-chromosome ( 1 + index ) + get-age-at-birth end
to-report get-age-at-adulthood let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report ceiling abs get-chromosome ( 2 + index ) + get-age-at-birth + get-age-at-weaning end
to-report get-age-at-senescence let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report ceiling abs get-chromosome ( 3 + index ) + get-age-at-birth + get-age-at-weaning + get-age-at-adulthood  end
to-report get-longevity let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report ceiling abs get-chromosome ( 4 + index ) +  get-age-at-birth + get-age-at-weaning + get-age-at-adulthood + get-age-at-senescence end
to-report get-cycle-length report abs get-chromosome 5 end
to-report get-ovulation-length report ceiling abs get-chromosome 6 end
to-report get-pregnancy-length report ceiling abs get-chromosome 7 end
to-report get-lactation-length report ceiling abs get-chromosome 8 end

to-report get-growth let index ifelse-value (sex = "female") [ 0 ] [ 3 ]
  report abs (get-chromosome (14 + index + get-status-index)) end
to-report get-placental-energy report abs get-chromosome 20 end
to-report get-lactation-energy report abs get-chromosome 21 end

; DISPERSAL
to-report get-dispersion let index ifelse-value (sex = "female") [ 0 ] [ 9 ]
  report (get-chromosome (22 + index + get-status-index)) end

; WEIGHTS
to-report get-home-weight report get-chromosome (40 + get-status-index) end
to-report get-food-weight report get-chromosome (49 + get-status-index) end
to-report get-friend-weight report get-chromosome (58 + get-status-index) end
to-report get-enemy-weight report get-chromosome (67 + get-status-index) end
to-report get-mate-weight report get-chromosome (76 + get-status-index) end

; TOLERANCE LEVELS
to-report get-IFI-tolerance report get-chromosome (85 + get-status-index) end
to-report get-IFJ-tolerance report get-chromosome (94 + get-status-index) end
to-report get-IFP-tolerance report get-chromosome (103 + get-status-index) end
to-report get-IFO-tolerance report get-chromosome (112 + get-status-index) end
to-report get-IFC-tolerance report get-chromosome (121 + get-status-index) end
to-report get-IFL-tolerance report get-chromosome (130 + get-status-index) end
to-report get-IFE-tolerance report get-chromosome (139 + get-status-index) end
to-report get-IMI-tolerance report get-chromosome (148 + get-status-index) end
to-report get-IMJ-tolerance report get-chromosome (157 + get-status-index) end
to-report get-IMA-tolerance report get-chromosome (166 + get-status-index) end
to-report get-IME-tolerance report get-chromosome (175 + get-status-index) end
to-report get-OFI-tolerance report get-chromosome (184 + get-status-index) end
to-report get-OFJ-tolerance report get-chromosome (193 + get-status-index) end
to-report get-OFP-tolerance report get-chromosome (202 + get-status-index) end
to-report get-OFO-tolerance report get-chromosome (211 + get-status-index) end
to-report get-OFC-tolerance report get-chromosome (220 + get-status-index) end
to-report get-OFL-tolerance report get-chromosome (229 + get-status-index) end
to-report get-OFE-tolerance report get-chromosome (238 + get-status-index) end
to-report get-OMI-tolerance report get-chromosome (247 + get-status-index) end
to-report get-OMJ-tolerance report get-chromosome (256 + get-status-index) end
to-report get-OMA-tolerance report get-chromosome (265 + get-status-index) end
to-report get-OME-tolerance report get-chromosome (274 + get-status-index) end

to-report get-sex-ratio report get-chromosome 283 end
to-report get-perception-range report abs get-chromosome 284 end
to-report get-mutation-rate report abs get-chromosome 285 end
to-report get-conception-rate report get-chromosome (286 + get-status-index) end

; FOR THE PLOTS
to-report get-infemale-tolerance report ( get-IFI-tolerance + get-IFJ-tolerance + get-IFP-tolerance + get-IFO-tolerance + get-IFC-tolerance + get-IFL-tolerance + get-IFE-tolerance) / 7 end
to-report get-inmale-tolerance report ( get-IMI-tolerance + get-IMJ-tolerance + get-IMA-tolerance + get-IME-tolerance ) / 4 end
to-report get-outfemale-tolerance report (get-OFI-tolerance + get-OFJ-tolerance + get-OFP-tolerance + get-OFO-tolerance + get-OFC-tolerance + get-OFL-tolerance + get-OFE-tolerance ) / 7 end
to-report get-outmale-tolerance report (get-OMI-tolerance + get-OMJ-tolerance + get-OMA-tolerance + get-OME-tolerance) / 4 end

; TOLERANCE
to-report get-enemy-tolerance-magnitude [enemy]
  report [get-tolerance-magnitude myself] of enemy
end

; TOLERANCE
to-report get-tolerance-magnitude [alter]
  let reporter 0
  ifelse [my-group] of alter = my-group
  [ ifelse [sex] of alter = "female" [

    ; INGROUP FEMALE
    if [get-life-history] of alter = "infant" [ set reporter get-IFI-tolerance ]
    if [get-life-history] of alter = "juvenile" [ set reporter get-IFJ-tolerance ]
    if [get-life-history] of alter = "pregnant" [ set reporter get-IFP-tolerance ]
    if [get-life-history] of alter = "ovulating" [ set reporter get-IFO-tolerance ]
    if [get-life-history] of alter = "cycling" [ set reporter get-IFC-tolerance ]
    if [get-life-history] of alter = "lactating" [ set reporter get-IFL-tolerance ]
    if [get-life-history] of alter = "elderly" [ set reporter get-IFE-tolerance ]]

  [ ; INGROUP MALE
    if [get-life-history] of alter = "infant" [ set reporter get-IMI-tolerance ]
    if [get-life-history] of alter = "juvenile" [ set reporter get-IMJ-tolerance ]
    if [get-life-history] of alter = "adult" [ set reporter get-IMA-tolerance ]
    if [get-life-history] of alter = "elderly" [ set reporter get-IME-tolerance ]]]

  [ ifelse [sex] of alter = "female" [

    ; OUTGROUP FEMALE
    if [get-life-history] of alter = "infant" [ set reporter get-OFI-tolerance ]
    if [get-life-history] of alter = "juvenile" [ set reporter get-OFJ-tolerance ]
    if [get-life-history] of alter = "pregnant" [ set reporter get-OFP-tolerance ]
    if [get-life-history] of alter = "ovulating" [ set reporter get-OFO-tolerance ]
    if [get-life-history] of alter = "cycling" [ set reporter get-OFC-tolerance ]
    if [get-life-history] of alter = "lactating" [ set reporter get-OFL-tolerance ]
    if [get-life-history] of alter = "elderly" [ set reporter get-OFE-tolerance ]]

  [ ; OUTGROUP MALE
    if [get-life-history] of alter = "infant" [ set reporter get-OMI-tolerance ]
    if [get-life-history] of alter = "juvenile" [ set reporter get-OMJ-tolerance ]
    if [get-life-history] of alter = "adult" [ set reporter get-OMA-tolerance ]
    if [get-life-history] of alter = "elderly" [ set reporter get-OME-tolerance ]]]

  report reporter
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;::::: FILE LOADER :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to load-chromosome
  let file user-file
  let readbit 0

  if ( file != false )
  [
    set initial-chromosome []
    file-open file

    while [ not file-at-end? ]
      [ set readbit file-read
        if ( is-number? readbit ) [ set initial-chromosome sentence initial-chromosome readbit ]]

    user-message "File loading complete!"
    file-close
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
256
61
772
598
-1
-1
24.1
1
14
1
1
1
0
1
1
1
0
20
0
20
0
0
1
ticks
30.0

BUTTON
397
14
486
47
setup
setup-world
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
493
14
575
47
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
1

PLOT
785
10
1126
189
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
"males" 1.0 0 -13791810 true "" "if count primates > 0 [plot count primates with [sex = \"male\"]]"
"females            " 1.0 0 -5825686 true "" "if count primates > 0 [plot count primates with [sex = \"female\"]]"
"total" 1.0 0 -7500403 true "" "if count primates > 0 [plot count primates]"

TEXTBOX
72
185
187
204
Primate Settings
13
0.0
0

TEXTBOX
81
10
183
28
Patch Settings
13
0.0
0

SLIDER
36
103
213
136
patch-growth-rate
patch-growth-rate
0
50
10
1
1
NIL
HORIZONTAL

SLIDER
36
138
213
171
patch-max-energy
patch-max-energy
0
1000
800
10
1
NIL
HORIZONTAL

SLIDER
36
208
212
241
food-eaten-per-step
food-eaten-per-step
0
50
30
1
1
NIL
HORIZONTAL

SLIDER
36
278
212
311
cost-per-unit-step
cost-per-unit-step
0
50
2
1
1
NIL
HORIZONTAL

SLIDER
36
348
212
381
cost-per-attack
cost-per-attack
0
50
20
1
1
NIL
HORIZONTAL

PLOT
1131
211
1569
402
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
"female-IN-female" 1.0 0 -2064490 true "" "if (count primates with [ sex = \"female\" ] > 0) [plot mean [get-infemale-tolerance] of primates with [sex = \"female\"]]"
"Female-IN-Male" 1.0 0 -11221820 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-inmale-tolerance] of primates with [sex = \"female\"]]"
"Female-OUT-Female" 1.0 0 -5825686 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-outfemale-tolerance] of primates with [sex = \"female\"]]"
"Female-OUT-Male" 1.0 0 -8630108 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-outmale-tolerance] of primates with [sex = \"female\"]]"
"Male-IN-Female" 1.0 0 -13840069 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-infemale-tolerance] of primates with [sex = \"male\"]]"
"Male-IN-Male" 1.0 0 -13791810 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-inmale-tolerance] of primates with [sex = \"male\"]]"
"Male-OUT-Female" 1.0 0 -955883 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-outfemale-tolerance] of primates with [sex = \"male\"]]"
"Male-OUT-Male" 1.0 0 -2674135 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-outmale-tolerance] of primates with [sex = \"male\"]]"

PLOT
1574
10
1829
207
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
"males" 1.0 0 -13791810 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [size] of primates with [sex = \"male\"]]"
"females" 1.0 0 -5825686 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [size] of primates with [sex = \"female\"]]"

PLOT
785
195
1126
595
Group Composition
Time
# Members
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Maximum Group Size " 1.0 0 -11053225 true "" "if count groups > 0 [ plot [group-size] of max-one-of groups [group-size]]"
"Average Group Size" 1.0 0 -7500403 true "" "if count groups > 0 [ plot count primates / count groups]"
"Minimum Group Size" 1.0 0 -4539718 true "" "if count groups > 0 [plot [group-size] of min-one-of groups [group-size]]"
"Number of Infants" 1.0 0 -723837 true "" "if count groups > 0 [plot count primates with [get-life-history = \"infant\"] / count groups]"
"Number of Juveniles" 1.0 0 -817084 true "" "if count groups > 0 [plot count primates with [get-life-history = \"juvenile\"] / count groups]"
"Number of Adult Females    " 1.0 0 -3508570 true "" "if count groups > 0 [plot (count primates with [get-life-history = \"cycling\"] + count primates with [ get-life-history = \"ovulating\"] + count primates with [get-life-history = \"pregnant\"] + count primates with [get-life-history = \"lactating\"]) / count groups]"
"Number of Adult Males" 1.0 0 -2139308 true "" "if count groups > 0 [plot count primates with [get-life-history = \"adult\"] / count groups]"
"Number of Senescent" 1.0 0 -10649926 true "" "if count groups > 0 [plot count primates with [get-life-history = \"elder\"] / count groups]"

SLIDER
36
313
212
346
cost-per-growth-unit
cost-per-growth-unit
0
50
15
1
1
NIL
HORIZONTAL

MONITOR
585
10
676
55
Generation
median [generation] of primates
17
1
11

SLIDER
36
243
212
276
cost-per-bmr
cost-per-bmr
0
50
10
1
1
NIL
HORIZONTAL

PLOT
1575
212
1829
403
Life History: Stages
Time
Ticks
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"gestation" 1.0 0 -8330359 true "" "if count primates > 0 [plot mean [get-age-at-birth] of primates]"
"infant" 1.0 0 -723837 true "" "if count primates > 0 [plot mean [get-age-at-weaning] of primates]"
"juvenile" 1.0 0 -817084 true "" "if count primates > 0 [plot mean [get-age-at-adulthood] of primates]"
"adulthood" 1.0 0 -2139308 true "" "if count primates > 0 [plot mean [get-age-at-senescence] of primates]"
"longevity" 1.0 0 -10649926 true "" "if count primates > 0 [plot mean [get-longevity] of primates]"

PLOT
1576
406
1829
594
Life History: Fertility
Time
Ticks
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"estrus cycle" 1.0 0 -7500403 true "" "if count primates > 0 [plot mean [get-cycle-length] of primates with [ sex = \"female\" ]]"
"ovulation" 1.0 0 -5825686 true "" "if count primates > 0 [plot mean [get-cycle-length + get-ovulation-length] of primates with [ sex = \"female\" ]]"
"pregnancy" 1.0 0 -8630108 true "" "if count primates > 0 [plot mean [get-pregnancy-length] of primates with [ sex = \"female\" ]]"
"lactation" 1.0 0 -11221820 true "" "if count primates > 0 [plot mean [get-lactation-length + get-pregnancy-length] of primates with [ sex = \"female\" ]]"

BUTTON
690
13
760
46
Clear Plots
clear-all-plots
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
1132
406
1571
604
Sex-Biased Weight Preferences
Time
Weight
0.0
10.0
-1.0
1.0
true
true
"" ""
PENS
"female-home" 1.0 0 -6917194 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-home-weight] of primates with [ sex = \"female\" ]]"
"male-home" 1.0 0 -10141563 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-home-weight] of primates with [ sex = \"male\" ]]"
"female-food" 1.0 0 -13840069 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-food-weight] of primates with [ sex = \"female\" ]]"
"male-food" 1.0 0 -15040220 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-food-weight] of primates with [ sex = \"male\" ]]"
"female-friend" 1.0 0 -1184463 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-friend-weight] of primates with [ sex = \"female\" ]]"
"male-friend" 1.0 0 -7171555 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-friend-weight] of primates with [ sex = \"male\" ]]"
"female-enemy" 1.0 0 -2139308 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-enemy-weight] of primates with [ sex = \"female\" ]]"
"male-enemy" 1.0 0 -5298144 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-enemy-weight] of primates with [ sex = \"male\" ]]"
"female-mate" 1.0 0 -2064490 true "" "if count primates with [ sex = \"female\" ] > 0 [plot mean [get-mate-weight] of primates with [ sex = \"female\" ]]"
"male-mate" 1.0 0 -7713188 true "" "if count primates with [ sex = \"male\" ] > 0 [plot mean [get-mate-weight] of primates with [ sex = \"male\" ]]"

MONITOR
965
491
1037
536
M : F
precision (count primates with [ sex = \"male\" and get-status-index > 2 ] / count primates with [ sex = \"female\" and get-status-index > 2 ]) 3
17
1
11

MONITOR
965
443
1036
488
Density
mean [ group-density ] of groups
2
1
11

SLIDER
36
33
213
66
patch-count
patch-count
1
50
50
1
1
NIL
HORIZONTAL

SLIDER
36
68
213
101
patch-radius
patch-radius
1
10
1
1
1
NIL
HORIZONTAL

PLOT
1130
10
1355
206
Group Radius
Time
Cells
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Maximum" 1.0 0 -11053225 true "" "if count groups > 0 [plot [group-radius] of max-one-of groups [group-radius]]"
"Average" 1.0 0 -7500403 true "" "if count groups > 0 [plot mean [group-radius] of groups]"
"Minimum" 1.0 0 -4539718 true "" "if count groups > 0 [plot [group-radius] of min-one-of groups [group-radius]]"

PLOT
1360
10
1570
207
Group Density
Time
Density
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Maximum" 1.0 0 -11053225 true "" "if count groups > 0 [plot [ group-density ] of max-one-of groups [ group-density ]]"
"Average" 1.0 0 -7500403 true "" "if count groups > 0 [plot mean [ group-density ] of groups]"
"Minimum" 1.0 0 -4539718 true "" "if count groups > 0 [plot [ group-density ] of min-one-of groups [ group-density ]]"

MONITOR
1040
444
1113
489
# Adult ♀
precision ((count primates with [get-life-history = \"cycling\"] + count primates with [ get-life-history = \"ovulating\"] + count primates with [get-life-history = \"pregnant\"] + count primates with [get-life-history = \"lactating\"]) / count groups) 2
17
1
11

MONITOR
1040
349
1112
394
# Infants
precision (count primates with [get-life-history = \"infant\"] / count groups) 2
17
1
11

MONITOR
1040
396
1113
441
# Juveniles
precision (count primates with [get-life-history = \"juvenile\"] / count groups) 2
17
1
11

MONITOR
1040
491
1114
536
# Adult ♂
precision (count primates with [get-life-history = \"adult\"] / count groups) 2
17
1
11

MONITOR
1040
538
1115
583
# Senescent
precision (count primates with [get-life-history = \"elder\"] / count groups) 2
17
1
11

MONITOR
966
349
1037
394
Group Size
count primates / count groups
2
1
11

MONITOR
1037
84
1108
129
# Primates
count primates
17
1
11

MONITOR
1038
132
1109
177
# Groups
count groups
17
1
11

MONITOR
966
396
1036
441
Radius
mean [group-radius] of groups
2
1
11

SLIDER
36
384
212
417
parasite-cost-per-step
parasite-cost-per-step
0
50
3
1
1
NIL
HORIZONTAL

PLOT
15
435
243
590
Parasite Population
Time
Population
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"parasites" 1.0 0 -16777216 true "" "if count primates > 0 [plot count predators]"

SWITCH
271
15
390
48
parasites?
parasites?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?


## HOW IT WORKS


## HOW TO USE IT


## THINGS TO NOTICE


## THINGS TO TRY


## COPYRIGHT AND LICENSE

Copyright 2016 K N Crouse
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
true
0
Circle -7500403 true true 0 0 300

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

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
