require ecs
require ecs.safe
require game.es.ecs_common
require math.base
require game.es.render.lut_switcher_common
require DngHuman
require DagorMath


[es(tag=render, no_order)]
def monster_flight_mode_effect_update(act : UpdateStageInfoAct;
                                      game_effect__attachedTo : EntityId;
                                      monster_flight_mode_effect__magnificationFromTo : float2;
                                      monster_flight_mode_effect__vignetteFactorFromTo : float2;
                                      monster_flight_mode_effect__gammaFromTo : float2;
                                      monster_flight_mode_effect__contrastFromTo : float2;
                                      monster_flight_mode_effect__saturationFromTo : float2;
                                      var human_cam_magnification_affect__magnification : float&;
                                      var postfx_vignette_affect__factor : float&;
                                      var game_effect__colorGrading : Object)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (human_net_phys : HumanActor;
                                                                  monster_flight_mode__speedDefault : float;
                                                                  monster_flight_mode__speedSprint : float;
                                                                  monster_flight_mode__sprintBrakeUntil : float;
                                                                  monster_flight_mode__forceVelocityEnabled : bool = false)
    assume phys = human_net_phys.phys
    assume curState = phys.currentState

    let speedMin = monster_flight_mode__speedDefault
    let speedMax = monster_flight_mode__speedSprint
    var effectFactor = cvt(length(curState.velocity), speedMin, speedMax, 0.0, 1.0)

    let isSprintBraking = monster_flight_mode__sprintBrakeUntil > act.curTime
    if isSprintBraking
      effectFactor = 0.0
    elif monster_flight_mode__forceVelocityEnabled
      effectFactor = 1.0

    let sprintBrakingKoef = isSprintBraking ? 1.25 : 1.0

    // FOV
    let magnification = lerp(monster_flight_mode_effect__magnificationFromTo.x, monster_flight_mode_effect__magnificationFromTo.y, effectFactor)
    human_cam_magnification_affect__magnification = lerp(human_cam_magnification_affect__magnification, magnification, sprintBrakingKoef * 1.0 * act.dt)

    // Vignette
    let vignetteFactor = lerp(monster_flight_mode_effect__vignetteFactorFromTo.x, monster_flight_mode_effect__vignetteFactorFromTo.y, effectFactor)
    postfx_vignette_affect__factor = lerp(postfx_vignette_affect__factor, vignetteFactor, sprintBrakingKoef * 1.0 * act.dt)
    find_query() <| $ [es] (var postfx_vignette_controller__vignetteFactor : float&)
      postfx_vignette_controller__vignetteFactor = postfx_vignette_affect__factor
      return true

    // Color grading
    game_effect__colorGrading |> ensure_float4("colorGamma", float4(1.0)) <| $(var colorGamma : float4&)
      let value = lerp(monster_flight_mode_effect__gammaFromTo.x,
                      monster_flight_mode_effect__gammaFromTo.y,
                      effectFactor)
      colorGamma.w = lerp(colorGamma.w, value, 3.0 * act.dt)

    game_effect__colorGrading |> ensure_float4("colorContrast", float4(1.0)) <| $(var colorContrast : float4&)
      let value = lerp(monster_flight_mode_effect__contrastFromTo.x,
                       monster_flight_mode_effect__contrastFromTo.y,
                       effectFactor)
      colorContrast.w = lerp(colorContrast.w, value, 3.0 * act.dt)

    game_effect__colorGrading |> ensure_float4("colorSaturation", float4(1.0)) <| $(var colorSaturation : float4&)
      let value = lerp(monster_flight_mode_effect__saturationFromTo.x,
                       monster_flight_mode_effect__saturationFromTo.y,
                       effectFactor)
      colorSaturation.w = lerp(colorSaturation.w, value, 3.0 * act.dt)

    query() <| $ [es] (var color_grading_items : ecs::Array)
      update_grading(ecs_hash("game_effect"), color_grading_items, game_effect__colorGrading)


[es(tag=render, on_appear)]
def monster_flight_mode_effect_on_appear(evt : Event;
                                         game_effect__attachedTo : EntityId;
                                         monster_flight_mode_effect__sprintGeomtreeEffectTemplate : string;
                                         var monster_flight_mode_effect__sprintGeomtreeEffectEid : EntityId&)
  monster_flight_mode_effect__sprintGeomtreeEffectEid = createEntity(monster_flight_mode_effect__sprintGeomtreeEffectTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", game_effect__attachedTo)


[es(tag=render, track=(monster_flight_mode__isSprinting, monster_flight_mode__forceVelocityEnabled), on_appear)]
def monster_flight_mode_effect_update_sprint_geomtree_effect(evt : Event;
                                                             eid : EntityId;
                                                             monster_flight_mode__isSprinting : bool;
                                                             monster_flight_mode__forceVelocityEnabled : bool = false)

  find_query() <| $ [es(REQUIRE=mothman_monster_effect)] (game_effect__attachedTo : EntityId;
                                                          monster_flight_mode_effect__sprintGeomtreeEffectEid : EntityId)
    if game_effect__attachedTo != eid
      return false

    query(monster_flight_mode_effect__sprintGeomtreeEffectEid) <| $ [es] (game_effect__geomtreeEffectEntities : EidList)
      let isEffectActive = monster_flight_mode__isSprinting || monster_flight_mode__forceVelocityEnabled
      let spawnRate = isEffectActive ? 1.0 : 0.0

      for fxEid in game_effect__geomtreeEffectEntities
        query(fxEid) <| $ [es] (var effect__spawnRate : float&)
          effect__spawnRate = spawnRate

    return true


[es(tag=render, on_disappear)]
def monster_flight_mode_effect_on_disappear(evt : Event;
                                            monster_flight_mode_effect__sprintGeomtreeEffectEid : EntityId)
  destroyEntity(monster_flight_mode_effect__sprintGeomtreeEffectEid)