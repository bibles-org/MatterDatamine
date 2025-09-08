options no_aot
require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorConsole
require danetlibs.thermal_vision.thermal_vision_event

[console_cmd(name="render.thermal_vision_debug")]
def toggle_thermal_vision_mode()
  query() <| $ [es] (var thermal_vision__debugMode : bool&)
    thermal_vision__debugMode = !thermal_vision__debugMode

[es(tag=render, tag=dev, track=thermal_vision__debugMode)]
def thermal_vision_debug_preset_track(evt : Event;
                                      thermal_vision__debugMode : bool)
  query() <| $ [es(REQUIRE=thermal_vision_debug)] (eid aka preset_eid : EntityId; var thermal_vision__isActive : bool&)
    thermal_vision__isActive = thermal_vision__debugMode
    find_query() <| $ [es] (eid : EntityId;
                            var thermal_vision__activePresetEid : EntityId&)
      if thermal_vision__isActive
        thermal_vision__activePresetEid = preset_eid
      else
        thermal_vision__activePresetEid = INVALID_ENTITY_ID
      sendEventImmediate(eid, OnChangeThermalActivePreset())
      return true