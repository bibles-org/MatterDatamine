require ecs
require net
require Grid
require CollRes
require DngActor
require DngHuman
require DagorMath
require math.base
require ecs.common
require DngPhysObj
require DagorSystem
require DagorMathUtils
require game.events.events_game
require game.es.confusion_common
require game.events.sound_events
require game.es.grav_zones_common
require game.events.events_active_matter


[es(tag=server, on_appear)]
def teleportation_portal_init(evt : Event;
                              eid aka my_eid : EntityId;
                              teleportation_portal__addTemplateOnLink aka my_teleportation_portal__addTemplateOnLink : string;
                              transform aka my_transform : float3x4;
                              teleportation_portal__groupId aka my_teleportation_portal__groupId : int;
                              var teleportation_portal__linkedPortal aka my_teleportation_portal__linkedPortal : EntityId&)
  if my_teleportation_portal__groupId == -1
    logerr("Wrong 'teleportation_portal__groupId' for portal in pos <{my_transform[3]}>")
    return
  if teleportation_portal__linkedPortal != INVALID_ENTITY_ID
    return
  find_query() <| $ [es] (eid : EntityId;
                          teleportation_portal__groupId : int;
                          teleportation_portal__addTemplateOnLink : string;
                          var teleportation_portal__linkedPortal : EntityId&)
    if my_eid != eid && my_teleportation_portal__groupId == teleportation_portal__groupId && teleportation_portal__linkedPortal == INVALID_ENTITY_ID
      teleportation_portal__linkedPortal = my_eid
      my_teleportation_portal__linkedPortal = eid
      addSubTemplate(eid, teleportation_portal__addTemplateOnLink)
      addSubTemplate(my_eid, my_teleportation_portal__addTemplateOnLink)
      return true
    return false


[es(tag=gameClient, track=transform, REQUIRE=teleportation_portal__groupId)]
def teleportation_portal_tm_change(evt : Event;
                                   transform aka my_transform : float3x4;
                                   teleportation_portal__linkedPortal : EntityId)
  query(teleportation_portal__linkedPortal) <| $ [es] (var target_transform : float3x4&)
    target_transform = my_transform


[es(on_disappear)]
def unlblock_teleportation_after_cooldown(evt : Event;
                                          teleportation_cooldown_effect__attachedTeleport : EntityId;
                                          game_effect__attachedTo : EntityId)
  query(teleportation_cooldown_effect__attachedTeleport) <| $ [es] (var teleportation_portal__teleportedEntities : EidList)
    let idx = find_index(teleportation_portal__teleportedEntities, game_effect__attachedTo)
    if idx >= 0
      erase(teleportation_portal__teleportedEntities, idx)

