require app
require ecs
require ecs.safe
require math
require math.base
require math.easing
require DagorMath
require game.es.render.lut_switcher_common
require game.es.zone_weather_common
require game.events.events_active_matter


enum ZoneWeatherPostFxColorGradingState
  NONE
  SHOWING
  SHOW
  HIDING
  DESTROYED


def show_postfx_color_grading_entity(template_mame : string;
                                     grading_time : float)
  var result = INVALID_ENTITY_ID
  let found = find_query() <| $ [es] (eid : EntityId;
                                      zone_weather_postfx_color_grading__name : string;
                                      var zone_weather_postfx_color_grading__state : int&;
                                      var zone_weather_postfx_color_grading__gradingTime : float&)
    if zone_weather_postfx_color_grading__name == template_mame
      result = eid
      zone_weather_postfx_color_grading__state = int(ZoneWeatherPostFxColorGradingState.SHOWING)
      zone_weather_postfx_color_grading__gradingTime = grading_time
      return true
    return false

  if !found
    result = createEntity(template_mame) <| $ [es] (var init : ComponentsInitializer)
      init |> set("zone_weather_postfx_color_grading__state", int(ZoneWeatherPostFxColorGradingState.SHOWING))
      init |> set("zone_weather_postfx_color_grading__gradingTime", grading_time)

  return result


def init_zone_weather_forcefield()
  find_query() <| $ [es] (zone_weather__state : int;
                          zone_weather__forcefield__aberrationShiftStorm : float4;
                          zone_weather__forcefield__fadeMaxDistStorm : float;
                          zone_weather__forcefield__shiningBorderMaxHeightStorm : float;
                          zone_weather__forcefield__shiningFlamesMaxHeightStorm : float;
                          zone_weather__forcefield__colorStorm : float4;
                          zone_weather__forcefield__waveSpeedStorm : float;
                          zone_weather__forcefield__distortionStrengthStorm : float;
                          zone_weather__forcefield__waveLengthStorm : float;
                          var zone_weather__forcefield__aberrationShiftDefault : float4&;
                          var zone_weather__forcefield__fadeMaxDistDefault : float&;
                          var zone_weather__forcefield__shiningBorderMaxHeightDefault : float&;
                          var zone_weather__forcefield__shiningFlamesMaxHeightDefault : float&;
                          var zone_weather__forcefield__colorDefault : float4&;
                          var zone_weather__forcefield__waveSpeedDefault : float&;
                          var zone_weather__forcefield__distortionStrengthDefault : float&;
                          var zone_weather__forcefield__waveLengthDefault : float&;
                          var zone_weather__forcefield__aberrationShiftFrom : float4&;
                          var zone_weather__forcefield__aberrationShiftTo : float4&;
                          var zone_weather__forcefield__fadeMaxDistFromTo : float2&;
                          var zone_weather__forcefield__shiningBorderMaxHeightFromTo : float2&;
                          var zone_weather__forcefield__shiningFlamesMaxHeightFromTo : float2&;
                          var zone_weather__forcefield__colorFrom : float4&;
                          var zone_weather__forcefield__colorTo : float4&;
                          var zone_weather__forcefield__waveSpeedFromTo : float2&;
                          var zone_weather__forcefield__distortionStrengthFromTo : float2&;
                          var zone_weather__forcefield__waveLengthFromTo : float2&)
    find_query() <| $ [es] (forcefield__aberrationShift : float4;
                            forcefield__fadeMaxDist : float;
                            forcefield__shiningBorderMaxHeight : float;
                            forcefield__shiningFlamesMaxHeight : float;
                            forcefield__color : float4;
                            forcefield__waveSpeed : float;
                            forcefield__distortionStrength : float;
                            forcefield__waveLength : float)
      zone_weather__forcefield__aberrationShiftDefault = forcefield__aberrationShift
      zone_weather__forcefield__aberrationShiftFrom = forcefield__aberrationShift
      zone_weather__forcefield__aberrationShiftTo = forcefield__aberrationShift

      zone_weather__forcefield__fadeMaxDistDefault = forcefield__fadeMaxDist
      zone_weather__forcefield__fadeMaxDistFromTo = float2(forcefield__fadeMaxDist, forcefield__fadeMaxDist)

      zone_weather__forcefield__shiningBorderMaxHeightDefault = forcefield__shiningBorderMaxHeight
      zone_weather__forcefield__shiningBorderMaxHeightFromTo = float2(forcefield__shiningBorderMaxHeight, forcefield__shiningBorderMaxHeight)

      zone_weather__forcefield__shiningFlamesMaxHeightDefault = forcefield__shiningFlamesMaxHeight
      zone_weather__forcefield__shiningFlamesMaxHeightFromTo = float2(forcefield__shiningFlamesMaxHeight, forcefield__shiningFlamesMaxHeight)

      zone_weather__forcefield__colorDefault = forcefield__color
      zone_weather__forcefield__colorFrom = forcefield__color
      zone_weather__forcefield__colorTo = forcefield__color

      zone_weather__forcefield__waveSpeedDefault = forcefield__waveSpeed
      zone_weather__forcefield__waveSpeedFromTo = float2(forcefield__waveSpeed, forcefield__waveSpeed)

      zone_weather__forcefield__distortionStrengthDefault = forcefield__distortionStrength
      zone_weather__forcefield__distortionStrengthFromTo = float2(forcefield__distortionStrength, forcefield__distortionStrength)

      zone_weather__forcefield__waveLengthDefault = forcefield__waveLength
      zone_weather__forcefield__waveLengthFromTo = float2(forcefield__waveLength, forcefield__waveLength)

      return true

    if zone_weather__state == int(ZoneWeatherState.STORM)
      zone_weather__forcefield__aberrationShiftTo = zone_weather__forcefield__aberrationShiftStorm
      zone_weather__forcefield__fadeMaxDistFromTo.y = zone_weather__forcefield__fadeMaxDistStorm
      zone_weather__forcefield__shiningBorderMaxHeightFromTo.y = zone_weather__forcefield__shiningBorderMaxHeightStorm
      zone_weather__forcefield__shiningFlamesMaxHeightFromTo.y = zone_weather__forcefield__shiningFlamesMaxHeightStorm
      zone_weather__forcefield__colorTo = zone_weather__forcefield__colorStorm
      zone_weather__forcefield__waveSpeedFromTo.y = zone_weather__forcefield__waveSpeedStorm
      zone_weather__forcefield__distortionStrengthFromTo.y = zone_weather__forcefield__distortionStrengthStorm
      zone_weather__forcefield__waveLengthFromTo.y = zone_weather__forcefield__waveLengthStorm
    return true


