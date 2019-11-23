extensions [sound]

globals [group-count]
breed [males male]
breed [females female]
breed [groups group]
breed [predators predator]
turtles-own [age energy fighting-ability intragroup-tolerance intergroup-tolerance my-group home-base adult? genes mother father food-eaten]
patches-own [penergy fertile? terminal-growth call-made?]
females-own [male-mate f-male-tolerance f-female-tolerance]
males-own [mate-number m-male-tolerance m-female-tolerance]
groups-own [group-size group-color predation-count]
predators-own [predator-age]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-patches;
  setup-groups;
  reset-ticks
end

to setup-patches
  ask patches [ set fertile? false set penergy 0 set call-made? false ] ;; initialize
  ask n-of (patch-abundance * count patches) patches [ set fertile? true ] ;; abundance
  ask n-of (patch-patchiness * count patches) patches [ ifelse count neighbors with [fertile?] > 3 [ set fertile? true ] [ set fertile? false ] ] ;; patchiness
  ask patches with [fertile?] [ set terminal-growth 1 + random patch-max-energy - 1  set penergy terminal-growth] ;; energy
  ask patches [ set-patch-color ] ;; color
end

to setup-groups
  create-groups initial-group-count [ set group-color random 13 * 10 + 2 + random 5 ]
  
  foreach [self] of groups [
    let groupPatch one-of patches;
    create-males initial-number-males [ initialize-male nobody nobody ? groupPatch ];
    create-females initial-number-females [ initialize-female nobody nobody ? groupPatch ];
  ]
end

to initialize-genes 
  let i 0;
  while [i < 16] [
    set genes replace-item i genes one-of ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"]
    set i i + 1
  ]
end

to mutate-genes [g]
  let i random 15;
  set g replace-item i g one-of ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ask groups [ if count turtles with [my-group = myself] = 0 [ die ] set predation-count 0]
  update-group-food-graph
  update-group-predation-graph
  update-competition-food-graph
  update-competition-mates-graph
  ask patches [ grow-patches set-patch-color set call-made? false ]
  ask males [ move compete eat ] 
  ask females [ move compete eat ]
  ask females [ mate reproduce ]
  ask males [ check-death update-life-history ]
  ask females [ check-death update-life-history ]
  ask groups [ set group-size count males with [my-group = myself] + count females with [ my-group = myself] ]
  ask males [ count-mates ]
  if count males = 0 or count females = 0 [ stop ]
  check-add-predator
  ask predators [ move-predators ]
  tick
end

to count-mates
  ask males [ set mate-number 0 set mate-number count females-on neighbors + count females-here ];
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; INITIALIZE PRIMATE FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to initialize-male [m f g startPatch]
  set size 2.0;
  set shape "triangle";
  ifelse m = nobody
     [set m-female-tolerance (male-female-tolerance * 100 + random 50 - random 50) / 100;
      set m-male-tolerance (male-male-tolerance * 100 + random 50 - random 50) / 100]
     [set m-female-tolerance [m-female-tolerance] of f
      set m-male-tolerance [m-male-tolerance] of f]
  initialize-primate m f g startPatch
end

to initialize-female [m f g startPatch]
  set size 1.5;
  set shape "circle";
  ifelse f = nobody 
     [set f-female-tolerance (female-female-tolerance * 100 + random 50 - random 50) / 100;
      set f-male-tolerance (female-male-tolerance * 100 + random 50 - random 50) / 100]
     [set f-female-tolerance [f-female-tolerance] of m
      set f-male-tolerance [f-male-tolerance] of m]
  initialize-primate m f g startPatch
end

to initialize-primate [m f g startPatch]
  set label-color white;
  set energy random 50;
  set age 0;
  set home-base startPatch;
  set genes "aaaaaaaaaaaaaaaa";
  set my-group g;
  set color [group-color] of my-group + 2;
  set xcor [pxcor] of startPatch + random 5 - random 5;
  set ycor [pycor] of startPatch + random 5 - random 5;
  ifelse (m = nobody or f = nobody)
     [ initialize-genes 
       set fighting-ability (ave-fighting-ability * 100 + random 50 - random 50) / 100;
       set intragroup-tolerance (ave-intragroup-tolerance * 100 + random 50 - random 50) / 100;
       set intergroup-tolerance (ave-intergroup-tolerance * 100 + random 50 - random 50) / 100] 
     [ set-genes m f
       if random 100 < 5 [ mutate-genes genes ]
       set mother m
       set father f
       set fighting-ability (([fighting-ability] of mother + [fighting-ability] of father) / 2)
       set intragroup-tolerance (([intragroup-tolerance] of mother + [intragroup-tolerance] of father) / 2)
       set intergroup-tolerance (([intergroup-tolerance] of mother + [intergroup-tolerance] of father) / 2)]
  set adult? false;
  update-life-history;
  if my-group = 0 or genes = 0 [ make-dead ]
