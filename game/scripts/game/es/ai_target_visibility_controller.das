require ecs
require ecs.common
require ecs.safe
require math.base
require game.es.level_common
require walkerai
require DagorMath


[es(tag=server, on_appear)]
def ai_target_visibility_controller_init(evt : Event;
                                         eid : EntityId;
                                         ai_target_visibility_controller__updateInterval : float;
                                         @shared_comp ai_target_visibility_controller__approxLightPerDayTime : Array;
                                         var ai_target_visibility_controller__nextUpdateAt : float&;
                                         var ai_target_visibility_controller__currentLightByDayTime : float&)
  ai_target_visibility_controller__nextUpdateAt = eid_frnd(eid) * ai_target_visibility_controller__updateInterval

  let timeOfDay = get_current_time_of_day()
  ai_target_visibility_controller__currentLightByDayTime = 1.0
  for lightPerDayTimeData in ai_target_visibility_controller__approxLightPerDayTime
    let lightPerDayTime = lightPerDayTimeData as Object
    let from = lightPerDayTime?.from ?? 0.0
    let to = lightPerDayTime?.to ?? 0.0

    if timeOfDay >= from && timeOfDay < to
      ai_target_visibility_controller__currentLightByDayTime = lightPerDayTime?.light ?? 1.0
      break


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def ai_target_visibility_controller_update(act : UpdateStageInfoAct;
                                           eid aka ai_target_eid : EntityId;
                                           transform aka ai_target_transform : float3x4;
                                           ai_target_visibility_controller__updateInterval : float;
                                           ai_target_visibility_controller__currentLightByDayTime : float;
                                           var ai_target_visibility_controller__nextUpdateAt : float&;
                                           var ai_target_visibility_controller__currentLight : float&;
                                           var ai_target : Target)
  if ai_target_visibility_controller__nextUpdateAt > act.curTime
    return

  ai_target_visibility_controller__nextUpdateAt += ai_target_visibility_controller__updateInterval

  let aiTargetCenter = ai_target_transform[3] + ai_target_transform[1]

  var accuracyShift = 0.0

  // Ambient light
  ai_target_visibility_controller__currentLight = ai_target_visibility_controller__currentLightByDayTime

  let lightDropOffLuminance = 0.05

  // Omni lights
  let omniLightFactorMult = 3.0 * (1.0 - ai_target_visibility_controller__currentLightByDayTime)
  query() <| $ [es(REQUIRE=ai_target_omni_light)] (transform aka light_transform : float3x4;
                                                   light__brightness : float;
                                                   light__color : E3DCOLOR;
                                                   light__radius_scale : float;
                                                   light__max_radius : float)
    let distSq = distance_sq(aiTargetCenter, light_transform[3])
    if distSq < square(light__max_radius) && distSq > 1e-6
      let lightColor = float4(Color4(light__color)).xyz
      let lightLuminance = 0.3333 * (lightColor.x + lightColor.y + lightColor.z) * light__brightness
      var autoDropOffRadius = sqrt(max(0.0, lightLuminance / lightDropOffLuminance)) * light__radius_scale
      if light__max_radius > 0.0
        autoDropOffRadius = min(light__max_radius, autoDropOffRadius)

      if autoDropOffRadius > 0.0
        let lightFactor = lightLuminance * max(0.0, 1.0f - (distSq / square(autoDropOffRadius)))
        ai_target_visibility_controller__currentLight += omniLightFactorMult * lightFactor


  // Spot lights
  query() <| $ [es(REQUIRE=ai_target_spot_light)] (transform aka light_transform : float3x4;
                                                   spot_light__cone_angle : float;
                                                   spot_light__inner_attenuation : float;
                                                   light__max_radius : float;
                                                   light__brightness : float;
                                                   light__color : E3DCOLOR;
                                                   light__radius_scale : float)
    if light__brightness <= 0.0
      return

    let lightToAiTarget = aiTargetCenter - light_transform[3]
    let distSq = length_sq(lightToAiTarget)
    if distSq < square(light__max_radius) && distSq > 1e-6
      let lightForwardLen = length(light_transform[2])

      var halfTan : float
      if spot_light__cone_angle >= 0.0
        let angle = spot_light__cone_angle * DEG_TO_RAD
        halfTan = tan(angle * 0.5)
      else
        halfTan = lightForwardLen
      let attCos = cos(spot_light__inner_attenuation * atan(halfTan))

      let lightToAiTargetDir = lightToAiTarget / sqrt(distSq)

      if dot(lightToAiTargetDir, light_transform[2] / lightForwardLen) > attCos
        let lightColor = float4(Color4(light__color)).xyz
        let lightLuminance = 0.3333 * (lightColor.x + lightColor.y + lightColor.z) * light__brightness
        var autoDropOffRadius = sqrt(max(0.0, lightLuminance / lightDropOffLuminance)) * light__radius_scale
        if light__max_radius > 0.0
          autoDropOffRadius = min(light__max_radius, autoDropOffRadius)

        if autoDropOffRadius > 0.0
          let lightFactor = lightLuminance * max(0.0, 1.0f - (distSq / square(autoDropOffRadius)))
          ai_target_visibility_controller__currentLight += omniLightFactorMult * lightFactor


  // Flashlights
  let flashlightFactorMult = 0.5 * (1.0 - ai_target_visibility_controller__currentLightByDayTime)
  find_query() <| $ [es] (attached_flashlight__actorEid : EntityId;
                          attached_flashlight__isOn : bool)
    if !attached_flashlight__isOn
      return false

    if attached_flashlight__actorEid == ai_target_eid
      ai_target_visibility_controller__currentLight += flashlightFactorMult
      return true
    return false

  ai_target_visibility_controller__currentLight = saturate(ai_target_visibility_controller__currentLight)

  let lightPenalty = 1.0 - ai_target_visibility_controller__currentLight
  accuracyShift -= lightPenalty


  // Set final accuracy shift
  ai_target.accuracyShift = accuracyShift