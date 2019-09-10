;; load extension for gis
extensions [ gis ]

globals [
  max-sheep                  ; don't let sheep population grow too large
]
; Sheep and wolves are both breeds of turtle.
breed [ sheep a-sheep ]  ; sheep is its own plural, so we use "a-sheep" as the singular.
breed [ wolves wolf ]
breed [ humans human ]         ;;; Adding humans as a breed
turtles-own [ energy ]         ;;; All entities have energy
wolves-own [ domesticated? ]   ;;; When humans encounter wolves, they sometimes domesticate them
patches-own [
  value ; value of raster
  land? ; add land
  wall? ; add wall
  house
  house-color
  countdown ]

to setup
  clear-all
  ;; call on setup-world to set up world
  setup-world
  ifelse netlogo-web? [set max-sheep 10000] [set max-sheep 30000]

  let land-patches patches with [ land? = true ]

  ; The grass's state of growth and growing logic need to be set up

  ask land-patches [
    set pcolor one-of [ green brown ]
    ifelse pcolor = green
      [ set countdown grass-regrowth-time ]
    [ set countdown random grass-regrowth-time ] ; initialize grass regrowth clocks randomly for brown patches
  ]

  ; Create sheep, wolves, and humans if necessary (in a separate procedure)

  ask n-of initial-number-sheep land-patches
  [
    ; each land patch sprouts 1 sheep
    sprout-sheep 1
    [
      set shape  "sheep"
      set color white
      set size 1.5  ; easier to see
      set label-color blue - 2
      set energy random (2 * sheep-gain-from-food)
      ;; setxy random-xcor random-ycor
    ]
  ]

  ask n-of initial-number-wolves land-patches
  [
    sprout-wolves 1
    [
      set shape "wolf"
      set color black
      set size 2  ; easier to see
      set energy random (2 * wolf-gain-from-food)
      ;; setxy random-xcor random-ycor
      set domesticated? false                     ;;; All wolves start wild
    ]
  ]

  ;;; Check model switch. If applicable, create humans
  if model-version = "sheep-wolves-humans-grass"
  [ add-humans ]

  display-labels
  reset-ticks
end

to go
  ; stop the simulation if no wolves, humans, or sheep
  if not any? turtles [ stop ]
  ; stop the model if there are no wolves and the number of sheep gets very large
  if not any? wolves and count sheep > max-sheep [ user-message "The sheep have inherited the earth" stop ]

  if model-version = "sheep-wolves-humans-grass"
  ;;; ADDED THIS
  [ if not any? humans [ stop ]]

  ask sheep [
    move
    ; sheep eat grass, grass grows, and it costs sheep energy to move
    set energy energy - 1  ; deduct energy for sheep
    eat-grass
    death ; sheep die from starvation
    reproduce sheep-reproduce  ; sheep reproduce at random rate governed by slider
  ]

  ask wolves [
    move
    set energy energy - 1  ; wolves lose energy as they move
    ifelse not domesticated?
    [ eat-sheep ] ; wolves eat a sheep on their patch  ;;; Only if they are still wild
    [ if energy < 20
      [ eat-sheep ]]                                   ;;; ... or they are starving
    death ; wolves die if out of energy
    reproduce wolf-reproduce  ; wolves reproduce at random rate governed by slider
  ]

  if model-version = "sheep-wolves-humans-grass"
  [ ;;; ADDED human actions, almost all the same as sheep and wolves
    ask humans [
      move
      set energy energy - 1       ;;; Humans also lose energy as they move
      humans-eat                  ;;; Humans eat some of the sheep that are on their patch or the grass if available
      domesticate-wolves          ;;; Humans domesticate some of the wolves that are on their patch
      humans-feed-animals         ;;; Humans have to feed the animals it keeps
      death                       ;;; Humans die when they run out of energy
      reproduce human-reproduce   ;;; Humans can reproduce when they have enough energy
  ]]

  ask patches [ grow-grass ]
  ; set grass count patches with [pcolor = green]

  tick
  display-labels
end

to move  ; turtle procedure
  rt random 50
  lt random 50
  fd 1
end

to eat-grass  ; sheep procedure
  ; sheep eat grass, turn the patch brown
  if pcolor = green [
    set pcolor brown
    set energy energy + sheep-gain-from-food  ; sheep gain energy by eating
  ]
end

to reproduce [ reproduce-rate ]  ; sheep procedure
  if random-float 100 < reproduce-rate [  ; throw "dice" to see if you will reproduce
    set energy (energy / 2)                ; divide energy between parent and offspring
    hatch 1 [ rt random-float 360 fd 1 ]   ; hatch an offspring and move it forward 1 step
  ]
