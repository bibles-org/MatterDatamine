require ecs
require app
require math.base
require game.events.events_game
require strings
require DngHumanAnim
require DngHuman
require DngActor
require DngNet
require PhysVars
require PhysDecl
require HumanPhys
require HumanAnim
require DagorMath
require DagorSystem
require Dacoll
require GeomNodeTree
require AnimV20
require game.events.events_active_matter
require game.es.grav_zones_common
require DngPhysObj
require Grid


let
  // for better performance enough enabling not higher than ~2 ragdoll per frame
  // because in theory a player can spawn in a heap of corpses and catch a freeze
  MAX_RAGDOLL_ENABLE_PER_FRAME = 2u

  RAGDOLL_SYNC_TELEPORT_DISTANCE_CONDITION = 3f

[es(tag=render, on_appear, REQUIRE=deadEntity, REQUIRE=ragdoll)]
def mark_phys_sym_dependent(evt : Event;
                            eid : EntityId)
  addSubTemplate(eid, "phys_sym_dependent")


[es(tag=render, no_order)]
def anim_ragdoll(info : ParallelUpdateFrameDelayed)
  var enablingCount = 0u
  find_query() <| $ [es(REQUIRE=(deadEntity, animchar__physSymDependence))] (eid : EntityId;
                                                                             animchar__updatable : bool;
                                                                             ragdoll__enabled : bool;
                                                                             ragdoll__isAllowed : bool)
    if !animchar__updatable || !ragdoll__isAllowed || ragdoll__enabled
      return false
    sendEvent(eid, CmdEnableRagdoll())
    enablingCount++
    return enablingCount >= MAX_RAGDOLL_ENABLE_PER_FRAME


[es(tag=render, on_event=CmdEnableRagdoll)]
def enable_ragdoll_impl(evt : Event;
                        eid : EntityId;
                        ragdoll__isAllowed : bool;
                        ragdoll__interactMask : int const?;
                        var animchar : AnimcharBaseComponent;
                        var animchar__animState : Object;
                        var ragdoll : PhysRagdoll;
                        var ragdoll__applyParams, ragdoll__enabled, animchar__updatable : bool&;
                        var ragdoll__enabledAt : float&;
                        human_net_phys__velocity : float3 const? = null;
                        navmesh_phys__currentWalkVelocity : float3 const? = null)
  if !ragdoll__isAllowed || ragdoll__enabled
    return
  animchar__animState |> clear()
  ragdoll__applyParams = true
  ragdoll__enabled = true
  animchar__updatable = true
  ragdoll__enabledAt = get_sync_time()
  sendEvent(eid, CmdApplyRagdollParameters(cur_time = ragdoll__enabledAt))
  animchar |> animchar_resetPostController()
  let vel = human_net_phys__velocity != null ? *human_net_phys__velocity : navmesh_phys__currentWalkVelocity != null ? *navmesh_phys__currentWalkVelocity : float3()
  let interactMask = ragdoll__interactMask ?? int(PhysLayer.EPL_ALL)
  ragdoll |> ragdoll_setOverrideVel(vel)
  ragdoll |> ragdoll_startRagdoll(int(PhysLayer.EPL_CHARACTER),
                                  interactMask,
                                  animchar.nodeTree)
  animchar |> animchar_setPostController(ragdoll)


[es(tag=render, REQUIRE=animchar__physSymDependence, no_order)]
def enable_ragdoll_around_hero(update : ParallelUpdateFrameDelayed;
                               eid : EntityId;
                               transform : float3x4;
                               ragdoll__enabled : bool;
                               ragdoll__enableAroundWatchedRadius : float;
                               var ragdoll__enabledAt : float&)
  let bsphere = BSphere3(transform[3], ragdoll__enableAroundWatchedRadius)
  find_entity_in_grid(ecs_hash("humans"), bsphere, GridEntCheck.BOUNDING) <| $(human : EntityId)
    if !has(human, "watchedByPlr")
      return false
    if ragdoll__enabled
      // to reset ragdoll disable timer
      ragdoll__enabledAt = get_sync_time()
    else
      sendEvent(eid, CmdEnableRagdoll())
    return true