[es(tag=gameClient, on_appear, REQUIRE=render_forcefield)]
def zone_weather_forcefield_appear(evt : Event)
  init_zone_weather_forcefield()


[es(tag=gameClient, on_appear)]
def zone_weather_appear(evt : Event;
                        var zone_weather__wind__strengthDefault : float&;
                        var zone_weather__wind__strengthFromTo : float2&;
                        var zone_weather__wind__noiseScaleDefault : float&;
                        var zone_weather__wind__noiseScaleFromTo : float2&)
  find_query() <| $ [es] (wind__strength : float;
                          wind__noiseScale : float)
    zone_weather__wind__strengthDefault = wind__strength
    zone_weather__wind__strengthFromTo = float2(wind__strength, wind__strength)

    zone_weather__wind__noiseScaleDefault = wind__noiseScale
    zone_weather__wind__noiseScaleFromTo = float2(wind__noiseScale, wind__noiseScale)
    return true

  init_zone_weather_forcefield()



[es(tag=gameClient, on_appear, track=zone_weather__state, after=zone_weather_appear)]
def zone_weather_track_state(evt : Event;
                             zone_weather__state : int;
                             zone_weather__stormColorGradingTemplate : string;
                             zone_weather__noize__factorStorm : float = 1.0;
                             zone_weather__riseTime : float = 15.0;
                             zone_weather__recoveryTime : float = 15.0;
                             //zone_weather__wind__strengthDefault : float;
                             //zone_weather__wind__strengthStorm : float;
                             //zone_weather__wind__noiseScaleDefault : float;
                             //zone_weather__wind__noiseScaleStorm : float;
                             zone_weather__forcefield__aberrationShiftDefault : float4;
                             zone_weather__forcefield__aberrationShiftStorm : float4;
                             zone_weather__forcefield__fadeMaxDistDefault : float;
                             zone_weather__forcefield__fadeMaxDistStorm : float;
                             zone_weather__forcefield__shiningBorderMaxHeightDefault : float;
                             zone_weather__forcefield__shiningBorderMaxHeightStorm : float;
                             zone_weather__forcefield__shiningFlamesMaxHeightDefault : float;
                             zone_weather__forcefield__shiningFlamesMaxHeightStorm : float;
                             zone_weather__forcefield__colorDefault : float4;
                             zone_weather__forcefield__colorStorm : float4;
                             zone_weather__forcefield__waveSpeedDefault : float;
                             zone_weather__forcefield__waveSpeedStorm : float;
                             zone_weather__forcefield__distortionStrengthDefault : float;
                             zone_weather__forcefield__distortionStrengthStorm : float;
                             zone_weather__forcefield__waveLengthDefault : float;
                             zone_weather__forcefield__waveLengthStorm : float;
                             var zone_weather__currentColorGradingEid : EntityId&;
                             var zone_weather__noize__enabled : bool&;
                             var zone_weather__noize__factor : float&;
                             var zone_weather__noize__speed : float&;
                             // var zone_weather__wind__strengthFromTo : float2&;
                             // var zone_weather__wind__noiseScaleFromTo : float2&;
                             var zone_weather__stateChangedAt : float&;
                             var zone_weather__stateFinalTimeAt : float&;
                             var zone_weather__forcefield__aberrationShiftFrom : float4&;
                             var zone_weather__forcefield__aberrationShiftTo : float4&;
                             var zone_weather__forcefield__fadeMaxDistFromTo : float2&;
                             var zone_weather__forcefield__shiningBorderMaxHeightFromTo : float2&;
                             var zone_weather__forcefield__shiningFlamesMaxHeightFromTo : float2&;
                             var zone_weather__forcefield__colorFrom : float4&;
                             var zone_weather__forcefield__colorTo : float4&;
                             var zone_weather__forcefield__waveSpeedFromTo : float2&;
                             var zone_weather__forcefield__distortionStrengthFromTo : float2&;
                             var zone_weather__forcefield__waveLengthFromTo : float2&)

  assume stormColorGradingTemplate = zone_weather__stormColorGradingTemplate
  assume currentColorGradingEid = zone_weather__currentColorGradingEid

  assume noizeEnabled = zone_weather__noize__enabled
  assume noizeSpeed = zone_weather__noize__speed
  assume noizeFactor = zone_weather__noize__factor

  // assume windStrengthFromTo = zone_weather__wind__strengthFromTo
  // assume windStrengthDefault = zone_weather__wind__strengthDefault
  // assume windStrengthStorm = zone_weather__wind__strengthStorm
  // assume windNoiseScaleFromTo = zone_weather__wind__noiseScaleFromTo
  // assume windNoiseScaleDefault = zone_weather__wind__noiseScaleDefault
  // assume windNoiseScaleStorm = zone_weather__wind__noiseScaleStorm


  if currentColorGradingEid != INVALID_ENTITY_ID
    query(currentColorGradingEid) <| $ [es] (var zone_weather_postfx_color_grading__state : int&)
      zone_weather_postfx_color_grading__state = int(ZoneWeatherPostFxColorGradingState.HIDING)
      currentColorGradingEid = INVALID_ENTITY_ID

  let currentTime = get_sync_time()


  var newStateTime = 0.0
  if zone_weather__state == int(ZoneWeatherState.DEFAULT)
    // Time of last state
    newStateTime = zone_weather__recoveryTime

  zone_weather__stateChangedAt = currentTime

  noizeEnabled = false


  // Wind update disabled
  // Wind (set immediately because we can't update it in runtime)
  // find_query() <| $ [es] (var wind__strength : float&;
  //                         var wind__noiseScale : float&)
  //   if zone_weather__state == int(ZoneWeatherState STORM)
  //     wind__strength = windStrengthStorm
  //     wind__noiseScale = windNoiseScaleStorm
  //   else
  //     wind__strength = windStrengthDefault
  //     wind__noiseScale = windNoiseScaleDefault
  //   return true


  // Forcefield
  find_query() <| $ [es] (forcefield__aberrationShift : float4;
                          forcefield__fadeMaxDist : float;
                          forcefield__shiningBorderMaxHeight : float;
                          forcefield__shiningFlamesMaxHeight : float;
                          forcefield__color : float4;
                          forcefield__waveSpeed : float;
                          forcefield__distortionStrength : float;
                          forcefield__waveLength : float)
    zone_weather__forcefield__aberrationShiftFrom = forcefield__aberrationShift
    zone_weather__forcefield__aberrationShiftTo = zone_weather__forcefield__aberrationShiftDefault
    zone_weather__forcefield__fadeMaxDistFromTo = float2(forcefield__fadeMaxDist, zone_weather__forcefield__fadeMaxDistDefault)
    zone_weather__forcefield__shiningBorderMaxHeightFromTo = float2(forcefield__shiningBorderMaxHeight, zone_weather__forcefield__shiningBorderMaxHeightDefault)
    zone_weather__forcefield__shiningFlamesMaxHeightFromTo = float2(forcefield__shiningFlamesMaxHeight, zone_weather__forcefield__shiningFlamesMaxHeightDefault)
    zone_weather__forcefield__colorFrom = forcefield__color
    zone_weather__forcefield__colorTo = zone_weather__forcefield__colorDefault
    zone_weather__forcefield__waveSpeedFromTo = float2(forcefield__waveSpeed, zone_weather__forcefield__waveSpeedDefault)
    zone_weather__forcefield__distortionStrengthFromTo = float2(forcefield__distortionStrength, zone_weather__forcefield__distortionStrengthDefault)
    zone_weather__forcefield__waveLengthFromTo = float2(forcefield__waveLength, zone_weather__forcefield__waveLengthDefault)
    return true

  if zone_weather__state == int(ZoneWeatherState.STORM)
    newStateTime = zone_weather__riseTime
    currentColorGradingEid = show_postfx_color_grading_entity(stormColorGradingTemplate, newStateTime)
    noizeEnabled = true
    noizeFactor = zone_weather__noize__factorStorm
    zone_weather__forcefield__aberrationShiftTo = zone_weather__forcefield__aberrationShiftStorm
    zone_weather__forcefield__fadeMaxDistFromTo.y = zone_weather__forcefield__fadeMaxDistStorm
    zone_weather__forcefield__shiningBorderMaxHeightFromTo.y = zone_weather__forcefield__shiningBorderMaxHeightStorm
    zone_weather__forcefield__shiningFlamesMaxHeightFromTo.y = zone_weather__forcefield__shiningFlamesMaxHeightStorm
    zone_weather__forcefield__colorTo = zone_weather__forcefield__colorStorm
    zone_weather__forcefield__waveSpeedFromTo.y = zone_weather__forcefield__waveSpeedStorm
    zone_weather__forcefield__distortionStrengthFromTo.y = zone_weather__forcefield__distortionStrengthStorm
    zone_weather__forcefield__waveLengthFromTo.y = zone_weather__forcefield__waveLengthStorm


  noizeSpeed = safeinv(newStateTime) * noizeFactor
  zone_weather__stateFinalTimeAt = currentTime + newStateTime