end

to eat-sheep  ; wolf procedure
  let prey one-of sheep-here                    ; grab a random sheep
  if prey != nobody  [                          ; did we get one?  if so,
    ask prey [ die ]                            ; kill it, and...
    set energy energy + wolf-gain-from-food     ; get energy from eating
  ]
end

to death  ; turtle procedure (i.e. both wolf nd sheep procedure)
  ; when energy dips below zero, die
  if energy < 0 [ die ]
end

to grow-grass  ; patch procedure
  ; countdown on brown patches: if reach 0, grow some grass
  if pcolor = brown [
    ifelse countdown <= 0
      [ set pcolor green
        set countdown grass-regrowth-time ]
      [ set countdown countdown - 1 ]
  ]
end

to-report grass
  report patches with [ pcolor = green ]
end

to display-labels
  ask turtles [ set label "" ]
  if show-energy? [
    ask wolves [ set label round energy ]
    if model-version = "sheep-wolves-grass" [ ask sheep [ set label round energy ] ]
  ]
end

;;; OBSERVER PROCEDURE ;;;

to add-humans

  let land-patches patches with [ land? = true ]

  ;;; Create as many humans as the slider
  ask n-of initial-number-humans patches          ;;; This way of creating humans prevents having to give them coordinates
  [ sprout-humans 1                               ;;; Create humans, then initialize their variables
    [ set shape "person"
      set size 5
      set color blue
      set energy random (2 * wolf-gain-from-food)]
    ]

end

;;; HUMAN PROCEDURE ;;;

to domesticate-wolves

  let friend one-of wolves-here                    ; grab a random wolf
  if friend != nobody                              ; did we get one?  if so,

    ;;; 50% of the time, the human will domesticate the wolf
    [ ifelse random 100 < 50                                             ;;; Random 100 will give values between 0-99 inclusively
      [ ask friend
        [ set domesticated? true set color 2 ]]                          ;;; Transform the wolf into a dog

      ;;; the rest of the time, the wolf will kill the human
      [ ask friend
        [ set energy energy + ( wolf-gain-from-food * 1.5 )]             ;;; The wolf gets some food out of the human (arbitraryly 1.5 * the meat of sheep)
        die ]]                                                           ;;; and the human dies

end

;;; HUMAN PROCEDURE ;;;

to humans-eat

  ;;; this is a modified version of the sheep-eat
  ifelse random 100 < rate-sheep-eating              ;;; Humans will eat sheep only a certain % of time, based on a slider.
  [ let prey one-of sheep-here                       ; grab a random sheep
    if prey != nobody
    [                                                ; did we get one?  if so,
      ask prey [ die ]                               ; kill it, and...
      set energy energy + wolf-gain-from-food        ; get energy from eating ;;; For simplicity, the same energy as wolves
  ]]

  ;;; If not eating sheep, still getting some pretty good nutrients from cultivated grass/wheat?
  [ if pcolor = green
    [ set pcolor brown
      set energy energy + (wolf-gain-from-food / 4)]]  ;;; But still not as good as eating a sheep

end

;;; HUMAN PROCEDURE ;;;

to humans-feed-animals

  ;;; Identifies the dogs and feed them by sharing a sheep if there is one around
  let dogs wolves-here with [ domesticated? = true ]     ;;; Temporary variable to identify dogs on the same patch

  if any? dogs                                           ;;; Same as saying if dogs != nobody
    [ ask one-of dogs
      [ eat-sheep set energy energy - 20 ]               ;;; The human tells its dog to hunt for a sheep, but it then takes some of the nutrients for itself
      set energy energy + 20 ]

end

;;; import raster dataset
to setup-world

  let basemap gis:load-dataset "Land_raster.asc"
  let world-wd gis:width-of basemap
  let world-ht gis:height-of basemap
  resize-world 0 world-wd 0 world-ht
  gis:set-world-envelope ( gis:envelope-of basemap)
  gis:apply-raster basemap value

  ;; distingusih between land and sea
  ask patches
  [ ifelse value > 0
    [ set land? true ]
    [ set land? false ]
  ]

  ask patches
  [ ifelse land?
    [ set pcolor green ]
    [ set pcolor blue ]
  ]

end


; Copyright 1997 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
355
10
519
385
-1
-1
3.0
1
14
1
1
1
0
0
0
1
0
51
0
121
1
1
1
ticks
30.0

SLIDER
5
60
179
93
initial-number-sheep
initial-number-sheep
0
250
104.0
1
1
NIL
HORIZONTAL

SLIDER
5
196
179
229
sheep-gain-from-food
sheep-gain-from-food
0.0
50.0
10.0
1.0
1
NIL
HORIZONTAL