[es(tag=render, on_event=CmdDisableRagdoll)]
def disable_ragdoll_impl(evt : Event;
                         var animchar__updatable : bool&;
                         var animchar : AnimcharBaseComponent;
                         var ragdoll__enabled : bool&;
                         var ragdoll : PhysRagdoll)
  if ragdoll__enabled
    ragdoll |> ragdoll_endRagdoll()
    animchar |> animchar_resetPostController()
    ragdoll__enabled = false
    animchar__updatable = false


[es(tag=render, on_event=CmdEnableRagdoll, before=enable_ragdoll_impl)]
def ragdoll_dynamic_clipout(evt : Event;
                            transform : float3x4;
                            var ragdoll : PhysRagdoll;
                            human_anim__dynamicRagdollClipoutOffset = float3(0f, 0.5f, 0f);
                            human_anim__dynamicRagdollClipoutTimeout = 1f)
  if human_anim__dynamicRagdollClipoutTimeout > 0f
    let invGravDir = -get_grav_dir(transform[3], true)
    let toPos = transform[3] + invGravDir * human_anim__dynamicRagdollClipoutOffset
    ragdoll |> ragdoll_setDynamicClipout(toPos, human_anim__dynamicRagdollClipoutTimeout)


[es(tag=render, after=ragdoll_sync)]
def put_to_sleep_ragdoll(update : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         ragdoll__enabled : bool;
                         ragdoll__enabledAt : float;
                         var ragdoll : PhysRagdoll;
                         ragdoll__timeBeforeFallingAsleep = 3f;
                         ragdoll__maxTimeInAwakenedState = 30f)
  if !ragdoll__enabled
    return
  let curTime = get_sync_time()
  if curTime < ragdoll__enabledAt + ragdoll__timeBeforeFallingAsleep
    return
  var physSys = ragdoll_getPhysSys(ragdoll)
  if physSys == null
    return
  if curTime >= ragdoll__enabledAt + ragdoll__maxTimeInAwakenedState
    sendEvent(eid, CmdDisableRagdoll())
    return
  var stillBodyPartsCount = 0
  for bodyIdx in range(physSys.bodyCount)
    var physBody = phys_system_instance_getBody(*physSys, bodyIdx)
    if physBody == null
      return
    let physBodyVel = phys_body_getVelocity(*physBody)
    let physBodyVelLength = length(physBodyVel)
    if physBodyVelLength < 1e-6f
      stillBodyPartsCount++
    elif physBodyVelLength >= 0.5f // If some physBody is moving somewhere, and not just “rolling”, the ragdoll should not sleep
      return
  if stillBodyPartsCount > physSys.bodyCount / 2
    sendEvent(eid, CmdDisableRagdoll())


[es(tag=render, after=ragdoll_sync)]
def update_ri_cache_around_ragdoll(update : ParallelUpdateFrameDelayed;
                                   ragdoll__enabled : bool;
                                   var ragdoll : PhysRagdoll)
  if !ragdoll__enabled
    return
  var physSys = ragdoll_getPhysSys(ragdoll)
  if physSys == null
    return
  var physBody = phys_system_instance_getBody(*physSys, 0)
  if physBody == null
    return
  var tm : float3x4
  phys_body_getTm(*physBody, tm)
  let boxScale = float3(1f)
  let box = BBox3(tm[3] - boxScale, tm[3] + boxScale)
  update_ri_cache_in_volume_to_phys_world(box)