[es]
def teleportation_portal_enter(evt : EventZoneEnter;
                               eid aka entry_portal_eid : EntityId;
                               teleportation_portal__linkedPortal : EntityId;
                               teleportation_portal__onTeleportEffect : string;
                               transform aka enter_portal_transform : float3x4;
                               teleportation_portal__teleportedEntities : EidList)
  if has_value(teleportation_portal__teleportedEntities, evt.visitorEid)
    print("[TELEPORTATION PORTAL] Already teleported <{evt.visitorEid}>")
    return
  query(evt.visitorEid) <| $ [es] (transform aka visitor_transform : float3x4;
                                   var zones_visitor__disabled : bool&;
                                   var phys_obj_net_phys : PhysObjActor?;
                                   var human_net_phys : HumanActor?;
                                   teleportation__once : Tag const?)
    if human_net_phys != null
      let isPlayerControlled = is_server() && (*human_net_phys).role == NetRole.ROLE_REMOTELY_CONTROLLED_AUTHORITY
      // Only client can initiate teleportation of the entity they are controlling
      // TODO: check if player has disconnected and apply server-side logic
      if isPlayerControlled
        return
    query(teleportation_portal__linkedPortal) <| $ [es] (transform aka exit_portal_transform : float3x4;
                                                         teleportation_portal__exitOffset : float;
                                                         teleportation_portal__isBidirectional : bool;
                                                         teleportation_portal__safeLocalExitDir : float3;
                                                         var teleportation_portal__teleportedEntities : EidList)
      var enterTm = enter_portal_transform
      orthonormalize(enterTm)
      let invEnterTm = inverse(enterTm)
      var exitTm = exit_portal_transform
      orthonormalize(exitTm)
      var targetTm = exitTm * (invEnterTm * visitor_transform)
      let oldTm = visitor_transform

      if phys_obj_net_phys != null
        assume velocity = (*phys_obj_net_phys).phys.currentState.velocity
        velocity = rotate(exitTm, (rotate(invEnterTm, velocity)))

      if human_net_phys != null
        assume state = (*human_net_phys).phys.currentState

        assume velocity = state.velocity
        velocity = rotate(exitTm, (rotate(invEnterTm, velocity)))

        if length_sq(teleportation_portal__safeLocalExitDir) > FLT_EPSILON // safe dir is set
          targetTm[3] += normalize((float3x3(exitTm) * teleportation_portal__safeLocalExitDir)) * teleportation_portal__exitOffset
        elif teleportation_portal__isBidirectional
          let fixDirection = normalize(exitTm[0])

          var dt = dot(fixDirection, velocity)
          if abs(dt) < 0.001
            let fwdDir = normalize(exitTm[3] - targetTm[3])
            dt = dot(fixDirection, fwdDir)

          if dt < 0.0
            targetTm[3] -= fixDirection * teleportation_portal__exitOffset
          else
            targetTm[3] += fixDirection * teleportation_portal__exitOffset
        else
          let up = normalize(exitTm[1])
          targetTm[3] += normalize(velocity - up * dot(normalize(velocity), up)) * teleportation_portal__exitOffset
        state.gravDirection = get_grav_dir(targetTm[3], true)
        state.vertDirection = -state.gravDirection

      teleport_phys_actor(evt.visitorEid, targetTm)

      if !has_value(teleportation_portal__teleportedEntities, evt.visitorEid)
        push(teleportation_portal__teleportedEntities, evt.visitorEid)
      createEntity(teleportation_portal__onTeleportEffect) <| $(var init)
        init |> set("game_effect__attachedTo", evt.visitorEid)
        init |> set("teleportation_cooldown_effect__attachedTeleport", teleportation_portal__linkedPortal)

      let isGameClientControlled = !is_server() && (*human_net_phys).role == NetRole.ROLE_LOCALLY_CONTROLLED_SHADOW
      if isGameClientControlled
        print("[TELEPORTATION PORTAL] Client teleport for <{evt.visitorEid}>: <{oldTm[3]}> -> <{targetTm[3]}>")
        send_net_event(evt.visitorEid, EventClientTeleportedEntity(newTm = targetTm, oldTm = oldTm, entryPortal = entry_portal_eid, atTick = (*human_net_phys).phys.currentState.atTick))
      else
        print("[TELEPORTATION PORTAL] Server teleport for <{evt.visitorEid}>: <{oldTm[3]}> -> <{targetTm[3]}>")

      if teleportation__once != null
        zones_visitor__disabled = true

      evt.visitorEid |> send_net_event(EventPortalTeleportEntity(newTm = targetTm, oldTm = oldTm))
      enable_confusion_affect(evt.visitorEid, 1.0, 1.0, 0.2)



