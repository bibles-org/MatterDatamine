require ecs
require app
require net
require math.easing
require DagorMath
require DagorSystem
require DngHuman
require DngActor
require DngPhysObj
require HumanPhys
require RendInst
require Dacoll
require game.es.grav_zones_common
require game.es.teleport_common
require game.events.events_active_matter


[es(tag=server, on_appear)]
def extraction_sequence_affect_appear(evt : Event;
                                      extraction_sequence_affect__testMode : bool;
                                      extraction_sequence_affect__finalStageTest : Object;
                                      extraction_sequence_affect__finalStage : Object;
                                      var game_effect_sequence__stages : Array)
  if extraction_sequence_affect__testMode
    game_effect_sequence__stages |> push(extraction_sequence_affect__finalStageTest)
  else
    game_effect_sequence__stages |> push(extraction_sequence_affect__finalStage)


[es(tag=server, no_order)]
def extraction_sequence_start_update(act : UpdateStageInfoAct;
                                     eid aka actor_eid : EntityId;
                                     extraction_sequence_start_on_appear__templateName : string;
                                     extraction_sequence_start_on_appear__testMode : bool;
                                     var extraction_sequence_start_on_appear__delay : float&)
  if extraction_sequence_start_on_appear__delay > 0.0
    extraction_sequence_start_on_appear__delay -= act.dt
    return

  createEntity(extraction_sequence_start_on_appear__templateName) <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", actor_eid)
    init |> set("extraction_sequence_affect__testMode", extraction_sequence_start_on_appear__testMode)
  removeSubTemplate(actor_eid, "extraction_sequence_start_on_appear")


