require ecs
require ecs.safe
require app
require net
require math.base
require math.easing
require AnimV20
require GeomNodeTree
require HumanPhys
require DngHuman
require DngActor
require DngNet
require DagorMath
require DagorRandom
require DagorSystem
require Dacoll
require game.es.level_common
require game.events.events_active_matter
require game.es.human_weap_common
require game.es.human.human_gun_common
require game.es.grav_zones_common
require game.utils.hero
require game.events.events
require game.es.teleport_common
require game.es.spawn_common
require game.es.ecs_common
require game.es.game_effect_common
require game.es.ai.agent_position_mapping_common
require pathfinder
require player
require GridCollision


enum SpawnSequenceControllerFlags
  INIT_REQUEST_SKIPPED_BY_TIMEOUT = 0x1


def spawn_sequence_print_log(text)
  print("[Spawn Sequence] {text}")


[es(tag=server, on_appear, track=spawn_sequence_controller__state, REQUIRE_NOT=recreated_possessed)]
def spawn_sequence_controller_track_state(evt : Event;
                                          createdByPlr : EntityId;
                                          eid aka actor_eid : EntityId;
                                          spawn_sequence_controller__initAffect : string;
                                          spawn_sequence_controller__sequenceAffect : string;
                                          spawn_sequence_controller__initRequestTimeout : float = 30.0;
                                          var spawn_sequence_controller__initAffectEid : EntityId&;
                                          var spawn_sequence_controller__state : int&;
                                          var spawn_sequence_controller__timeoutAt : float&)
  spawn_sequence_controller__timeoutAt = 0.0

  spawn_sequence_print_log("{actor_eid}: state={spawn_sequence_controller__state}")
  if spawn_sequence_controller__state == int(SpawnSequenceControllerState.INIT)
    // Create init affect synchronously to hide actor asap
    spawn_sequence_controller__state = int(SpawnSequenceControllerState.INIT_REQUEST)
    spawn_sequence_controller__initAffectEid = createEntitySync(spawn_sequence_controller__initAffect) <| $ [es] (var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", actor_eid)
  elif spawn_sequence_controller__state == int(SpawnSequenceControllerState.INIT_REQUEST)
    let isPlayerExists = (createdByPlr != INVALID_ENTITY_ID)
    let isPlayerIsBot = isPlayerExists && has(createdByPlr, "playerIsBot")
    let isPlayerDisconnected = isPlayerExists && get_bool(createdByPlr, "disconnected") ?? false

    if !isPlayerExists || isPlayerIsBot || isPlayerDisconnected
      spawn_sequence_print_log("{actor_eid}: Start spawn sequence right now (isPlayerExists={isPlayerExists}, isPlayerIsBot={isPlayerIsBot}, isPlayerDisconnected={isPlayerDisconnected})")
      spawn_sequence_controller__state = int(SpawnSequenceControllerState.SEQUENCE)
    else
      spawn_sequence_print_log("{actor_eid}: Start waiting client response... Timeout in {spawn_sequence_controller__initRequestTimeout}.")
      spawn_sequence_controller__timeoutAt = get_sync_time() + spawn_sequence_controller__initRequestTimeout
  elif spawn_sequence_controller__state == int(SpawnSequenceControllerState.SEQUENCE)
    destroyEntity(spawn_sequence_controller__initAffectEid)
    spawn_sequence_controller__initAffectEid = INVALID_ENTITY_ID
    createEntity(spawn_sequence_controller__sequenceAffect) <| $ [es] (var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", actor_eid)


[es(tag=server, no_order)]
def spawn_sequence_controller_update(act : UpdateStageInfoAct;
                                     eid : EntityId;
                                     var spawn_sequence_controller__flags : int&;
                                     var spawn_sequence_controller__state : int&;
                                     var spawn_sequence_controller__timeoutAt : float&)
  if spawn_sequence_controller__timeoutAt > 0.0 && act.curTime >= spawn_sequence_controller__timeoutAt
    spawn_sequence_print_log("{eid}: timeout! state={spawn_sequence_controller__state}")
    spawn_sequence_controller__timeoutAt = 0.0
    if spawn_sequence_controller__state == int(SpawnSequenceControllerState.INIT_REQUEST)
      spawn_sequence_print_log("{eid}: INIT_REQUEST -> SEQUENCE")
      spawn_sequence_controller__state = int(SpawnSequenceControllerState.SEQUENCE)
      spawn_sequence_controller__flags |= int(SpawnSequenceControllerFlags.INIT_REQUEST_SKIPPED_BY_TIMEOUT)


def is_my_hero_on_spawn_sequence_init(actor_eid : EntityId)
  var res = false
  query(actor_eid) <| $ [es] (possessedByPlr : EntityId)
    if possessedByPlr == get_local_player_eid()
      res = find_query() <| $ [es(REQUIRE=spawn_sequence_init)] (game_effect__attachedTo : EntityId)
        return game_effect__attachedTo == actor_eid
  return res


[es(tag=gameClient, on_appear, REQUIRE=spawn_sequence_init, REQUIRE_NOT=recreated_possessed)]
def spawn_sequence_init_on_client(evt : Event;
                                  game_effect__attachedTo : EntityId)
  if is_my_hero_on_spawn_sequence_init(game_effect__attachedTo)
    spawn_sequence_print_log("{game_effect__attachedTo}: spawn_sequence_init_on_client")
    send_net_event(game_effect__attachedTo, EventSpawnSequenceHeroInited())


[es(tag=gameClient, on_appear, track=possessedByPlr, REQUIRE_NOT=recreated_possessed)]
def spawn_sequence_controller_track_player_on_client(evt : Event;
                                                     eid aka actor_eid : EntityId;
                                                     possessedByPlr : EntityId)
  if possessedByPlr == get_local_player_eid()
    if is_my_hero_on_spawn_sequence_init(actor_eid)
      spawn_sequence_print_log("{actor_eid}: spawn_sequence_controller_track_player_on_client")
      send_net_event(actor_eid, EventSpawnSequenceHeroInited())


[es(tag=server)]
def spawn_sequence_hero_inited_on_server(evt : EventSpawnSequenceHeroInited;
                                         eid : EntityId;
                                         var spawn_sequence_controller__state : int&)
  if spawn_sequence_controller__state == int(SpawnSequenceControllerState.INIT_REQUEST)
    spawn_sequence_print_log("{eid}: INIT_REQUEST -> SEQUENCE")
    spawn_sequence_controller__state = int(SpawnSequenceControllerState.SEQUENCE)


[es(tag=server, on_disappear, REQUIRE=spawn_sequence_affect)]
def spawn_sequence_affect_disappear(evt : Event;
                                    game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var spawn_sequence_controller__state : int&)
    spawn_sequence_print_log("{game_effect__attachedTo}: -> DONE")
    spawn_sequence_controller__state = int(SpawnSequenceControllerState.DONE)


[es(tag=gameClient, on_appear, REQUIRE=spawn_sequence__soldierAppears)]
def spawn_sequence_soldier_appears_client(evt : Event;
                                          game_effect__attachedTo : EntityId)
  createEntity("militant_spawn_sequence_fov_affect") <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", game_effect__attachedTo)


def test_spawn_sphere_collision(pos : float3;
                                radius : float)
  var hasCollision = false

  dacoll_use_sphere_collision() <| $(var coll : CollisionObject)
    var testTm = IDENT_TM
    testTm[3] = pos
    dacoll_set_collision_object_tm(coll, testTm)
    dacoll_set_collision_sphere_rad(coll, radius)
    hasCollision = test_collision_ri(coll, IDENT_BBOX)
  return hasCollision


def get_spawn_sequence_portal_test_collision_radius()
  return 0.5


def create_spawn_sequence_fx(eid : EntityId;
                             spawn_sequence__fxTempl : string;
                             stage_game_effect__attachedTo : EntityId;
                             spawn_sequence__fxOffset : float3)
  find_query() <| $ [es] (game_effect__attachedTo aka sequence_game_effect__attachedTo : EntityId;
                          var spawn_sequence__fxEid : EntityId&)
    if sequence_game_effect__attachedTo != stage_game_effect__attachedTo
      return false

    query(stage_game_effect__attachedTo) <| $ [es] (transform : float3x4)
      let gravTm = get_grav_tm(transform[3])
      var gravOrientedTm = gravTm

      if is_server() && !has(eid, "spawn_sequence__noMoveToNavMesh")
        // Project on navmesh
        var attempts : int
        var fixOffset : float3
        while attempts++ < 3
          var pos = transform[3] + fixOffset
          if project_to_nearest_navmesh_point_with_navmesh_mapping_and_check_accessibility(pos, float3(2.5))
            gravOrientedTm[3] = pos
            break
          else
            var rndDir : float2
            sincos(gfrnd() * TWOPI, rndDir.y, rndDir.x)
            let scale = float(attempts)
            fixOffset = gravTm[0] * rndDir.x * scale + gravTm[2] * rndDir.y * scale

      var tm = scale_tm(1e-3)
      tm[3] = gravOrientedTm[3] + gravOrientedTm |> rotate(spawn_sequence__fxOffset)
      if test_spawn_sphere_collision(tm[3], get_spawn_sequence_portal_test_collision_radius())
        tm[3] = gravOrientedTm[3] + gravOrientedTm |> rotate(spawn_sequence__fxOffset * 0.5)
        if test_spawn_sphere_collision(tm[3], get_spawn_sequence_portal_test_collision_radius())
          tm[3] = gravOrientedTm[3] + gravOrientedTm |> rotate(spawn_sequence__fxOffset * 0.25)


      adjust_entity_spawn_position(tm[3], 0.25, 5, 0.1)

      spawn_sequence__fxEid = createEntity(spawn_sequence__fxTempl) <| $(init)
        init |> set("transform", tm)
        init |> set("extraction_visual__ownerEid", eid)

    return true


[es(tag=server, on_appear)]
def create_spawn_sequence_fx_server(evt : Event; eid : EntityId;
                                    spawn_sequence__fxTempl : string;
                                    game_effect__attachedTo : EntityId;
                                    spawn_sequence__fxOffset : float3)
  create_spawn_sequence_fx(eid, spawn_sequence__fxTempl, game_effect__attachedTo, spawn_sequence__fxOffset)


[es(tag=netClient, on_appear, REQUIRE=spawn_sequence__createFxClient)]
def create_spawn_sequence_fx_client(evt : Event; eid : EntityId;
                                    spawn_sequence__fxTempl : string;
                                    game_effect__attachedTo : EntityId;
                                    spawn_sequence__fxOffset : float3)
  create_spawn_sequence_fx(eid, spawn_sequence__fxTempl, game_effect__attachedTo, spawn_sequence__fxOffset)



[es(tag=server, on_appear, REQUIRE=suspendedPlayerControl, REQUIRE_NOT=(hero, am_militant_bot))]
def spawn_seq_suspend_player_control_server(evt : Event; var human_net_phys : HumanActor; var replication : NetObject&; var spawn_sequence__connIdMemory : int&)
  base_phys_actor_setRoleAndTickrateType(human_net_phys, NetRole.ROLE_LOCALLY_CONTROLLED_AUTHORITY, human_net_phys.tickrateType)
  spawn_sequence__connIdMemory = int(replication |> net_object_getControlledBy())
  replication |> net_object_setControlledBy(-1)


[es(tag=netClient, on_appear, REQUIRE=suspendedPlayerControl)]
def spawn_seq_suspend_player_control_client(evt : Event; var human_net_phys : HumanActor)
  if human_net_phys.role == NetRole.ROLE_LOCALLY_CONTROLLED_SHADOW
    base_phys_actor_setRoleAndTickrateType(human_net_phys, NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW, human_net_phys.tickrateType)


[es(tag=server, on_disappear, REQUIRE=suspendedPlayerControl, REQUIRE_NOT=(hero, am_militant_bot))]
def spawn_seq_resume_player_control_server(evt : Event; var human_net_phys : HumanActor; var replication : NetObject&; spawn_sequence__connIdMemory : int)
  if human_net_phys.role == NetRole.ROLE_LOCALLY_CONTROLLED_AUTHORITY
    base_phys_actor_setRoleAndTickrateType(human_net_phys, NetRole.ROLE_REMOTELY_CONTROLLED_AUTHORITY, human_net_phys.tickrateType)
    replication |> net_object_setControlledBy(spawn_sequence__connIdMemory)


[es(tag=netClient, on_disappear, REQUIRE=suspendedPlayerControl)]
def spawn_seq_resume_player_control_client(evt : Event; var human_net_phys : HumanActor)
  if human_net_phys.role == NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW
    base_phys_actor_setRoleAndTickrateType(human_net_phys, NetRole.ROLE_LOCALLY_CONTROLLED_SHADOW, human_net_phys.tickrateType)


[es(on_appear, REQUIRE=hero_spawn_portal)]
def extraction_portal_appear(evt : Event;
                             eid aka portal_eid : EntityId;
                             extraction_visual__ownerEid : EntityId;
                             hero_spawn_portal__scaleAnimationTemplate : string)
  if hero_spawn_portal__scaleAnimationTemplate != ""
    query(extraction_visual__ownerEid) <| $ [es] (game_effect__attachedTo : EntityId)
      addSubTemplate(game_effect__attachedTo, hero_spawn_portal__scaleAnimationTemplate) <| $(var init : ComponentsInitializer)
        init |> set("militant_sequence_scale_animation__portalEid", portal_eid)


def correct_scale_animation_offset(pos : float3;
                                   down : float3;
                                   offset : float)
  // positive offset means that we go along with the down direction
  var correctedOffset = offset
  // Validate ceil collision
  var t = offset * 2.0
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()
  let traceDir = -down
  var tracePos = pos + down * offset
  if traceray_normalized(tracePos, traceDir, t, pmid, norm, ETF_RI, riDesc, -1) && riDesc.isValid
    correctedOffset += (offset * 2.0 - t)

  tracePos = pos + down * correctedOffset
  // Validate floor collision
  t = length(tracePos - pos)
  if traceray_normalized(pos, down, t, pmid, norm, ETF_RI, riDesc, -1) && riDesc.isValid
    correctedOffset = t
  return correctedOffset


[es(tag=gameClient, on_appear)]
def militant_spawn_sequence_scale_animation_init(evt : Event;
                                                 eid : EntityId;
                                                 militant_spawn_sequence_scale_animation__initialScale : float;
                                                 militant_sequence_scale_animation__portalEid : EntityId;
                                                 var militant_spawn_sequence_scale_animation__initialOffset : float&;
                                                 var militant_spawn_sequence_scale_animation__endOffset : float&;
                                                 var scaled_net_phys__scale : float&)
  assume portalEid = militant_sequence_scale_animation__portalEid
  assume initialOffset = militant_spawn_sequence_scale_animation__initialOffset
  assume endOffset = militant_spawn_sequence_scale_animation__endOffset

  scaled_net_phys__scale = militant_spawn_sequence_scale_animation__initialScale
  initialOffset = endOffset * scaled_net_phys__scale

  query(portalEid) <| $ [es] (var transform : float3x4&)
    if test_spawn_sphere_collision(transform[3], get_spawn_sequence_portal_test_collision_radius())
      // Worst case - just project to a nearest navmesh point
      project_to_nearest_navmesh_point_with_navmesh_mapping_and_check_accessibility(transform[3], float3(5.0))
    let down = get_grav_dir(transform[3])
    initialOffset = correct_scale_animation_offset(transform[3], down, initialOffset)
    endOffset = correct_scale_animation_offset(transform[3], down, endOffset)
    teleport_scaled_net_phys_actor(eid, transform[3] + down * initialOffset)


def get_militant_landing_portal_position_debug(militant_pos : float3)
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
def militant_spawn_sequence_scale_animation_update(act : UpdateStageInfoAct;
                                                   eid : EntityId;
                                                   militant_spawn_sequence_scale_animation__time : float;
                                                   militant_spawn_sequence_scale_animation__initialScale : float;
                                                   militant_sequence_scale_animation__portalEid : EntityId;
                                                   militant_spawn_sequence_scale_animation__initialOffset : float;
                                                   militant_spawn_sequence_scale_animation__endOffset : float;
                                                   var human_net_phys : HumanActor;
                                                   var militant_spawn_sequence_scale_animation__initialDelay : float&;
                                                   var militant_spawn_sequence_scale_animation__progress : float&;
                                                   var militant_spawn_sequence_scale_animation__finalDelay : float&;
                                                   var scaled_net_phys__scale : float&)
  if militant_spawn_sequence_scale_animation__initialDelay > 0.0
    militant_spawn_sequence_scale_animation__initialDelay -= act.dt
    scaled_net_phys__scale = militant_spawn_sequence_scale_animation__initialScale
    human_net_phys.phys.currentState.velocity = float3(0.0, 0.0, 0.0)
    human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND
    return

  let deltaProgress = act.dt * safeinv(militant_spawn_sequence_scale_animation__time)
  militant_spawn_sequence_scale_animation__progress += deltaProgress

  if militant_spawn_sequence_scale_animation__progress >= 1.0
    if militant_spawn_sequence_scale_animation__finalDelay > 0.0
      militant_spawn_sequence_scale_animation__finalDelay -= act.dt
    else
      removeSubTemplate(eid, "militant_spawn_sequence_scale_animation")
    scaled_net_phys__scale = 1.0
    return

  let smoothT = inOutBezier(militant_spawn_sequence_scale_animation__progress)
  scaled_net_phys__scale = lerp(militant_spawn_sequence_scale_animation__initialScale, 1.0, smoothT)
  let heroOffset = lerp(militant_spawn_sequence_scale_animation__initialOffset,
                        militant_spawn_sequence_scale_animation__endOffset,
                        smoothT)

  assume portalEid = militant_sequence_scale_animation__portalEid
  query(portalEid) <| $ [es] (transform aka portal_transform : float3x4)
    let portalPosition = portal_transform[3]
    let pos = portalPosition + get_grav_dir(portalPosition) * heroOffset
    teleport_scaled_net_phys_actor(eid, pos)

  human_net_phys.phys.currentState.velocity = float3(0.0, 0.0, 0.0)
  human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND


[es(on_disappear, REQUIRE=militant_sequence_scale_animation__portalEid)]
def militant_spawn_sequence_scale_animation_disappear(evt : Event;
                                                      var scaled_net_phys__scale : float&)
  scaled_net_phys__scale = 1.0


[es(tag=gameClient, before=camera_magnification_es)]
def mmilitant_spawn_sequence_fov_affect_update(act : UpdateStageInfoAct;
                                               game_effect__attachedTo : EntityId;
                                               game_effect__clientDestroyAt : float;
                                               game_effect__timeToDestroy : float;
                                               militant_spawn_sequence_fov_affect__initialMagnification : float)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    var t = 1.0 - clamp((game_effect__clientDestroyAt - act.curTime) / game_effect__timeToDestroy, 0.0, 1.0)

    t = pow(t, 4.0)
    t = lerp(outSine(t), t, pow(t, 2.0))
    t = clamp(t, 0.0, 1.0)

    human__cameraMagnificationMult = max(1e-3, lerp(militant_spawn_sequence_fov_affect__initialMagnification, 1.0, t))


[es(tag=gameClient, on_disappear, REQUIRE=militant_spawn_sequence_fov_affect__initialMagnification)]
def mmilitant_spawn_sequence_fov_affect_disappear(evt : Event;
                                                  game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    human__cameraMagnificationMult = 1.0


[es(on_appear, REQUIRE=spawn_sequence__invisibilityStart)]
def hide_human_on_invisibility_start(evt : Event;
                                     game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human__visible : bool&;
                                            var human_net_phys : HumanActor?;
                                            var havePairCollision : bool?;
                                            var grid_obj__hidden : int&)
    grid_obj__hidden |= int(GridHideFlag.EGH_GAME_EFFECT)
    human__visible = false
    if human_net_phys != null
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(false)
    if havePairCollision != null
      *havePairCollision = false


[es(on_appear, REQUIRE=spawn_sequence__invisibilityEnd)]
def show_human_on_invisibility_end(evt : Event;
                                   game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human__visible : bool&;
                                            var human_net_phys : HumanActor?;
                                            var havePairCollision : bool?;
                                            var grid_obj__hidden : int&)
    grid_obj__hidden &= ~int(GridHideFlag.EGH_GAME_EFFECT)
    human__visible = true
    if human_net_phys != null
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(true)
    if havePairCollision != null
      *havePairCollision = true


[es(tag=server, on_appear, track=spawn_sequence_controller__state)]
def track_spawn_sequence_end(evt : Event;
                             eid : EntityId;
                             spawn_sequence_controller__state : int)
  if spawn_sequence_controller__state == int(SpawnSequenceControllerState.DONE)
    spawn_sequence_print_log("{eid}: Spawn sequence end")
    send_net_event(eid, EventSpawnSequenceEnd())