end

to set-genes [m f]
  let i 0;
  while [i < 16] [ ifelse random 100 < 50 [ 
      set genes replace-item i genes item i [genes] of m ] [ 
      set genes replace-item i genes item i [genes] of f ]
      set i i + 1 ]
end

to-report tolerance-level [ego enemy]
  ifelse [my-group] of ego = [my-group] of enemy [
    report [intragroup-tolerance] of ego] [
    report [intergroup-tolerance] of ego]
end

to-report degree-relatedness [ego kin]
  let kinPoints 0;
  let i 0;
  ifelse [genes] of ego = 0 or [genes] of kin = 0 [ report 0 ] [
    while [i < 16] [
      if item i [genes] of ego = item i [genes] of kin [ set kinPoints kinPoints + 1 ]
      set i i + 1 ]
    report kinPoints / 16 ]
end

to-report sex-tolerance [ego conspecific]
  if [breed] of ego = males and [breed] of conspecific = males [ report [m-male-tolerance] of ego ]
  if [breed] of ego = males and [breed] of conspecific = females [ report [m-female-tolerance] of ego ]
  if [breed] of ego = females and [breed] of conspecific = males [ report [f-male-tolerance] of ego ]
  if [breed] of ego = females and [breed] of conspecific = females [ report [f-female-tolerance] of ego ]
end

to-report within-group-relatedness
  let relatedness 0;
  
  foreach [self] of turtles with [breed = males or breed = females] [
     let meTurtle ?;
     foreach [self] of other turtles with [(breed = males or breed = females) and my-group = [my-group] of meTurtle] [
       set relatedness relatedness + degree-relatedness meTurtle ?;
     ]
  ]
  
  report relatedness / ( count turtles with [breed = males or breed = females] ^ 2);
end

to-report between-group-relatedness
  let relatedness 0;
  
  foreach [self] of turtles with [breed = males or breed = females] [
     let meTurtle ?;
     foreach [self] of other turtles with [(breed = males or breed = females) and my-group != [my-group] of meTurtle] [
       set relatedness relatedness + degree-relatedness meTurtle ?;
     ]
  ]
  
  report relatedness / ( count turtles with [breed = males or breed = females] ^ 2);
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; PRIMATE FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move
  let bestPatch patch-here;
  let bestPatchValue 1;
  let meTurtle self;
  
  
  foreach [self] of patches with [distance myself < perception-range] [
    
    ;; FOOD = ( percent food value of max potential) x ( current energy deficit ) x ( proximity to food )
    let foodValue ([penergy] of ? / patch-max-energy) * (1 - ([energy] of meTurtle / max-energy)) * ( 1 - (distance meTurtle / perception-range));

    ;; HOME RANGE = ( proximity of patch to home ) x ( current distance from home )
    let homeValue 0;
    if [home-base] of meTurtle != 0 [set homeValue (1 / (([distance [home-base] of meTurtle] of ? / 50 ) + 0.1)) * (distance [home-base] of meTurtle / 50)] 
    
    ;; CONSPECIFIC = SUM ( percent of surrounding individuals) x ( lack of fighting ability ) x ( intolerance toward individual) x ( unrelatedness to individual) x ( proximity to individual) x (intolerance of sex);
    let conspecificValue 0;
    foreach [self] of females-on ? [
      set conspecificValue conspecificValue + ( 1 / count turtles-on ? ) * ( 1 - fighting-ability ) * (1 - tolerance-level meTurtle ?) * (1 - degree-relatedness meTurtle ?) * ( 1 - (distance meTurtle / perception-range)) * (1 - sex-tolerance meTurtle ?)  ]
    foreach [self] of males-on ? [
      set conspecificValue conspecificValue + ( 1 / count turtles-on ? ) * ( 1 - fighting-ability ) * (1 - tolerance-level meTurtle ?) * (1 - degree-relatedness meTurtle ?) * ( 1 - (distance meTurtle / perception-range)) * (1 - sex-tolerance meTurtle ?)  ]
    
    ;; MATES = ( percent of surrounding individuals)
    let mateValue 0;
    ifelse [breed] of meTurtle = females [
      if male-mate = nobody or male-mate = 0 [ set mateValue 1 ]
    ] [
      if count females-on ? > 0 [ set mateValue (count females-on ? / count females-on patches with [distance meTurtle < perception-range] )]
    ]
    
    ;; PREDATORS
    let predatorValue 0;
    if [call-made?] of ? [ set predatorValue 1 ]
    if count predators-on ? > 0 [ set predatorValue predatorValue + (count predators-on ? / count predators-on patches with [distance meTurtle < perception-range] )]
    if predatorValue > 0 and play-alarm-calls? [ sound:play-note "Bird Tweet" 40 - random 5 40 - random 5  0.3
                                                 ask ? [ set call-made? true ]]
      
    ;; TOTAL
    let patchValue homeValue * home-weightedness + foodValue * food-weightedness - conspecificValue * conspecific-weightedness + mateValue * mate-weightedness - predatorValue * predation-weightedness;
    
    if patchValue > bestPatchValue [ set bestPatchValue patchValue  set bestPatch ? ]]
 
  move-to-patch bestPatch;
