require ecs
require DagorShaders


let
  vignette_strengthVarId = get_shader_variable_id("vignette_strength", true)
  second_vignette_strengthVarId = get_shader_variable_id("second_vignette_strength", true)
  second_vignette_colorVarId = get_shader_variable_id("second_vignette_color", true)


[es(tag=render, on_appear, track=(postfx_vignette_controller__vignetteFactor,
  postfx_vignette_controller__secondVignetteFactor, postfx_vignette_controller__secondVignetteColor))]
def postfx_vignette_controller_track_progress(evt : Event;
                                              postfx_vignette_controller__vignetteFactor : float;
                                              postfx_vignette_controller__secondVignetteFactor : float;
                                              postfx_vignette_controller__secondVignetteColor : float4)
  DagorShaders::set_real(vignette_strengthVarId, postfx_vignette_controller__vignetteFactor)
  DagorShaders::set_real(second_vignette_strengthVarId, postfx_vignette_controller__secondVignetteFactor)
  DagorShaders::set_color4(second_vignette_colorVarId, postfx_vignette_controller__secondVignetteColor)