[es(tag=gameClient)]
def zone_weather_update(evt : ParallelUpdateFrameDelayed;
                        zone_weather__noize__speed : float;
                        zone_weather__noize__factor : float;
                        zone_weather__noize__enabled : bool;
                        zone_weather__stateChangedAt : float;
                        zone_weather__stateFinalTimeAt : float;
                        // zone_weather__wind__strengthFromTo : float2;
                        // zone_weather__wind__noiseScaleFromTo : float2;
                        zone_weather__forcefield__aberrationShiftFrom : float4;
                        zone_weather__forcefield__aberrationShiftTo : float4;
                        zone_weather__forcefield__fadeMaxDistFromTo : float2;
                        zone_weather__forcefield__shiningBorderMaxHeightFromTo : float2;
                        zone_weather__forcefield__shiningFlamesMaxHeightFromTo : float2;
                        zone_weather__forcefield__colorFrom : float4;
                        zone_weather__forcefield__colorTo : float4;
                        zone_weather__forcefield__waveSpeedFromTo : float2;
                        zone_weather__forcefield__distortionStrengthFromTo : float2;
                        zone_weather__forcefield__waveLengthFromTo : float2)
  assume stateChangedAt = zone_weather__stateChangedAt
  assume stateFinalTimeAt = zone_weather__stateFinalTimeAt

  let stateTotalTime = zone_weather__stateFinalTimeAt - zone_weather__stateChangedAt
  let stateProgress = saturate(safediv(evt.curTime - stateChangedAt, stateTotalTime))


  // Noize
  assume noizeSpeed = zone_weather__noize__speed
  assume noizeFactor = zone_weather__noize__factor
  assume noizeEnabled = zone_weather__noize__enabled
  find_query() <| $ [es] (var postfx_noize_controller__factor : float&)
    let targetNoize = noizeEnabled ? zone_weather__noize__factor : 0.0
    postfx_noize_controller__factor = move_to_scalar(postfx_noize_controller__factor,
                                                     targetNoize,
                                                     evt.dt,
                                                     noizeSpeed)
    return true


  // Wind (runtime update disabled)
  // assume windStrengthFromTo = zone_weather__wind__strengthFromTo
  // assume windNoiseScaleFromTo = zone_weather__wind__noiseScaleFromTo
  // find_query() <| $ [es] (var wind__strength : float&;
  //                         var wind__noiseScale : float&)
  //   wind__strength = lerp(windStrengthFromTo.x, windStrengthFromTo.y, stateProgress)
  //   wind__noiseScale = lerp(windNoiseScaleFromTo.x, windNoiseScaleFromTo.y, stateProgress)
  //   return true


  // Forcefield
  find_query() <| $ [es] (var forcefield__aberrationShift : float4&;
                          var forcefield__fadeMaxDist : float&;
                          var forcefield__shiningBorderMaxHeight : float&;
                          var forcefield__shiningFlamesMaxHeight : float&;
                          var forcefield__color : float4&;
                          var forcefield__waveSpeed : float&;
                          var forcefield__distortionStrength : float&;
                          var forcefield__waveLength : float&)
    forcefield__aberrationShift = lerp(zone_weather__forcefield__aberrationShiftFrom, zone_weather__forcefield__aberrationShiftTo, stateProgress)
    forcefield__fadeMaxDist = lerp(zone_weather__forcefield__fadeMaxDistFromTo.x, zone_weather__forcefield__fadeMaxDistFromTo.y, stateProgress)
    forcefield__shiningBorderMaxHeight = lerp(zone_weather__forcefield__shiningBorderMaxHeightFromTo.x, zone_weather__forcefield__shiningBorderMaxHeightFromTo.y, stateProgress)
    forcefield__shiningFlamesMaxHeight = lerp(zone_weather__forcefield__shiningFlamesMaxHeightFromTo.x, zone_weather__forcefield__shiningFlamesMaxHeightFromTo.y, stateProgress)
    forcefield__color = lerp(zone_weather__forcefield__colorFrom, zone_weather__forcefield__colorTo, stateProgress)
    forcefield__waveSpeed = lerp(zone_weather__forcefield__waveSpeedFromTo.x, zone_weather__forcefield__waveSpeedFromTo.y, stateProgress)
    forcefield__distortionStrength = lerp(zone_weather__forcefield__distortionStrengthFromTo.x, zone_weather__forcefield__distortionStrengthFromTo.y, stateProgress)
    forcefield__waveLength = lerp(zone_weather__forcefield__waveLengthFromTo.x, zone_weather__forcefield__waveLengthFromTo.y, stateProgress)
    return true