end

to move-to-patch [to-patch]
    set energy energy - energy-cost-per-step
    face to-patch
    rt random-float 20
    lt random-float 20
    fd 1
end

to compete
  let meTurtle self;
  foreach [self] of other males-here [
    ask ? [ set energy energy - ([fighting-ability] of myself) * (aggression-cost) * (1 - tolerance-level meTurtle ?) * (1 - degree-relatedness meTurtle ?) * (1 - sex-tolerance meTurtle ?)]
  ]
  foreach [self] of other females-here [
    ask ? [ set energy energy - ([fighting-ability] of myself) * (aggression-cost) * (1 - tolerance-level meTurtle ?) * (1 - degree-relatedness meTurtle ?) * (1 - sex-tolerance meTurtle ?)]
  ]
  foreach [self] of other predators-here [
    ask ? [ set predator-age predator-age + ([fighting-ability] of myself) * (aggression-cost)]
  ]
end

to mate
  let potential-mates males with [patch-here = [patch-here] of myself]
  if any? potential-mates and adult? [
    if random 100 < 50 [
      set male-mate one-of potential-mates;
    ]   
  ]
end

to eat
  ifelse penergy > food-eaten-per-step [
    set food-eaten food-eaten-per-step
  ] [
    set food-eaten penergy
  ]
  set energy energy + food-eaten
  set penergy penergy - food-eaten
end

to reproduce
  if energy > (birth-cost + energy-cost-per-step + aggression-cost) and adult? [
    if male-mate != 0 and male-mate != nobody [
       set energy energy - birth-cost
       ifelse random 100 < 50 [ hatch-males 1 [ initialize-male myself [male-mate] of myself [my-group] of myself patch-here]] 
                              [ hatch-females 1 [ initialize-female myself [male-mate] of myself [my-group] of myself patch-here]]
       set male-mate nobody;
    ]
  ]
end

to update-life-history
  set age age + 1
  if age < age-at-maturity [ set adult? false ] ; youth
  if age = age-at-maturity [ check-transfer set color color - 2] ; transfer
  if age > age-at-maturity [ set adult? true ] ; adult
  if age > life-expectancy [ make-dead ] ; die
end

to check-death
  if energy < 0 or my-group = 0 [ make-dead ]
end

to make-dead
  die
end

to check-transfer
  if (breed = males and male-transfer?) or (breed = females and female-transfer?) [
    set my-group [my-group] of one-of turtles with [my-group != [my-group] of myself]
    set home-base [home-base] of one-of turtles with [my-group = [my-group] of myself]
  ]  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; PATCH FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to grow-patches
  ifelse fertile? [ if penergy + patch-growth-rate < terminal-growth [ set penergy penergy + patch-growth-rate ]] [ set penergy 0 ]  
end

