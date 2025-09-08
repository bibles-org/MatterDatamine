require ecs
require game.events.events
require game.es.client.postfx_fade_common
require DagorMath
require DagorShaders


let
  forcefield_aberrationShiftVarId = get_shader_variable_id("forcefield_aberrationShift", true)
  forcefield_fadeMaxDistVarId = get_shader_variable_id("forcefield_fadeMaxDist", true)
  forcefield_shiningBorderMaxHeightVarId = get_shader_variable_id("forcefield_shiningBorderMaxHeight", true)
  forcefield_shiningFlamesMaxHeighttVarId = get_shader_variable_id("forcefield_shiningFlamesMaxHeight", true)
  forcefield_colorVarId = get_shader_variable_id("forcefield_color", true)
  forcefield_waveSpeedVarId = get_shader_variable_id("forcefield_waveSpeed", true)
  forcefield_distortionStrengthVarId = get_shader_variable_id("forcefield_distortionStrength", true)
  forcefield_waveLengthVarId = get_shader_variable_id("forcefield_waveLength", true)


[es(tag=render, on_appear,
  track=(forcefield__aberrationShift, forcefield__fadeMaxDist, forcefield__shiningBorderMaxHeight,
    forcefield__shiningFlamesMaxHeight, forcefield__color, forcefield__waveSpeed,
    forcefield__distortionStrength, forcefield__waveLength))]
def forcefield_render_track_vars(evt : Event;
                                 forcefield__aberrationShift : float4;
                                 forcefield__fadeMaxDist : float;
                                 forcefield__shiningBorderMaxHeight : float;
                                 forcefield__shiningFlamesMaxHeight : float;
                                 forcefield__color : float4;
                                 forcefield__waveSpeed : float;
                                 forcefield__distortionStrength : float;
                                 forcefield__waveLength : float)
  DagorShaders::set_color4(forcefield_aberrationShiftVarId, forcefield__aberrationShift)
  DagorShaders::set_real(forcefield_fadeMaxDistVarId, forcefield__fadeMaxDist)
  DagorShaders::set_real(forcefield_shiningBorderMaxHeightVarId, forcefield__shiningBorderMaxHeight)
  DagorShaders::set_real(forcefield_shiningFlamesMaxHeighttVarId, forcefield__shiningFlamesMaxHeight)
  DagorShaders::set_color4(forcefield_colorVarId, forcefield__color)
  DagorShaders::set_real(forcefield_waveSpeedVarId, forcefield__waveSpeed)
  DagorShaders::set_real(forcefield_distortionStrengthVarId, forcefield__distortionStrength)
  DagorShaders::set_real(forcefield_waveLengthVarId, forcefield__waveLength)