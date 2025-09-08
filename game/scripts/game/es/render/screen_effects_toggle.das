require ecs


[es(tag=render, track=camera__active, REQUIRE=disableScreenEffects)]
def screen_effects_toggle(evt : Event; camera__active : bool)
  query() <| $ [es] (var screen_effect_renderer__enable, screen_effect__is_active : bool&)
    screen_effect_renderer__enable = !camera__active
    screen_effect__is_active = screen_effect_renderer__enable


[es(tag=render, on_appear, REQUIRE=disableScreenEffects)]
def disable_screen_effects_on_tag_appear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var screen_effect_renderer__enable, screen_effect__is_active : bool&)
      screen_effect_renderer__enable = false
      screen_effect__is_active = false


[es(tag=render, on_disappear, REQUIRE=disableScreenEffects)]
def enable_screen_effects_on_tag_disappear(evt : Event; camera__active : bool)
  if camera__active
    query() <| $ [es] (var screen_effect_renderer__enable, screen_effect__is_active : bool&)
      screen_effect_renderer__enable = true
      screen_effect__is_active = true