[es(tag=gameClient, on_appear)]
def zone_weather_postfx_color_grading_appear(evt : Event;
                                             zone_weather_postfx_color_grading__name : string;
                                             zone_weather_postfx_color_grading__gradingTime : float;
                                             var zone_weather_postfx_color_grading__colorGrading : Object;
                                             var zone_weather_postfx_color_grading__nameHash : uint&;
                                             var zone_weather_postfx_color_grading__gradingSpeed : float&)
  var gradingFactorPtr = zone_weather_postfx_color_grading__colorGrading |> getRW_float("gradingFactor")
  if gradingFactorPtr != null
    *gradingFactorPtr = 0.0
  else
    zone_weather_postfx_color_grading__colorGrading |> set("gradingFactor", 0.0)

  zone_weather_postfx_color_grading__nameHash = ecs_hash(zone_weather_postfx_color_grading__name)
  add_grading(zone_weather_postfx_color_grading__nameHash, zone_weather_postfx_color_grading__colorGrading)

  zone_weather_postfx_color_grading__gradingSpeed = safeinv(zone_weather_postfx_color_grading__gradingTime)


[es(tag=gameClient, on_disappear)]
def zone_weather_postfx_color_grading_disappear(evt : Event;
                                                zone_weather_postfx_color_grading__nameHash : uint)
  remove_grading(zone_weather_postfx_color_grading__nameHash)