[es(tag=server)]
def server_acknoledge_teleport_from_client(evt : EventClientTeleportedEntity;
                                           eid aka hero_eid : EntityId;
                                           transform aka hero_transform : float3x4;
                                           var human_net_phys : HumanActor&)
  var allowTeleport = false
  var disallowReason = ""
  query(evt.entryPortal) <| $ [es] (teleportation_portal__linkedPortal : EntityId;
                                    transform aka entry_transform : float3x4;
                                    teleportation_portal__clientEntryClearance : float)
    query(teleportation_portal__linkedPortal) <| $ [es] (transform aka exit_transform : float3x4; teleportation_portal__clientExitClearance : float)
      if distance_sq(entry_transform[3], hero_transform[3]) > square(teleportation_portal__clientEntryClearance)
        disallowReason = "dist(entry, hero) too big ({distance(entry_transform[3], hero_transform[3])})"
        return
      if distance_sq(entry_transform[3], evt.oldTm[3]) > square(teleportation_portal__clientEntryClearance)
        disallowReason = "dist(entry, old) too big ({distance(entry_transform[3], evt.oldTm[3])})"
        return
      if distance_sq(evt.oldTm[3], hero_transform[3]) > square(teleportation_portal__clientEntryClearance)
        disallowReason = "dist(old, hero) too big ({distance(evt.oldTm[3], hero_transform[3])})"
        return
      if distance_sq(exit_transform[3], evt.newTm[3]) > square(teleportation_portal__clientExitClearance)
        disallowReason = "dist(exit, new tm) too big ({distance(evt.newTm[3], exit_transform[3])})"
        return
      allowTeleport = true

  if !allowTeleport
    logwarn("[TELEPORTATION PORTAL] Disallow teleport for <{hero_eid}>({hero_transform[3]}) via <{evt.entryPortal}>: clientTick={evt.atTick} serverTick={human_net_phys.phys.currentState.atTick} <{evt.oldTm[3]}> -> <{evt.newTm[3]}> (\"{disallowReason}\")")
    return

  print("[TELEPORTATION PORTAL] Allow teleport for <{hero_eid}> via <{evt.entryPortal}>: clientTick={evt.atTick} serverTick={human_net_phys.phys.currentState.atTick} <{evt.oldTm[3]}> -> <{evt.newTm[3]}>")
  human_net_phys |> human_actor_teleportTo(evt.newTm, true)

  assume state = human_net_phys.phys.currentState
  state.gravDirection = get_grav_dir(evt.newTm[3], true)
  state.vertDirection = -state.gravDirection

  assume velocity = state.velocity
  let invEnterTm = inverse(evt.oldTm)
  velocity = rotate(evt.newTm, (rotate(invEnterTm, velocity)))
  human_net_phys |> base_phys_actor_resetAAS()


[es(tag=gameClient, REQUIRE=hero, no_order)]
def teleportation_portal_enter_client_via_capsule_bbox(update : UpdateStageInfoAct;
                                                       eid aka hero_eid : EntityId;
                                                       transform aka hero_transform : float3x4;
                                                       collres : CollisionResource)
  var foundTeleport = false
  let bbox3 = BBox3(collres.vFullBBox)
  let bsphere = BSphere3(hero_transform * bbox3)

  gather_entities_in_grid(ecs_hash("zones"), bsphere, GridEntCheck.BOUNDING) <| $(zones)
    for zone in zones
      query(zone) <| $ [es(REQUIRE=(box_zone, teleportation_portal__linkedPortal))] (transform aka teleport_transform : float3x4;
                                                                                     zone__active : bool = true)
        if !zone__active
          return

        if check_bbox3_intersection(bbox3, hero_transform, IDENT_BBOX, teleport_transform)
          foundTeleport = true
          sendEvent(zone, EventZoneEnter(visitorEid = hero_eid))

      if foundTeleport
        break


[es(tag=gameClient)]
def teleportation_portal_fx(evt : EventPortalTeleportEntity;
                            teleportation__fxNameIn, teleportation__fxNameOut : string;
                            teleportation__fxOffset : float3 = float3(0.0, 0.0, 0.0);
                            collres : CollisionResource const?)
  var scale = 1.0
  if collres != null
    let bbox = BBox3((*collres).vFullBBox)
    scale = max(bbox.width.x, bbox.width.y, bbox.width.z)
  var tm = scale_tm(scale)
  createEntity(teleportation__fxNameIn) <| $(var init)
    tm[3] = evt.oldTm * teleportation__fxOffset
    init |> set("transform", tm)
  createEntity(teleportation__fxNameOut) <| $(var init)
    tm[3] = evt.newTm * teleportation__fxOffset
    init |> set("transform", tm)


[es(tag=gameClient, on_appear)]
def teleportation_portal_visual_init(evt : Event;
                                     teleportation_portal_dynmodel__owner : EntityId;
                                     var target_transform : float3x4&)
  query(teleportation_portal_dynmodel__owner) <| $ [es] (teleportation_portal__linkedPortal : EntityId)
    query(teleportation_portal__linkedPortal) <| $ [es] (transform aka other_transform : float3x4)
      target_transform = other_transform