SLIDER
5
231
179
264
sheep-reproduce
sheep-reproduce
1.0
20.0
2.0
1.0
1
%
HORIZONTAL

SLIDER
185
60
350
93
initial-number-wolves
initial-number-wolves
0
250
55.0
1
1
NIL
HORIZONTAL

SLIDER
183
195
348
228
wolf-gain-from-food
wolf-gain-from-food
0.0
100.0
40.0
1.0
1
NIL
HORIZONTAL

SLIDER
183
231
348
264
wolf-reproduce
wolf-reproduce
0.0
20.0
2.0
1.0
1
%
HORIZONTAL

SLIDER
40
100
252
133
grass-regrowth-time
grass-regrowth-time
0
100
52.0
1
1
NIL
HORIZONTAL

BUTTON
40
140
109
173
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
115
140
190
173
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
10
360
350
530
populations
time
pop.
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"sheep" 1.0 0 -612749 true "" "plot count sheep"
"wolves" 1.0 0 -16449023 true "" "plot count wolves"
"grass / 4" 1.0 0 -10899396 true "" "if model-version = \"sheep-wolves-grass\" [ plot count grass / 4 ]"
"humans" 1.0 0 -7500403 true "" "plot count humans"

MONITOR
41
308
111
353
sheep
count sheep
3
1
11

MONITOR
115
308
185
353
wolves
count wolves
3
1
11

MONITOR
191
308
256
353
grass
count grass / 4
0
1
11

TEXTBOX
20
178
160
196
Sheep settings
11
0.0
0

TEXTBOX
198
176
311
194
Wolf settings
11
0.0
0

SWITCH
105
270
241
303
show-energy?
show-energy?
1
1
-1000

CHOOSER
5
10
350
55
model-version
model-version
"sheep-wolves-grass" "sheep-wolves-humans-grass"
1

SLIDER
880
40
1075
73
initial-number-humans
initial-number-humans
0
100
30.0
10
1
NIL
HORIZONTAL

SLIDER
880
75
1075
108
human-reproduce
human-reproduce
0
10
2.0
1
1
%
HORIZONTAL

SLIDER
880
110
1075
143
rate-sheep-eating
rate-sheep-eating
0
50
20.0
10
1
%
HORIZONTAL

TEXTBOX
930
15
1080
33
Human settings
11
0.0
1

MONITOR
265
310
327
355
humans
count humans
17
1
11

@#$#@#$#@
## What is different here?

We added a new breed of humans to this simulation. Humans are taking care of the sheep but sometimes eating them and they domesticate wolves when they encounter them. Wolves do not hunt sheep.

We also simplified it by removing the "only sheep and wolves" scenario. Now, the two possible scenarios are: wolf-sheep-grass and wolf-sheep-grass-humans.

## CREDITS AND REFERENCES

Wilensky, U. & Reisman, K. (1998). Connected Science: Learning Biology through Constructing and Testing Computational Theories -- an Embodied Modeling Approach. International Journal of Complex Systems, M. 234, pp. 1 - 12. (The Wolf-Sheep-Predation model is a slightly extended version of the model described in the paper.)

Wilensky, U. & Reisman, K. (2006). Thinking like a Wolf, a Sheep or a Firefly: Learning Biology through Constructing and Testing Computational Theories -- an Embodied Modeling Approach. Cognition & Instruction, 24(2), pp. 171-209. http://ccl.northwestern.edu/papers/wolfsheep.pdf .

Wilensky, U., & Rand, W. (2015). An introduction to agent-based modeling: Modeling natural, social and engineered complex systems with NetLogo. Cambridge, MA: MIT Press.

Lotka, A. J. (1925). Elements of physical biology. New York: Dover.

Volterra, V. (1926, October 16). Fluctuations in the abundance of a species considered mathematically. Nature, 118, 558–560.

Gause, G. F. (1934). The struggle for existence. Baltimore: Williams & Wilkins.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Wolf Sheep Predation model.  http://ccl.northwestern.edu/netlogo/models/WolfSheepPredation.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2000.

<!-- 1997 2000 -->
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

leader
false
0
Polygon -8630108 true false 105 90 195 90 225 270 75 270
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -1184463 true false 105 30 195 30 195 0 165 15 150 0 135 15 105 0 105 30
Polygon -8630108 true false 105 90 135 135 165 135 195 90 165 90 165 105 135 105 135 90
Polygon -1184463 true false 120 90 135 120 165 120 180 90 165 90 150 105 135 90

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
NetLogo 6.1.0
@#$#@#$#@
set model-version "sheep-wolves-grass"
set show-energy? false
setup
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
1
@#$#@#$#@
