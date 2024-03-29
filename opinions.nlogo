globals
[
  sum-change                           ;; sum of changed opinions
]

turtles-own
[
  opinion
  stubborn?
]


;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup Procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  make-turtles
  if network-type = "random-graph" [ random-graph ]
  if network-type = "spatial-graph" [ spatial-graph ]
  if network-type = "small-world-graph" [ small-world-graph ]
  if network-type = "prefferential-graph" [ prefferential-graph ]
  color-turtles
  make-stubborn
  reset-ticks
end

to make-turtles
  set-default-shape turtles "circle"
  create-turtles people [ set color white ]
end


;;; Coloring ;;;

to color-turtles
  ask turtles with [ color = white ] [

    ;; uniform distribution
    if opinion-distribution = "uniform" [ set opinion random-float 1 ]

    ;; normal distribution
    if opinion-distribution = "middle" [
      set opinion random-normal 0.5 0.2
    ]

    ;; inversed normal distribution
    if opinion-distribution = "extremes" [
      set opinion random-normal 0.5 0.2
      ifelse opinion = 0.5
      [ set opinion random 2 ]
      [ ifelse opinion < 0.5 [ set opinion opinion + 0.5 ] [ set opinion opinion - 0.5 ] ]
    ]

    set-color
    set stubborn? false
  ]
end

to set-color
  if opinion > 1 [ set opinion 1 ]
  if opinion < 0 [ set opinion 0 ]
  ifelse opinion < 0.5
  [ set color (list 255 (255 * opinion * 2) 0) ]
  [ set color (list (255 - 255 * (opinion - 0.5) * 2) 255 0) ]
end

to make-stubborn
  ask turtles [
    if random 100 < stubborn-prob [
      set stubborn? true
      set size 2
    ]
  ]
end


;;; Graphs ;;;

to random-graph
  layout-circle (sort turtles) max-pycor
  let num-edges people * average-node-degree / 2
  let i 0
  while [i < num-edges ]
  [
    ask one-of turtles
    [
      let choice one-of other turtles with [not link-neighbor? myself]
      if choice != nobody [ create-link-with choice ]
    ]
    set i i + 1
  ]
end