[es(tag=gameClient, on_appear)]
def extraction_sequence_soldier_appears_client(evt : Event;
                                               game_effect__attachedTo : EntityId;
                                               extraction_sequence__soldierDisappearsAffect : string)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] ()
    createEntity(extraction_sequence__soldierDisappearsAffect) <| $ [es] (var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", game_effect__attachedTo)


def get_militant_extraction_portal_position_debug(militant_pos : float3)
  let down = get_grav_dir(militant_pos)
  var riDesc = RendInstDesc()
  let traceOrigin = militant_pos - down * 10.0
  var traceT = 20.0
  var pmid : int
  var norm : float3
  if !traceray_normalized(traceOrigin, down, traceT, pmid, norm, ETF_DEFAULT, riDesc, -1)
    return militant_pos
  let end = traceOrigin + down * traceT
  return end - down * 2.0


[es(after=after_net_phys_sync)]
def militant_extraction_sequence_scale_animation_update(act : UpdateStageInfoAct;
                                                        eid : EntityId;
                                                        militant_extraction_sequence_scale_animation__time : float;
                                                        militant_extraction_sequence_scale_animation__endScale : float;
                                                        militant_sequence_scale_animation__portalEid : EntityId;
                                                        militant_extraction_sequence_scale_animation__portalOffset : float;
                                                        transform aka militant_transform : float3x4;
                                                        var human_net_phys : HumanActor?;
                                                        var phys_obj_net_phys : PhysObjActor?;
                                                        var militant_extraction_sequence_scale_animation__initialDelay : float&;
                                                        var militant_extraction_sequence_scale_animation__progress : float&;
                                                        var militant_extraction_sequence_scale_animation__finalDelay : float&;
                                                        var scaled_net_phys__scale : float&)
  if militant_extraction_sequence_scale_animation__initialDelay > 0.0
    militant_extraction_sequence_scale_animation__initialDelay -= act.dt
    scaled_net_phys__scale = 1.0
    return
  else
    let deltaProgress = act.dt * safeinv(militant_extraction_sequence_scale_animation__time)
    militant_extraction_sequence_scale_animation__progress += deltaProgress

    if militant_extraction_sequence_scale_animation__progress < 1.0
      let smoothT = inOutBezier(militant_extraction_sequence_scale_animation__progress)
      scaled_net_phys__scale = lerp(1.0,
                                    militant_extraction_sequence_scale_animation__endScale,
                                    smoothT)
    else
      if militant_extraction_sequence_scale_animation__finalDelay > 0.0
        militant_extraction_sequence_scale_animation__finalDelay -= act.dt
      else
        removeSubTemplate(eid, "militant_extraction_sequence_scale_animation")

      scaled_net_phys__scale = militant_extraction_sequence_scale_animation__endScale

  let militantPos = militant_transform[3]
  let down = get_grav_dir(militantPos)

  var portalPosition : float3
  var portalPositionSet = query(militant_sequence_scale_animation__portalEid) <| $ [es] (transform aka portal_transform : float3x4)
    portalPosition = portal_transform[3]

  if !portalPositionSet && militant_sequence_scale_animation__portalEid == INVALID_ENTITY_ID
    // For debug only
    portalPosition = get_militant_extraction_portal_position_debug(militantPos)
    portalPositionSet = true

  if portalPositionSet
    let pos = lerp(militant_transform[3],
                   portalPosition + down * militant_extraction_sequence_scale_animation__portalOffset * scaled_net_phys__scale,
                   act.dt * 2.5)

    teleport_scaled_net_phys_actor(eid, pos)

  if human_net_phys != null
    (*human_net_phys).phys.currentState.velocity = float3(0.0, 0.0, 0.0)
    (*human_net_phys).phys.currentState.moveState = HUMoveState.EMS_STAND

  if phys_obj_net_phys != null
    (*phys_obj_net_phys).phys.currentState.velocity = float3(0.0, 0.0, 0.0)


[es(tag=gameClient, on_appear, REQUIRE = militant_extraction_sequence_fov_affect__endMagnification)]
def militant_extraction_sequence_fov_affect_appear(evt : Event;
                                                   game_effect__attachedTo aka fov_game_effect__attachedTo : EntityId)
  find_query() <| $ [es(REQUIRE=human_cam_magnification_normalizer_affect)] (eid aka normalizer_affect_eid : EntityId;
                                                                             game_effect__attachedTo aka normalizer_affect_game_effect__attachedTo : EntityId)
    if normalizer_affect_game_effect__attachedTo == fov_game_effect__attachedTo
      destroyEntity(normalizer_affect_eid)
      return true
    return false


[es(tag=gameClient, before=camera_magnification_es)]
def militant_extraction_sequence_fov_affect_update(act : UpdateStageInfoAct;
                                                   game_effect__attachedTo : EntityId;
                                                   game_effect__clientDestroyAt : float;
                                                   game_effect__timeToDestroy : float;
                                                   militant_extraction_sequence_fov_affect__endMagnification : float)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    var t = 1.0 - clamp((game_effect__clientDestroyAt - act.curTime) / game_effect__timeToDestroy, 0.0, 1.0)

    t = pow(t, 1.5)

    human__cameraMagnificationMult = max(1e-3, lerp(1.0, militant_extraction_sequence_fov_affect__endMagnification, t))


[es(tag=gameClient, on_disappear, REQUIRE=militant_extraction_sequence_fov_affect__endMagnification)]
def mmilitant_extraction_sequence_fov_affect_disappear(evt : Event;
                                                       game_effect__attachedTo : EntityId;
                                                       militant_extraction_sequence_fov_affect__normalizerTemplate : string)
  createEntity(militant_extraction_sequence_fov_affect__normalizerTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", game_effect__attachedTo)


[es(tag=server, on_appear, REQUIRE=extraction_sequence__processExtraction)]
def extraction_sequence_process_extraction(evt : Event;
                                           game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (possessedByPlr : EntityId; isAlive : bool&)
    if isAlive
      print("<{game_effect__attachedTo}>(plr {possessedByPlr}) CmdExtractFromBattlefield")
      send_net_event(possessedByPlr, CmdExtractFromBattlefield())
      sendEventImmediate(possessedByPlr, CmdExtractFromBattlefieldServer())
    else
      print("<{game_effect__attachedTo}>(plr {possessedByPlr}) did not extract because they were dead by the time extraction sequence ended.")


[es(tag=server, on_appear, REQUIRE=extraction_sequence__processDestroy)]
def extraction_sequence_process_destroy(evt : Event; game_effect__attachedTo : EntityId)
  destroyEntity(game_effect__attachedTo)


[es(tag=gameClient, on_appear, REQUIRE=extraction_sequence__connectToHost)]
def extraction_sequence_connect_to_host(evt : Event;
                                        eid : EntityId)
  sendEvent(eid, CmdConnectToHost())