[es(tag=gameClient, REQUIRE=watchedByPlr, on_disappear)]
def teleportation_portal_disappear_visual_effects_for_hero(evt : Event)
  query() <| $ [es] (var teleportation_portal__effectEid : EntityId&)
    if teleportation_portal__effectEid != INVALID_ENTITY_ID
      destroyEntity(teleportation_portal__effectEid)
      teleportation_portal__effectEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_disappear)]
def teleportation_portal_disappear_visual_effects_on_remove(evt : Event; teleportation_portal__effectEid : EntityId)
  destroyEntity(teleportation_portal__effectEid)


[es(tag=gameClient, REQUIRE=watchedByPlr, no_order)]
def teleportation_portal_update_visual_effects(act : ParallelUpdateFrameDelayed;
                                               transform aka hero_transform : float3x4)
  let showEffectDistSq = square(50.0)
  let hideEffectDistSq = square(70.0)

  query() <| $ [es] (transform aka portal_transform : float3x4;
                     teleportation_portal__effectName : string;
                     teleportation_portal__effectScale : float3 = float3(1.0);
                     var teleportation_portal__effectEid : EntityId&)
    let effectExists = teleportation_portal__effectEid != INVALID_ENTITY_ID

    let needCreateEffect = distance_sq(hero_transform[3], portal_transform[3]) < showEffectDistSq
    let needDestroyEffect = distance_sq(hero_transform[3], portal_transform[3]) > hideEffectDistSq

    if needCreateEffect && !effectExists
      teleportation_portal__effectEid = createEntity(teleportation_portal__effectName) <| $(var init)
        init |> set("transform", portal_transform * scale_tm(teleportation_portal__effectScale))
    elif needDestroyEffect && effectExists
      destroyEntity(teleportation_portal__effectEid)
      teleportation_portal__effectEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_appear)]
def teleportation_portal_create_dynmodel(evt : Event;
                                         eid : EntityId;
                                         teleportation_portal__dynmodelName : string;
                                         teleportation_portal__effectScale : float3 = float3(1.0);
                                         transform aka teleport_transform : float3x4;
                                         var teleportation_portal__dynmodelEid : EntityId&)
  if !empty(teleportation_portal__dynmodelName)
    teleportation_portal__dynmodelEid = createEntity(teleportation_portal__dynmodelName) <| $(var init)
      set(init, "teleportation_portal_dynmodel__owner", eid)
      set(init, "transform", teleport_transform * scale_tm(teleportation_portal__effectScale))


[es(tag=gameClient, on_disappear)]
def teleportation_portal_destroy_dynmodel(evt : Event;
                                          teleportation_portal__dynmodelEid : EntityId)
  destroyEntity(teleportation_portal__dynmodelEid)


[es(track=level__allLoadedTime, on_event=EventRetriggerEntity)]
def validate_teleportation_portals(evt : Event; level__allLoadedTime : float)
  if level__allLoadedTime > .0
    query() <| $ [es] (transform aka p1_transform : float3x4;
                       eid, teleportation_portal__linkedPortal : EntityId;
                       teleportation_portal__skipOrientationCheck = false)
      if uint(eid) > uint(teleportation_portal__linkedPortal) && !teleportation_portal__skipOrientationCheck
        query(teleportation_portal__linkedPortal) <| $ [es] (transform aka p2_transform : float3x4; teleportation_portal__skipOrientationCheck = false)
          if !teleportation_portal__skipOrientationCheck
            let gravity1 = get_grav_dir(p1_transform[3])
            let gravity2 = get_grav_dir(p2_transform[3])
            let v1 = normalize(p1_transform[1])
            let v2 = normalize(p2_transform[1])
            let diff = abs(dot(gravity1, v1) - dot(gravity2, v2))
            if diff > 0.5
              logerr("Teleportation portal incorrecly placed, probably upside-down. Problematic pair: {p1_transform[3]} <=> {p2_transform[3]}\nTheir gravs: {gravity1} <=> {gravity2}.\nTheir verticals: {v1} <=> {v2}, diff:{diff} = {dot(gravity1, v1)} - {dot(gravity2, v2)}")
