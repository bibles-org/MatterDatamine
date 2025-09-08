require ecs
require game.events.events
require game.es.client.postfx_fade_common
require DagorMath
require DagorShaders


let
  screen_noize_factorVarId = get_shader_variable_id("screen_noize_factor", true)


[es(tag=render, on_appear, track=postfx_noize_controller__factor)]
def postfx_noize_controller_track_progress(evt : Event;
                                           postfx_noize_controller__factor : float)
  DagorShaders::set_real(screen_noize_factorVarId, postfx_noize_controller__factor)