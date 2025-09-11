require ecs
require ecs.common
require DagorMath
require DagorShaders
require DagorSystem
require danetlibs.thermal_vision.thermal_vision_event
require danetlibs.heat_sources.render.heat_source_common
require danetlibs.renderer.includes.render_events

def set_thermalvision_palette_tex(entity_with_scope_lens : EntityId)
  query(entity_with_scope_lens) <| $ [es] (thermal_visionPaletteTex : SharedTex&)
    let varId = get_shader_variable_id("thermal_palette_tex", true)
    DagorShaders::set_texture(varId, thermal_visionPaletteTex.getTexId)

def set_thermal_vision_preset_value(eid aka preset_eid : EntityId;
                                    value : bool)
  query() <| $ [es] (eid : EntityId;
                     var thermal_vision__activePresetEid : EntityId&)
    if preset_eid != INVALID_ENTITY_ID && preset_eid |> has("thermal_vision__isActive")
      query(preset_eid) <| $ [es] (var thermal_vision__isActive : bool&;
                                   var thermal_vision__prevIsActive : bool&)
        thermal_vision__prevIsActive = thermal_vision__isActive
        thermal_vision__isActive = value
        if thermal_vision__prevIsActive != thermal_vision__isActive
          if thermal_vision__isActive
            thermal_vision__activePresetEid = preset_eid
          else
            thermal_vision__activePresetEid = INVALID_ENTITY_ID
          sendEventImmediate(eid, OnChangeThermalActivePreset())
    elif preset_eid != thermal_vision__activePresetEid
      query(thermal_vision__activePresetEid) <| $ [es] (var thermal_vision__isActive : bool&;
                                                        var thermal_vision__prevIsActive : bool&)
        thermal_vision__prevIsActive = thermal_vision__isActive
        thermal_vision__isActive = false
      thermal_vision__activePresetEid = INVALID_ENTITY_ID
      sendEventImmediate(eid, OnChangeThermalActivePreset())

[es(tag=render, on_disappear, REQUIRE=thermal_vision__activePresetEid)]
def thermal_vision_on_disappear_es(event : Event)
  DagorShaders::set_int(get_shader_variable_id("special_vision", true), 0)

[es(tag=render, on_event=OnChangeThermalActivePreset, before=thermal_vision_renderer_es)]
def thermal_vision_params_set_es(event : Event;
                                 thermal_vision__activePresetEid : EntityId;
                                 thermal_vision__noise_value : ShaderVar;
                                 thermal_vision__pow_value : ShaderVar;
                                 thermal_vision__black_is_hot : ShaderVar;
                                 thermal_vision__pixel_size : ShaderVar;
                                 thermal_vision__led_effect : ShaderVar;
                                 thermal_vision__low_intensity_color : ShaderVar;
                                 thermal_vision__low_mid_intensity_color : ShaderVar;
                                 thermal_vision__mid_high_intensity_color : ShaderVar;
                                 thermal_vision__high_intensity_color : ShaderVar;
                                 thermal_vision__low_intensity_treshold : ShaderVar;
                                 thermal_vision__low_mid_intensity_treshold : ShaderVar;
                                 thermal_vision__mid_high_intensity_treshold : ShaderVar;
                                 thermal_vision__high_intensity_treshold : ShaderVar)
  if thermal_vision__activePresetEid != INVALID_ENTITY_ID
    query(thermal_vision__activePresetEid) <| $ [es] (thermal_vision__noiseValue : float;
                                                      thermal_vision__powValue : float;
                                                      thermal_vision__blackIsHot : bool;
                                                      thermal_vision__pixelSize : int;
                                                      thermal_vision__ledEffectMode : int;
                                                      thermal_vision__lowIntensityColor : float4;
                                                      thermal_vision__lowMidIntensityColor : float4;
                                                      thermal_vision__midHighIntensityColor : float4;
                                                      thermal_vision__highIntensityColor : float4;
                                                      thermal_vision__lowIntensityTreshold : float;
                                                      thermal_vision__lowMidIntensityTreshold : float;
                                                      thermal_vision__midHighIntensityTreshold : float;
                                                      thermal_vision__highIntensityTreshold : float)
      set_thermalvision_palette_tex(thermal_vision__activePresetEid)
      DagorShaders::set_real(thermal_vision__noise_value.varId, thermal_vision__noiseValue)
      DagorShaders::set_real(thermal_vision__pow_value.varId, thermal_vision__powValue)
      DagorShaders::set_color4(thermal_vision__low_intensity_color.varId, thermal_vision__lowIntensityColor)
      DagorShaders::set_color4(thermal_vision__low_mid_intensity_color.varId, thermal_vision__lowMidIntensityColor)
      DagorShaders::set_color4(thermal_vision__mid_high_intensity_color.varId, thermal_vision__midHighIntensityColor)
      DagorShaders::set_color4(thermal_vision__high_intensity_color.varId, thermal_vision__highIntensityColor)
      DagorShaders::set_real(thermal_vision__low_intensity_treshold.varId, thermal_vision__lowIntensityTreshold)
      DagorShaders::set_real(thermal_vision__low_mid_intensity_treshold.varId, thermal_vision__lowMidIntensityTreshold)
      DagorShaders::set_real(thermal_vision__mid_high_intensity_treshold.varId, thermal_vision__midHighIntensityTreshold)
      DagorShaders::set_real(thermal_vision__high_intensity_treshold.varId, thermal_vision__highIntensityTreshold)
      DagorShaders::set_real(thermal_vision__high_intensity_treshold.varId, thermal_vision__highIntensityTreshold)
      DagorShaders::set_int(thermal_vision__black_is_hot.varId, thermal_vision__blackIsHot ? 1 : 0)
      DagorShaders::set_int(thermal_vision__pixel_size.varId, thermal_vision__pixelSize)
      DagorShaders::set_int(thermal_vision__led_effect.varId, thermal_vision__ledEffectMode)


