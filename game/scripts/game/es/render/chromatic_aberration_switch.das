require ecs
require DagorMath
require game.utils.hero
require DagorShaders
require PriorityShadervar

let
  chromatic_aberration_paramsVarId = get_shader_variable_id("chromatic_aberration_params", true)
  CHROMATIC_ABERRATION_PRIORITY = 3


[es(tag=render, on_appear)]
def chromatic_aberration_affect_set_es(evt : Event;  game_effect__attachedTo : EntityId;
                                       game_effect__chromaticAberrationParams : float4)
  if has(game_effect__attachedTo, "watchedByPlr")
    PriorityShadervar::set_color4(chromatic_aberration_paramsVarId, CHROMATIC_ABERRATION_PRIORITY, game_effect__chromaticAberrationParams)


[es(tag=render, on_disappear, REQUIRE=game_effect__chromaticAberrationParams)]
def chromatic_aberration_affect_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "watchedByPlr")
    PriorityShadervar::clear(chromatic_aberration_paramsVarId, CHROMATIC_ABERRATION_PRIORITY)


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def actor_appear_update_chromatic_aberration_affect(evt : Event;
                                                    eid : EntityId)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          game_effect__chromaticAberrationParams : float4)
    if game_effect__attachedTo == eid
      PriorityShadervar::set_color4(chromatic_aberration_paramsVarId, CHROMATIC_ABERRATION_PRIORITY, game_effect__chromaticAberrationParams)
      return true
    return false


[es(tag=render, on_appear, track=(chromatic_aberration__value, camera__active))]
def chromatic_aberration_value_set_es(evt : Event; chromatic_aberration__value : float4; camera__active : bool)
  if !camera__active
    return
  PriorityShadervar::set_color4(chromatic_aberration_paramsVarId, CHROMATIC_ABERRATION_PRIORITY, chromatic_aberration__value)


[es(tag=render, on_appear, track=camera__active, REQUIRE_NOT=chromatic_aberration__value)]
def chromatic_aberration_disable_on_camera_switch_es(evt : Event; camera__active : bool)
  if !camera__active
    return
  PriorityShadervar::clear(chromatic_aberration_paramsVarId, CHROMATIC_ABERRATION_PRIORITY)