[es(tag=render, before=start_async_phys_sim_es)]
def ragdoll_sync(update : ParallelUpdateFrameDelayed;
                 phys_obj_net_phys : PhysObjActor;
                 ragdoll_phys_obj__attachedTo : EntityId;
                 ragdoll_phys_obj__ragdollSyncVelMult : float;
                 var ragdoll_phys_obj__links : Array;
                 var ragdoll_phys_obj__addVelocity : float3&)
  query(ragdoll_phys_obj__attachedTo) <| $ [es] (ragdoll__enabled : bool;
                                                 var ragdoll : PhysRagdoll)
    if !ragdoll__enabled
      return
    var physSys = ragdoll_getPhysSys(ragdoll)
    if physSys == null
      return
    for link in ragdoll_phys_obj__links
      var obj = getRW_ecs_object(link)
      if obj == null
        continue
      let linkNodeName = get_string(obj, "nodeName", "")
      var linkNodeId = getRW_int(obj, "nodeIdx")
      if linkNodeId == null
        logerr("can't find nodeIdx for {linkNodeName} in ragdoll for {getEntityTemplateName(ragdoll_phys_obj__attachedTo)}}")
        return
      if *linkNodeId == -1
        *linkNodeId = *physSys |> findBodyIdByName(linkNodeName)
        if *linkNodeId == -1
          logerr("can't find node {linkNodeName} in ragdoll for {getEntityTemplateName(ragdoll_phys_obj__attachedTo)}}")
          ragdoll_endRagdoll(ragdoll)
          return
      var physBody = phys_system_instance_getBody(*physSys, *linkNodeId)
      if physBody == null
        return
      let linkOffset = get_Point3(obj, "offset") ?? float3(0f)
      var physBodyTM = IDENT_TM
      phys_body_getTm(*physBody, physBodyTM)
      var attractionPointTM : float3x4
      phys_obj_net_phys.phys.currentState.location |> location_toTM(attractionPointTM)
      attractionPointTM[3] = attractionPointTM * linkOffset
      let difference = attractionPointTM[3] - physBodyTM[3]
      let dist = length(difference)
      if dist < RAGDOLL_SYNC_TELEPORT_DISTANCE_CONDITION
        let dir = normalize(difference)
        var mass, ixx, iyy, izz : float
        phys_body_getMassMatrix(*physBody, mass, ixx, iyy, izz)
        let vel = dir * dist * mass * ragdoll_phys_obj__ragdollSyncVelMult + ragdoll_phys_obj__addVelocity
        phys_body_setVelocity(*physBody, vel, true)
        ragdoll_wakeUp(ragdoll)
      else
        for idx in range(physSys.bodyCount)
          var body = phys_system_instance_getBody(*physSys, idx)
          if body == null
            continue
          phys_body_setTm(*body, attractionPointTM)
          let zeroVel = float3(0f)
          phys_body_setVelocity(*physBody, zeroVel, true)
  ragdoll_phys_obj__addVelocity = float3(0f)


[es(tag=render, on_appear)]
def attach_ragdoll_use_hint_to_node(evt : Event;
                                    ragdoll_phys_obj__attachedTo : EntityId;
                                    var item_world_marker__attachedToEid : EntityId&)
  item_world_marker__attachedToEid = ragdoll_phys_obj__attachedTo


[es(tag=render, before=ragdoll_sync)]
def apply_impulse_on_ragdoll_from_influence_gatherer(update : ParallelUpdateFrameDelayed;
                                                     transform : float3x4;
                                                     am_pile_visual__influenceFromGatherers : Point3List;
                                                     am_pile_visual__velMult : float;
                                                     am_pile_attached_to_corpse__corpseEid : EntityId)
  query(am_pile_attached_to_corpse__corpseEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId;
                                                          var ragdoll_phys_obj__addVelocity : float3&)
    for influenceFrom in am_pile_visual__influenceFromGatherers
      ragdoll_phys_obj__addVelocity += influenceFrom - transform[3]
    ragdoll_phys_obj__addVelocity = normalize(ragdoll_phys_obj__addVelocity) * am_pile_visual__velMult
    if length(ragdoll_phys_obj__addVelocity) > 0f
      query(ragdoll_phys_obj__attachedTo) <| $ [es(REQUIRE=animchar__physSymDependence)] (ragdoll__enabled : bool)
        if !ragdoll__enabled
          sendEvent(ragdoll_phys_obj__attachedTo, CmdEnableRagdoll())


// If the ragdoll has already fallen asleep and the phys obj
// for some reason has speed -> wake up the ragdoll
[es(tag=render, after=anim_ragdoll, REQUIRE=deadEntity)]
def awake_ragdoll_if_phys_obj_moving(info : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     ragdoll__enabled, animchar__updatable : bool;
                                     ragdoll_phys_obj__physObjEid : EntityId)
  if ragdoll__enabled || animchar__updatable
    return
  query(ragdoll_phys_obj__physObjEid) <| $ [es(REQUIRE=animchar__physSymDependence)] (phys_obj_net_phys : PhysObjActor)
    let physObjSpeed = length(phys_obj_net_phys.phys.currentState.velocity)
    if physObjSpeed >= 0.1f
      sendEventImmediate(eid, CmdEnableRagdoll())