to spatial-graph
  ask turtles [ setxy (random-xcor * 0.95) (random-ycor * 0.95) ]
  let num-edges people * average-node-degree / 2
  while [count links < num-edges ]
  [
    ask one-of turtles
    [
      let choice (min-one-of (other turtles with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  ;; make graph nice
  repeat 10
  [
    layout-spring turtles links 0.3 (world-width / (sqrt people)) 1
  ]
end

to small-world-graph
  lattice-graph

  ask links [
    ;; whether to rewire it or not?
    if random 100 < rewiring-probability
    [
      let node1 end1
      ;; if node1 is not connected to everybody
      if [ count link-neighbors ] of end1 < (people - 1)
      [
        ;; find a node distinct from node1 and not already a neighbor of node1 and rewire
        let node2 one-of turtles with [ (self != node1) and (not link-neighbor? node1) ]
        ask node1 [ create-link-with node2 [ set color cyan ] ]
        die
      ]
    ]
  ]
end

to lattice-graph
  layout-circle (sort turtles) max-pycor
  let i 0
  let j 1
  while [i < count turtles]
  [
    set j 1
    while [j <= average-node-degree / 2]
    [
      ask turtle i [ create-link-with turtle ((i + j) mod count turtles) ]
      set j j + 1
    ]
    set i i + 1
  ]
end

to prefferential-graph
  clear-all
  create-turtles 1 [set color white]
  create-turtles 1 [
    set color white
    create-link-with turtle 0
  ]
  while [count turtles < people] [
    let old-node [one-of both-ends] of one-of links
    create-turtles 1
    [
      set color white
      if old-node != nobody
      [ create-link-with old-node
        ;; position the new node near its partner
        move-to old-node
        fd 8
      ]
    ]
    ;; make graph nice
    repeat 3 [
      let factor sqrt count turtles
      layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    ]
    let x-offset max [xcor] of turtles + min [xcor] of turtles
    let y-offset max [ycor] of turtles + min [ycor] of turtles
    ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;
;;; Opinion forming ;;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  set sum-change 0
  if changing-opinion-strategy = "one neighbor" [ opinion-strategy-1 ]
  if changing-opinion-strategy = "all neighbors" [ opinion-strategy-2 ]
  tick
end

;; asking one neighbor at a time and leaning towards his opinion
to opinion-strategy-1
  ask turtles with [ stubborn? = false ]
  [
    let starting-opinion opinion

    let choice one-of other turtles with [link-neighbor? myself]
    let choice-opinion 0
    if choice != nobody and random 100 < changing-opinion-prob
    [
      ask choice [ set choice-opinion opinion ]
      let difference choice-opinion - opinion
      set opinion opinion + (difference * changing-opinion-strength)
      set-color
    ]

    set sum-change sum-change + abs (starting-opinion - opinion)
  ]
end

;; asking all neighbors and leaning towards average opinion
to opinion-strategy-2
  let sum-opinion 0
  ask turtles with [ stubborn? = false ]
  [
    let starting-opinion opinion

    if random 100 < changing-opinion-prob [
      ask link-neighbors [ set sum-opinion sum-opinion + opinion ]
      let difference 0
      if count link-neighbors != 0 [ set difference sum-opinion / count link-neighbors - opinion]
      set opinion opinion + (difference * changing-opinion-strength)
      set-color
      set sum-opinion 0
    ]

    set sum-change sum-change + abs (starting-opinion - opinion)
  ]
end

to-report min-opinion
  let i 1
  ask turtles [ if opinion < i [set i opinion] ]
  report i
end

to-report max-opinion
  let i 0
  ask turtles [ if opinion > i [set i opinion] ]
  report i
end

to-report avg-opinion
  let i 0
  ask turtles [ set i i + opinion ]
  report i / people
end

to-report zero-pad [n places]
  let result (word precision n places)
  if not is-number? position "." result [
    set result (word result ".")
  ]
  let padding-amount position "." result - length result + places + 1
  let padding reduce word fput "" n-values padding-amount [0]
  report (word result padding)
end

to-report count-turtles-in [lower-interval upper-interval]
  report ( count turtles with [ opinion >= lower-interval and opinion < upper-interval ] )
end

to-report max-opinion-from [percent]
  let i (people - 1) * percent / 100
  report item i sort [ opinion ] of turtles
end
@#$#@#$#@
GRAPHICS-WINDOW
470
10
1253
645
27
21
14.061
1
10
1
1
1
0
0
0
1
-27
27
-21
21
1
1
1
ticks
30.0

SLIDER
21
12
193
45
people
people
0
300
200
1
1
NIL
HORIZONTAL

BUTTON
252
174
325
207
NIL
setup\n
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
247
61
460
94
average-node-degree
average-node-degree
0
people - 1
6
1
1
NIL
HORIZONTAL

CHOOSER
247
10
432
55
network-type
network-type
"random-graph" "spatial-graph" "small-world-graph" "prefferential-graph"
3

BUTTON
349
174
419
207
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

CHOOSER
22
124
192
169
changing-opinion-strategy
changing-opinion-strategy
"one neighbor" "all neighbors"
0

SLIDER
247
103
431
136
rewiring-probability
rewiring-probability
0
100
30
1
1
NIL
HORIZONTAL

PLOT
22
452
222
602
extremes
Time
Number
0.0
200.0
0.0
1.0
true
true
"" ""
PENS
"Min" 1.0 0 -2674135 true "" "plot min-opinion"
"Max" 1.0 0 -13840069 true "" "plot max-opinion"
"Avg" 1.0 0 -1184463 true "" "plot avg-opinion"

SLIDER
21
172
193
205
changing-opinion-strength
changing-opinion-strength
0
1
0.3
0.1
1
NIL
HORIZONTAL

CHOOSER
23
74
189
119
opinion-distribution
opinion-distribution
"uniform" "middle" "extremes"
2

PLOT
21
296
221
446
distribution-dynamics
Time
Number
0.0
200.0
0.0
200.0
true
true
"set-plot-y-range 0 people" ""
PENS
"<0; 0.2)" 1.0 0 -2674135 true "" "plot count-turtles-in 0 0.2"
"<0.2; 0.4)" 1.0 0 -955883 true "" "plot count-turtles-in 0.2 0.4"
"<0.4; 0.6)" 1.0 0 -1184463 true "" "plot count-turtles-in 0.4 0.6"
"<0.6; 0.8)" 1.0 0 -6565750 true "" "plot count-turtles-in 0.6 0.8"
"<0.8; 1>" 1.0 0 -13840069 true "" "plot count-turtles-in 0.8 1.4"

PLOT
246
451
446
601
changes
Time
Change
0.0
200.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot sum-change"

MONITOR
272
607
427
652
changes
zero-pad sum-change 8
17
1
11

SLIDER
246
255
446
288
stubborn-prob
stubborn-prob
0
100
0
1
1
NIL
HORIZONTAL

PLOT
246
296
446
446
distribution-current
NIL
NIL
0.0
1.0
0.0
10.0
true
false
"set-plot-pen-mode 1\nset-plot-y-range 0 count turtles\nset-histogram-num-bars 7" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [opinion] of turtles"

SLIDER
21
254
223
287
changing-opinion-prob
changing-opinion-prob
0
100
100
1
1
NIL
HORIZONTAL

PLOT
26
620
226
770
max-opinion-from
Time
Number
0.0
200.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -8630108 true "" "plot max-opinion-from 0"
"pen-1" 1.0 0 -13345367 true "" "plot max-opinion-from 10"
"pen-2" 1.0 0 -13791810 true "" "plot max-opinion-from 20"
"pen-3" 1.0 0 -11221820 true "" "plot max-opinion-from 30"
"pen-4" 1.0 0 -14835848 true "" "plot max-opinion-from 40"
"pen-5" 1.0 0 -13840069 true "" "plot max-opinion-from 50"
"pen-6" 1.0 0 -10899396 true "" "plot max-opinion-from 60"
"pen-7" 1.0 0 -1184463 true "" "plot max-opinion-from 70"
"pen-8" 1.0 0 -612749 true "" "plot max-opinion-from 80"
"pen-9" 1.0 0 -955883 true "" "plot max-opinion-from 90"
"pen-10" 1.0 0 -2674135 true "" "plot max-opinion-from 100"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

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
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>avg-opinion</metric>
    <enumeratedValueSet variable="changing-opinion-strategy">
      <value value="&quot;continuous - one neighbor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strength">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;spatial-graph&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-prob">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="opinions">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strategy">
      <value value="&quot;one neighbor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="opinion-distribution">
      <value value="&quot;uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;random-graph&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strength">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stubborn-prob">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-graph_node-degree_opinion-ditrib" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks &gt; 199</exitCondition>
    <metric>sum-change</metric>
    <metric>count turtles with [opinion &lt; 0.2]</metric>
    <metric>count turtles with [opinion &gt;= 0.2 and opinion &lt; 0.4]</metric>
    <metric>count turtles with [opinion &gt;= 0.2 and opinion &lt; 0.4]</metric>
    <metric>count turtles with [opinion &gt;= 0.2 and opinion &lt; 0.4]</metric>
    <metric>count turtles with [opinion &gt;= 0.8]</metric>
    <metric>max-opinion</metric>
    <metric>avg-opinion</metric>
    <metric>min-opinion</metric>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strategy">
      <value value="&quot;one neighbor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="opinion-distribution">
      <value value="&quot;uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;random-graph&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strength">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stubborn-prob">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>histogram [opinion] of turtles</metric>
    <enumeratedValueSet variable="opinion-distribution">
      <value value="&quot;uniform&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strategy">
      <value value="&quot;all neighbors&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stubborn-prob">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-prob">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;spatial-graph&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="changing-opinion-strength">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="30"/>
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
0
@#$#@#$#@