to set-patch-color
  set pcolor scale-color green penergy (patch-max-energy + 20) -10;
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; PREDATOR FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to check-add-predator
  if random 100 < predation-rate * 100 [
    create-predators 1 [
      set size 3;
      set shape "face sad";
      set color red;
      set xcor random 50 - random 50;
      set ycor random 50 - random 50;
      set predator-age 0;
    ]
  ]
end

to move-predators
  set predator-age predator-age + 1
  rt random-float 20
  lt random-float 20
  fd 1
  ask males-here [ set energy energy - predation-cost ask my-group [ set predation-count predation-count + 1] ]
  ask females-here [ set energy energy - predation-cost ask my-group [ set predation-count predation-count + 1] ]
  if predator-age > predation-duration [ die ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; GRAPHING FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-group-food-graph
  set-current-plot "Group v Food";
  
  foreach [self] of groups [
    let foodValue sum [food-eaten] of turtles with [my-group = ?] / count turtles with [my-group = ?]
    plotxy [group-size] of ? foodValue
    plot-pen-down
    plot-pen-up
  ]
end

to update-group-predation-graph
  set-current-plot "Group v Predation";
  
  foreach [self] of groups [
    if [predation-count] of ? > 0 [
      plotxy [group-size] of ? [predation-count] of ?
      plot-pen-down
      plot-pen-up
    ]
  ]
end

to update-competition-food-graph
  set-current-plot "Female Food Competition";

  foreach [self] of females [
    plotxy [fighting-ability] of ? [food-eaten] of ?
    plot-pen-down
    plot-pen-up
  ]
end

to update-competition-mates-graph
  set-current-plot "Male Mate Competition";
  
  foreach [self] of males [
    plotxy [fighting-ability] of ? [mate-number] of ?
    plot-pen-down
    plot-pen-up
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
526
56
990
541
50
50
4.5
1
14
1
1
1
0
1
1
1
-50
50
-50
50
1
1
1
ticks
30.0

SLIDER
9
86
167
119
initial-number-males
initial-number-males
0
100
1
1
1
NIL
HORIZONTAL

SLIDER
9
128
167
161
initial-number-females
initial-number-females
0
100
1
1
1
NIL
HORIZONTAL

BUTTON
695
13
764
46
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
777
13
844
46
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
1344
15
1603
215
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
"males" 1.0 0 -13791810 true "" "plot count males"
"females" 1.0 0 -5825686 true "" "plot count females"

MONITOR
1215
89
1334
134
# Groups
count groups
3
1
11

MONITOR
1215
141
1335
186
# Primates
count turtles with [breed = females or breed = males]
3
1
11

TEXTBOX
285
22
425
41
Primate Settings
14
0.0
0

TEXTBOX
34
175
186
193
Patch Settings
14
0.0
0

SLIDER
12
278
160
311
patch-growth-rate
patch-growth-rate
0
10
5.04
.01
1
NIL
HORIZONTAL

SLIDER
12
198
159
231
patch-abundance
patch-abundance
0
1
0.5
.01
1
NIL
HORIZONTAL

SLIDER
12
237
159
270
patch-patchiness
patch-patchiness
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
12
318
161
351
patch-max-energy
patch-max-energy
0
100
50
1
1
NIL
HORIZONTAL

INPUTBOX
358
54
509
114
perception-range
2
1
0
Number

SLIDER
10
44
166
77
initial-group-count
initial-group-count
0
50
50
1
1
NIL
HORIZONTAL

SLIDER
184
109
339
142
birth-cost
birth-cost
0
1000
240
10
1
NIL
HORIZONTAL

SWITCH
361
297
510
330
female-transfer?
female-transfer?
1
1
-1000

SWITCH
360
337
509
370
male-transfer?
male-transfer?
0
1
-1000

SLIDER
183
68
340
101
max-energy
max-energy
0
1000
660
10
1
NIL
HORIZONTAL

TEXTBOX
36
20
186
38
Group Settings
14
0.0
1

SLIDER
184
149
340
182
food-eaten-per-step
food-eaten-per-step
0
50
32
1
1
NIL
HORIZONTAL

INPUTBOX
359
139
509
199
age-at-maturity
25
1
0
Number

INPUTBOX
359
206
509
266
life-expectancy
400
1
0
Number

SLIDER
184
192
342
225
energy-cost-per-step
energy-cost-per-step
0
100
6
1
1
NIL
HORIZONTAL

SLIDER
184
233
341
266
aggression-cost
aggression-cost
0
100
18
1
1
NIL
HORIZONTAL

PLOT
1011
223
1313
420
Evolution of Tolerance
Time
Tolerance Level
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Intragroup" 1.0 0 -955883 true "" "plot mean [intragroup-tolerance] of turtles with [breed = females or breed = males]"
"Intergroup" 1.0 0 -15040220 true "" "plot mean [intergroup-tolerance] of turtles with [breed = females or breed = males]"
"Female-Female" 1.0 0 -5825686 true "" "plot mean [f-female-tolerance] of females"
"Female-Male" 1.0 0 -10141563 true "" "plot mean [f-male-tolerance] of females"
"Male-Female" 1.0 0 -14985354 true "" "plot mean [m-female-tolerance] of males"
"Male-Male" 1.0 0 -2674135 true "" "plot mean [m-male-tolerance] of males"

SLIDER
182
301
340
334
ave-fighting-ability
ave-fighting-ability
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
181
342
340
375
ave-intragroup-tolerance
ave-intragroup-tolerance
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
181
384
340
417
ave-intergroup-tolerance
ave-intergroup-tolerance
0
1
0.5
.1
1
NIL
HORIZONTAL

MONITOR
1214
37
1333
82
Average Group Size
count turtles with [breed = females or breed = males] / count groups
1
1
11

PLOT
1011
14
1205
212
Mating System
With # Female Mates
# of Males
0.0
10.0
0.0
40.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [mate-number] of males"

TEXTBOX
184
46
334
64
Energy Costs & Gains
11
0.0
1

TEXTBOX
361
120
497
138
Life History
11
0.0
1

TEXTBOX
184
282
334
300
Evolving Traits
11
0.0
1

TEXTBOX
363
277
513
295
Dispersal
11
0.0
1

PLOT
1487
432
1721
610
Group Size Histogram
Group Size
# Groups
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 3.0 1 -16777216 true "" "histogram [group-size] of groups"

SLIDER
180
465
341
498
female-male-tolerance
female-male-tolerance
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
180
425
340
458
female-female-tolerance
female-female-tolerance
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
179
546
342
579
male-female-tolerance
male-female-tolerance
0
1
0.9
.1
1
NIL
HORIZONTAL

SLIDER
180
505
341
538
male-male-tolerance
male-male-tolerance
0
1
0.3
.1
1
NIL
HORIZONTAL

SLIDER
359
403
508
436
home-weightedness
home-weightedness
0
10
4
1
1
NIL
HORIZONTAL

SLIDER
359
443
507
476
food-weightedness
food-weightedness
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
359
483
508
516
conspecific-weightedness
conspecific-weightedness
0
10
6
1
1
NIL
HORIZONTAL

SLIDER
359
524
507
557
mate-weightedness
mate-weightedness
0
10
6
1
1
NIL
HORIZONTAL

TEXTBOX
361
382
511
400
Weighted Strategies
11
0.0
1

TEXTBOX
23
362
173
380
Predator Settings
14
0.0
1

SLIDER
13
427
164
460
predation-rate
predation-rate
0
1
0
.001
1
NIL
HORIZONTAL

SLIDER
13
468
164
501
predation-duration
predation-duration
0
300
0
10
1
NIL
HORIZONTAL

SLIDER
12
510
165
543
predation-cost
predation-cost
0
100
0
1
1
NIL
HORIZONTAL

SLIDER
358
564
508
597
predation-weightedness
predation-weightedness
0
10
7
1
1
NIL
HORIZONTAL

SWITCH
14
386
165
419
play-alarm-calls?
play-alarm-calls?
1
1
-1000

PLOT
1326
223
1603
420
Evolution of Fighting Ability
Time
Fighting Ability
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"primates" 1.0 0 -16777216 true "" "plot mean [fighting-ability] of turtles with [breed = males or breed = females]"

PLOT
1010
431
1230
609
Relatedness Within Groups
Time
Relatedness
0.0
10.0
0.0
0.25
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot within-group-relatedness"

PLOT
1247
432
1473
610
Relatedness Between Groups
Time
Relatedness
0.0
10.0
0.0
0.25
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot between-group-relatedness"

PLOT
1613
226
1899
420
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
1910
228
2204
420
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
1909
15
2205
215
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
1612
15
1899
215
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
NetLogo 5.0.4
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
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
