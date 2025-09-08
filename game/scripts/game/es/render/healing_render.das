require ecs
require math.base
require DagorMath


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def healing_effect_clear(evt : Event)
  find_query() <| $ [es] (var healing_screen_effect__value : float&)
    healing_screen_effect__value = 0.0
    return true


[es(tag=render, before=screen_effect_render_es)]
def healing_effect_update(info : UpdateStageInfoAct;
                          healing_screen_effect__dampViscosity, healing_screen_effect__speedViscosity : float;
                          healing_screen_effect__effectRange : float2;
                          var healing_screen_effect__wishValue : float&;
                          var healing_screen_effect__value, screen_effect__borderOffset, screen_effect__weight : float&)
  healing_screen_effect__value = approach(healing_screen_effect__value, healing_screen_effect__wishValue, info.dt, healing_screen_effect__dampViscosity)
  healing_screen_effect__wishValue = approach(healing_screen_effect__wishValue, 0.0, info.dt, healing_screen_effect__speedViscosity)
  screen_effect__borderOffset = cvt(healing_screen_effect__value, 0.0, 1.0, healing_screen_effect__effectRange.x, healing_screen_effect__effectRange.y)
  screen_effect__weight = cvt(healing_screen_effect__wishValue, 0.0, 1.0, 0.0, 1.0)


[es(tag=render, on_appear)]
def make_healing_screen_effect_on_instant_heal(evt : Event;
                                               game_effect__attachedTo : EntityId;
                                               healing_effect__effectVisualStrength : float)
  if game_effect__attachedTo |> has("watchedByPlr")
    find_query() <| $ [es] (var healing_screen_effect__wishValue : float&)
      healing_screen_effect__wishValue = healing_effect__effectVisualStrength
      return true