[es(tag=render, before=thermal_vision_renderer_es, REQUIRE=(thermal_vision__isPreset, thermal_vision__isActive),
track=(thermal_vision__noiseValue, thermal_vision__powValue, thermal_vision__blackIsHot, thermal_vision__pixelSize, thermal_vision__ledEffectMode, thermal_vision__lowIntensityColor,
thermal_vision__lowMidIntensityColor, thermal_vision__midHighIntensityColor, thermal_vision__highIntensityColor, thermal_vision__lowIntensityTreshold,
thermal_vision__lowMidIntensityTreshold, thermal_vision__midHighIntensityTreshold, thermal_vision__highIntensityTreshold))]
def thermal_vision_track_params_es(event : Event;
                                   eid : EntityId;
                                   thermal_vision__noiseValue : float;
                                   thermal_vision__powValue : float;
                                   thermal_vision__blackIsHot : bool;
                                   thermal_vision__pixelSize : int;
                                   thermal_vision__ledEffectMode : int;
                                   thermal_vision__lowIntensityColor : float4;
                                   thermal_vision__lowMidIntensityColor : float4;
                                   thermal_vision__midHighIntensityColor : float4;
                                   thermal_vision__highIntensityColor : float4;
                                   thermal_vision__lowIntensityTreshold : float;
                                   thermal_vision__lowMidIntensityTreshold : float;
                                   thermal_vision__midHighIntensityTreshold : float;
                                   thermal_vision__highIntensityTreshold : float)
  query() <| $ [es] (thermal_vision__activePresetEid : EntityId;
                     thermal_vision__noise_value : ShaderVar;
                     thermal_vision__pow_value : ShaderVar;
                     thermal_vision__black_is_hot : ShaderVar;
                     thermal_vision__pixel_size : ShaderVar;
                     thermal_vision__led_effect : ShaderVar;
                     thermal_vision__low_intensity_color : ShaderVar;
                     thermal_vision__low_mid_intensity_color : ShaderVar;
                     thermal_vision__mid_high_intensity_color : ShaderVar;
                     thermal_vision__high_intensity_color : ShaderVar;
                     thermal_vision__low_intensity_treshold : ShaderVar;
                     thermal_vision__low_mid_intensity_treshold : ShaderVar;
                     thermal_vision__mid_high_intensity_treshold : ShaderVar;
                     thermal_vision__high_intensity_treshold : ShaderVar)
    if thermal_vision__activePresetEid != INVALID_ENTITY_ID && thermal_vision__activePresetEid == eid
      DagorShaders::set_real(thermal_vision__noise_value.varId, thermal_vision__noiseValue)
      DagorShaders::set_real(thermal_vision__pow_value.varId, thermal_vision__powValue)
      DagorShaders::set_color4(thermal_vision__low_intensity_color.varId, thermal_vision__lowIntensityColor)
      DagorShaders::set_color4(thermal_vision__low_mid_intensity_color.varId, thermal_vision__lowMidIntensityColor)
      DagorShaders::set_color4(thermal_vision__mid_high_intensity_color.varId, thermal_vision__midHighIntensityColor)
      DagorShaders::set_color4(thermal_vision__high_intensity_color.varId, thermal_vision__highIntensityColor)
      DagorShaders::set_real(thermal_vision__low_intensity_treshold.varId, thermal_vision__lowIntensityTreshold)
      DagorShaders::set_real(thermal_vision__low_mid_intensity_treshold.varId, thermal_vision__lowMidIntensityTreshold)
      DagorShaders::set_real(thermal_vision__mid_high_intensity_treshold.varId, thermal_vision__midHighIntensityTreshold)
      DagorShaders::set_real(thermal_vision__high_intensity_treshold.varId, thermal_vision__highIntensityTreshold)
      DagorShaders::set_int(thermal_vision__black_is_hot.varId, thermal_vision__blackIsHot ? 1 : 0)
      DagorShaders::set_int(thermal_vision__pixel_size.varId, thermal_vision__pixelSize)
      DagorShaders::set_int(thermal_vision__led_effect.varId, thermal_vision__ledEffectMode)

