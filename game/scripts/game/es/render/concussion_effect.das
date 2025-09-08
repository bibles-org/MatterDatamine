require ecs
require app
require game.utils.hero
require DagorShaders
require danetlibs.renderer.includes.render_events
require DagorMath
require game.es.render.screen_effects_common


let
  concsussion_effect_time_startVarId = get_shader_variable_id("concussion_effect_time_start", true)
  concussion_effect_durationVarId = get_shader_variable_id("concussion_effect_duration", true)
  concussion_shake_intensityVarId = get_shader_variable_id("concussion_shake_intensity", true)

  BASE_INTENSITY = 0.02f


def enable_concussion_screen_effect(duration : float)
  DagorShaders::set_real(concsussion_effect_time_startVarId, get_shader_global_time_phase(0.0, 0.0))
  DagorShaders::set_real(concussion_effect_durationVarId, duration)
  DagorShaders::set_real(concussion_shake_intensityVarId, BASE_INTENSITY)

def disable_concussion_screen_effect()
  DagorShaders::set_real(concsussion_effect_time_startVarId, -1000.0)
  DagorShaders::set_real(concussion_shake_intensityVarId, BASE_INTENSITY)
  DagorShaders::set_real(concussion_effect_durationVarId, 1f)

[es(tag=render, REQUIRE=(watchedByPlr, hasConcussedVision), on_disappear)]
def disable_concussion_vision_on_spectator_disappear(evt : Event)
  disable_concussion_screen_effect()

[es(tag=render, REQUIRE=(hero, hasConcussedVision), on_disappear)]
def disable_concussion_vision_on_destroy(evt : Event)
  disable_concussion_screen_effect()

[es(tag=render, REQUIRE=hero, track=hasConcussedVision, on_appear)]
def track_concussion_vision(evt : Event; eid : EntityId; hasConcussedVision : bool)
  if !hasConcussedVision
    disable_concussion_screen_effect()
    return

  find_query() <| $ [es(REQUIRE=concussionScreenEffect)] (game_effect__attachedTo : EntityId;
                                                          concussion__startedAtTime : float;
                                                          concussion__duration : float)
    if game_effect__attachedTo != eid
      return false
    if is_camera_allow_effect()
      enable_concussion_screen_effect(concussion__duration - (get_sync_time() - concussion__startedAtTime))
    return true

[es(tag=render, REQUIRE=concussionScreenEffect, on_appear, after=concussion_init_timer)]
def concussion_screen_effect_prolong(evt : Event;
                                     game_effect__attachedTo : EntityId;
                                     concussion__startedAtTime : float;
                                     concussion__duration : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero, REQUIRE_NOT=deadEntity)] ()
    if is_camera_allow_effect()
      enable_concussion_screen_effect(concussion__duration - (get_sync_time() - concussion__startedAtTime))
    else
      disable_concussion_screen_effect()


[es(tag=render, no_order, REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def force_concussion_screen_effect(info : UpdateStageInfoAct;
                                   eid : EntityId)
  if !is_camera_allow_effect()
    disable_concussion_screen_effect()
    return
  var bestDuration, bestStartTime, bestIntensity = 0f
  query() <| $ [es] (game_effect__attachedTo : EntityId;
                     force_concussion_screen_effect__intensity,
                     force_concussion_screen_effect__duration,
                     force_concussion_screen_effect__startedAtTime : float)
    if game_effect__attachedTo != eid
      return
    if bestIntensity <= force_concussion_screen_effect__intensity
      bestIntensity = force_concussion_screen_effect__intensity
      bestDuration  = force_concussion_screen_effect__duration
      bestStartTime = force_concussion_screen_effect__startedAtTime
  if bestIntensity <= 0f
    return
  DagorShaders::set_real(concussion_shake_intensityVarId, bestIntensity)
  DagorShaders::set_real(concussion_effect_durationVarId, bestDuration)
  DagorShaders::set_real(concsussion_effect_time_startVarId, bestStartTime)


[es(tag=render, on_appear)]
def force_concussion_screen_effect_init_start_time(evt : Event;
                                                   var force_concussion_screen_effect__startedAtTime : float&)
  force_concussion_screen_effect__startedAtTime = get_shader_global_time_phase(0.0, 0.0)


[es(tag=render, on_disappear, REQUIRE=force_concussion_screen_effect__intensity)]
def force_concussion_screen_effect_disable_on_disappear(evt : Event;
                                                        game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "watchedByPlr")
    disable_concussion_screen_effect()