def update_zone_weather_postfx_color_grading_factor(zone_weather_postfx_color_grading__gradingProgress : float;
                                                    zone_weather_postfx_color_grading__gradingFactor : float;
                                                    zone_weather_postfx_color_grading__nameHash : uint;
                                                    var zone_weather_postfx_color_grading__colorGrading : Object)
  let gradingFactorValue = zone_weather_postfx_color_grading__gradingProgress * zone_weather_postfx_color_grading__gradingFactor
  var gradingFactorPtr = zone_weather_postfx_color_grading__colorGrading |> getRW_float("gradingFactor")
  if gradingFactorPtr != null
    *gradingFactorPtr = gradingFactorValue
  else
    zone_weather_postfx_color_grading__colorGrading |> set("gradingFactor", gradingFactorValue)

  update_grading(zone_weather_postfx_color_grading__nameHash, zone_weather_postfx_color_grading__colorGrading)


[es(tag=gameClient, no_order)]
def zone_weather_postfx_color_grading_update(act : ParallelUpdateFrameDelayed;
                                             eid : EntityId;
                                             zone_weather_postfx_color_grading__nameHash : uint;
                                             zone_weather_postfx_color_grading__gradingFactor : float;
                                             zone_weather_postfx_color_grading__gradingSpeed : float;
                                             zone_weather_postfx_color_grading__destroyOnHide : bool = true;
                                             zone_weather_postfx_color_grading__testMode : bool = false;
                                             var zone_weather_postfx_color_grading__gradingProgress : float&;
                                             var zone_weather_postfx_color_grading__state : int&;
                                             var zone_weather_postfx_color_grading__colorGrading : Object)
  assume nameHash = zone_weather_postfx_color_grading__nameHash
  assume gradingFactor = zone_weather_postfx_color_grading__gradingFactor
  assume gradingSpeed = zone_weather_postfx_color_grading__gradingSpeed
  assume gradingProgress = zone_weather_postfx_color_grading__gradingProgress
  assume state = zone_weather_postfx_color_grading__state
  assume colorGrading = zone_weather_postfx_color_grading__colorGrading


  if state == int(ZoneWeatherPostFxColorGradingState.SHOWING)
    gradingProgress += act.dt * gradingSpeed
    if gradingProgress >= 1.0
      gradingProgress = 1.0
      state = int(ZoneWeatherPostFxColorGradingState.SHOW)
    update_zone_weather_postfx_color_grading_factor(gradingProgress, gradingFactor, nameHash, colorGrading)
  elif state == int(ZoneWeatherPostFxColorGradingState.HIDING)
    gradingProgress -= act.dt * gradingSpeed
    if gradingProgress <= 0.0
      gradingProgress = 0.0

      if zone_weather_postfx_color_grading__destroyOnHide
        state = int(ZoneWeatherPostFxColorGradingState.DESTROYED)
        destroyEntity(eid)
      else
        state = int(ZoneWeatherPostFxColorGradingState.NONE)

    update_zone_weather_postfx_color_grading_factor(gradingProgress, gradingFactor, nameHash, colorGrading)
  elif zone_weather_postfx_color_grading__testMode
    update_zone_weather_postfx_color_grading_factor(gradingProgress, gradingFactor, nameHash, colorGrading)