[es(tag=render, REQUIRE=(watchedByPlr), track=isAlive)]
def turn_off_thermal_vision_on_soldier_death_es(event : Event;
                                                isAlive : bool)
  find_query() <| $ [es(REQUIRE=thermal_vision_renderer)] (eid : EntityId; var thermal_vision__activePresetEid : EntityId&)
    if !isAlive
      thermal_vision__activePresetEid = INVALID_ENTITY_ID
      sendEventImmediate(eid, OnChangeThermalActivePreset())
    return true

[es(tag=render, after=update_shooter_camera_aim_parameters_es, REQUIRE=(possessedByPlr, watchedByPlr), track=possessedByPlr)]
def reinit_thermal_vision_on_soldier_switch_es(event : Event)
  // we use possessedByPlr to track moment when soldier has been changed
  find_query() <| $ [es] (thermal_vision__activePresetEid : EntityId)
    if thermal_vision__activePresetEid != INVALID_ENTITY_ID
      set_thermal_vision_preset_value(thermal_vision__activePresetEid, false)
    return true

[es(tag=render, after=update_shooter_camera_aim_parameters_es,
  REQUIRE=(camera__active, isHeroCockpitCam), REQUIRE_NOT=(isPlaneCockpitCam, isTankCockpitCam))]
def set_thermal_vision_preset_scope_parameters_es(info : UpdateStageInfoAct&;
                                                  aim_data__entityWithScopeLensEid : EntityId;
                                                  aim_data__thermalVision : bool;
                                                  aim_data__lensRenderEnabled : bool;
                                                  aim_data__isAiming : bool;
                                                  camera__active : bool)
  if camera__active == false
    return
  let isAimingThermal = aim_data__thermalVision && aim_data__lensRenderEnabled && aim_data__isAiming
  find_query() <| $ [es(REQUIRE=watchedByPlr)] (attached_gun_scope__currentEid : EntityId)
    let isAimingCurrentGun = attached_gun_scope__currentEid == aim_data__entityWithScopeLensEid
    let enable = isAimingThermal && isAimingCurrentGun
    set_thermal_vision_preset_value(aim_data__entityWithScopeLensEid, enable)
    return true

[es(tag=render, REQUIRE=thermal_vision__isPreset, after=cockpit_change_active_camera_effects, track=vehicle__thermal_vision)]
def set_thermal_vision_preset_vehicle_parameters_es(evt : Event;
                                                    eid : EntityId;
                                                    vehicle__thermal_vision : bool)
  let value = vehicle__thermal_vision
  set_thermal_vision_preset_value(eid, value)
