require ecs

// Blood on screen
[es(tag=render, track=camera__active)]
def blood_on_screen_toggle(evt : Event; camera__active : bool; disableScreenEffects : Tag const?)
  if camera__active
    query() <| $ [es] (var blood_on_screen__enable : bool&)
      blood_on_screen__enable = disableScreenEffects == null


[es(tag=render, on_appear, REQUIRE=disableScreenEffects)]
def blood_on_screen_appear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var blood_on_screen__enable : bool&)
      blood_on_screen__enable = false


[es(tag=render, on_disappear, REQUIRE=disableScreenEffects)]
def blood_on_screen_disappear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var blood_on_screen__enable : bool&)
      blood_on_screen__enable = true

// zone effect
[es(tag=render, track=camera__active)]
def zone_effect_on_screen_toggle(evt : Event; camera__active : bool; disableScreenEffects : Tag const?)
  if camera__active
    query() <| $ [es] (var screen_bleed__enabled : bool&)
      screen_bleed__enabled = disableScreenEffects == null


[es(tag=render, on_appear, REQUIRE=disableScreenEffects)]
def zone_effect_on_screen_appear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var screen_bleed__enabled : bool&)
      screen_bleed__enabled = false


[es(tag=render, on_disappear, REQUIRE=disableScreenEffects)]
def zone_effect_on_screen_disappear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var screen_bleed__enabled : bool&)
      screen_bleed__enabled = true

