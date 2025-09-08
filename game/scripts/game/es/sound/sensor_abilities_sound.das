require ecs
require ecs.safe
require math.base
require math.curve
require DagorMath
require soundEvent
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events

def sound_mult_function(t, pulse_count, pause_count)
  if t < 0. || pulse_count + pause_count == 0
    return false
  return int(t / TWOPI) % (pulse_count + pause_count) < pulse_count

[es(tag=sound, REQUIRE=hero, after=sound_begin_update_es, before=sound_end_update_es)]
def sensor_abilities_sound(info : ParallelUpdateFrameDelayed;
                           sensor_abilities__abilitiesProps : Array;
                           sensor_abilities__abilitiesStates : Array;
                           var sensor_abilities_sound__types : Object&;
                           sensor_abilities_sound__enable : bool;
                           sensor_abilities_sound__timeMult : float;
                           @shared_comp sensor_abilities_sound__pulsesPerSenseValue : Array;
                           sensor_abilities_sound__updateTime : float;
                           var sensor_abilities_sound__nextUpdateTime : float&;
                           transform : float3x4)
  if sensor_abilities_sound__enable
    for soundType in sensor_abilities_sound__types
      var soundTypeObj = getRW_ecs_object(soundType.value)
      let intensity = soundTypeObj?.intensity ?? 0.
      if intensity > 0.
        var soundEnabled = false
        for node in sensor_abilities_sound__pulsesPerSenseValue
          let nodeObj = node as Object
          let pause = nodeObj?.pauseCount ?? 0
          if intensity > nodeObj?.senseValueMin ?? 1.
            let pauseCount = (nodeObj?.pause ?? false) ? pause : 0
            soundEnabled = sound_mult_function(
              info.curTime * sensor_abilities_sound__timeMult, nodeObj?.pulseCount ?? 0, pauseCount
            )
            break
        let lastPlayedTime = soundTypeObj?.lastPlayedTime ?? 0.
        if soundEnabled && info.curTime >= lastPlayedTime + TWOPI / sensor_abilities_sound__timeMult
          set(*soundTypeObj, "lastPlayedTime", info.curTime)
          var handle = soundEvent::play("", get_string(*soundTypeObj, "path", "missing path"), transform[3])
          let scanerDistance = 1. - intensity
          set_var(handle, "scanner_distance", scanerDistance)
          let volumeRng = soundTypeObj?.volumeRng ?? float2(1f)
          handle |> set_volume(cvt(scanerDistance, 1f, 0f, volumeRng.x, volumeRng.y))
          abandon(handle)

  if info.curTime >= sensor_abilities_sound__nextUpdateTime
    sensor_abilities_sound__nextUpdateTime = info.curTime + sensor_abilities_sound__updateTime
    for soundType in sensor_abilities_sound__types
      set(*getRW_ecs_object(soundType.value), "intensity", 0.)
    let sensorPos = transform[3]
    for abilityProps, abilityState in sensor_abilities__abilitiesProps, sensor_abilities__abilitiesStates
      let abilityPropsObj = abilityProps as Object
      var abilityStateList = get_ecs_EidList(abilityState)
      if abilityPropsObj != null && abilityStateList != null
        let sensorTemplate = get_ecs_string(*abilityPropsObj, "sensorTemplate")
        var soundTypeObj = sensorTemplate != null ? getRW_ecs_object(sensor_abilities_sound__types, string(*sensorTemplate)) : null
        if soundTypeObj != null
          let sensorSearchRange = (*abilityPropsObj).sensorSearchRange ?? float2(1.)
          let sensorSearchRadExtensionMult = (*abilityPropsObj).sensorSearchRadExtensionMult ?? 1.
          let sensorsCount = (*abilityPropsObj).sensorsCount ?? 1
          let sensorScanRad = min(sensorSearchRange.y, sensorSearchRange.x * pow(sensorSearchRadExtensionMult, float(sensorsCount - 1)))
          var minDistSq = square(sensorScanRad)
          for entity in *abilityStateList
            query(entity) <| $ [es] (transform : float3x4)
              minDistSq = min(minDistSq, length_sq(transform[3] - sensorPos))
          if minDistSq < square(sensorScanRad)
            let directionLen = min(sensorScanRad, sqrt(minDistSq))
            set(*soundTypeObj, "intensity", 1.0 - directionLen / sensorScanRad)
