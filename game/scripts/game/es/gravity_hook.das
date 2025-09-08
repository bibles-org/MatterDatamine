require ecs
require app
require Dacoll
require game.events.events_game
require math.base
require DngHuman
require DagorMath
require game.events.events_active_matter
require game.events.events
require math.linear
require AnimV20
require DaWeaponProps
require DngNet
require game.es.grav_zones_common
require DagorMathUtils


def make_effect_tm(var tm : float3x4; dir, pos : float3)
  tm[1] = normalize(dir)
  tm[0] = get_normal(tm[1])
  tm[2] = cross(tm[1], tm[0])
  tm[3] = pos


[es(tag=server, on_appear, REQUIRE=gravity_hook_bullet)]
def on_gravity_hook_usage(evt : Event;
                          transform : float3x4;
                          var gravity_hook__shootPos : float3&)
  gravity_hook__shootPos = transform[3]


[es(tag=server, REQUIRE=gravity_hook_bullet)]
def gravity_hook_hit(evt : CmdShellExplode;
                     eid : EntityId;
                     gravity_hook__zoneTemplate : string;
                     gravity_hook__heightOffset : float;
                     gravity_hook__maxDistance : float;
                     gravity_hook__shootPos : float3;
                     shell__owner : EntityId)
  if distance_sq(gravity_hook__shootPos, evt.position) > square(gravity_hook__maxDistance)
    destroyEntity(eid)
    return // too far
  // check other hook
  let inter = find_query() <| $ [es(REQUIRE=gravity_hook_zone)] (gravity_hook_zone__itm : float3x4;
                                                                 gravity_hook_zone__height : float;
                                                                 gravity_hook_zone__radius : float)
    let locStart = gravity_hook_zone__itm * gravity_hook__shootPos
    let locEnd = gravity_hook_zone__itm * evt.position
    let locDir = locEnd - locStart
    if length_sq(locDir.xz) < FLT_EPSILON // parallel
      return !((locStart.y < 0.0f && locEnd.y < 0.0f) ||
                (locStart.y > gravity_hook_zone__height && locEnd.y > gravity_hook_zone__height) ||
                length_sq(locStart.xz) > square(2.0f * gravity_hook_zone__radius))
    else
      let zoneDir = float3(0.f, gravity_hook_zone__height, 0.f)
      let normal = cross(locDir, zoneDir)
      let localT = dot(-locStart, cross(locDir, normal)) / length_sq(normal)
      let zoneT = dot(-locStart, cross(zoneDir, normal)) / length_sq(normal)
      if zoneT >= 0.0 && zoneT <= 1.0 && localT >= 0.0 && localT <= 1.0
        return dot(locStart, normal) / length(normal) < 2.0f * gravity_hook_zone__radius
      else
        let maxSq = square(2.0f * gravity_hook_zone__radius)
        return (distance_sq_to_seg(locStart, float3(), zoneDir) < maxSq ||
                distance_sq_to_seg(locEnd, float3(), zoneDir) < maxSq ||
                distance_sq_to_seg(float3(), locStart, locEnd) < maxSq ||
                distance_sq_to_seg(zoneDir, locStart, locEnd) < maxSq)
  if inter
    return

  // create zone
  let toOwnerDir = gravity_hook__shootPos - evt.position
  var tm = IDENT_TM
  tm[1] = normalize(toOwnerDir)
  tm[0] = get_normal(tm[1])
  tm[2] = normalize(cross(tm[0], tm[1]))
  tm[3] = evt.position
  createEntity(gravity_hook__zoneTemplate) <| $(var init)
    init |> set("transform", tm)
    init |> set("gravity_hook_zone__height", length(toOwnerDir) + gravity_hook__heightOffset)
    init |> set("gravity_hook_zone__heightOffset", gravity_hook__heightOffset)
    init |> set("gravity_hook_zone__itm", inverse(tm))
    init |> set("gravity_hook_zone__ownerEid", shell__owner)
  destroyEntity(eid)


[es(tag=server, REQUIRE=gravity_hook_zone, after=update_grav_direction_in_hook_zone)]
def update_gravity_hook_zone(act : ParallelUpdateFrameDelayed;
                             eid aka zone_eid : EntityId;
                             transform : float3x4;
                             gravity_hook_zone__ownerEid : EntityId;
                             gravity_hook_zone__destroyTime : float;
                             gravity_hook_zone__minDistance : float;
                             gravity_hook_zone__heightOffset : float;
                             gravity_hook_zone__tickDelay : int;
                             var gravity_hook_zone__height : float&;
                             var gravity_hook_zone__timer : float&)
  query(gravity_hook_zone__ownerEid) <| $ [es] (human_net_phys : HumanActor;
                                                gravity_hook__effectEid : EntityId = INVALID_ENTITY_ID;
                                                deadEntity : Tag const?)
    var destroy = false
    query(gravity_hook__effectEid) <| $ [es] (gravity_hook_effect__zoneEid : EntityId;
                                              gravity_hook_effect__tickEnd : int)
      if gravity_hook_effect__zoneEid == zone_eid
        destroy = gravity_hook_effect__tickEnd >= 0
        if destroy
          return
        let pos = float3(human_net_phys.phys.currentState.location.P)
        if !(length_sq(human_net_phys.phys.currentState.velocity) < FLT_EPSILON ||
              gravity_hook_zone__minDistance >= gravity_hook_zone__height - gravity_hook_zone__heightOffset)
          gravity_hook_zone__height = length(transform[3] - pos) + gravity_hook_zone__heightOffset
          gravity_hook_zone__timer = 0.0f
    gravity_hook_zone__timer += act.dt
    if deadEntity != null || gravity_hook_zone__timer >= gravity_hook_zone__destroyTime || destroy
      var cnt = 0
      query() <| $ [es] (eid aka effect_eid : EntityId;
                         game_effect__attachedTo : EntityId;
                         gravity_hook_effect__zoneEid : EntityId;
                         var gravity_hook_effect__tickEnd : int&)
        if gravity_hook_effect__zoneEid != zone_eid
          return
        query(game_effect__attachedTo) <| $ [es] (human_net_phys aka effect_human_net_phys : HumanActor)
          if gravity_hook_effect__tickEnd <= 0
            gravity_hook_effect__tickEnd = effect_human_net_phys.phys.currentState.atTick + gravity_hook_zone__tickDelay
          elif effect_human_net_phys.phys.currentState.atTick > gravity_hook_effect__tickEnd
            destroyEntity(effect_eid)
            return
          cnt += 1
      if cnt == 0
        destroyEntity(zone_eid)


[es(tag=server, REQUIRE=grav_zones_affected, before=human_phys_es, REQUIRE_NOT=disableUpdate)]
def check_gravity_hook_zone(evt : CmdPostPhysUpdate;
                            eid aka human_eid : EntityId;
                            var human_net_phys : HumanActor;
                            gravity_hook__effectEid : EntityId = INVALID_ENTITY_ID)
  assume state = human_net_phys.phys.currentState
  let physPos = float3(state.location.P)
  let inZone = find_query() <| $ [es(REQUIRE=gravity_hook_zone)] (eid aka zone_eid : EntityId;
                                                                  gravity_hook_zone__tickDelay : int;
                                                                  gravity_hook_zone__effectTemplate : string;
                                                                  gravity_hook_zone__itm : float3x4;
                                                                  gravity_hook_zone__height : float;
                                                                  gravity_hook_zone__radius : float)
    let localCoord = gravity_hook_zone__itm * physPos
    if (localCoord.y <= gravity_hook_zone__height && localCoord.y >= 0.f &&
        length_sq(localCoord.xz) <= square(gravity_hook_zone__radius))
      if gravity_hook__effectEid == INVALID_ENTITY_ID // enter
        let effectEid = createEntity(gravity_hook_zone__effectTemplate) <| $(var init)
          init |> set("game_effect__attachedTo", human_eid)
          init |> set("gravity_hook_effect__zoneEid", zone_eid)
          init |> set("gravity_hook_effect__tickStart", evt.tick + gravity_hook_zone__tickDelay)
        addSubTemplate(human_eid, "in_gravity_hook_zone") <| $(var init)
          init |> set("gravity_hook__effectEid", effectEid)
        human_eid |> send_net_event(EventEnterGravityHookZone(effectEid = effectEid))
      return true
    return false
  if !inZone && gravity_hook__effectEid != INVALID_ENTITY_ID // exit
    destroyEntity(gravity_hook__effectEid)
    human_eid |> removeSubTemplate("in_gravity_hook_zone")
    human_eid |> send_net_event(EventLeaveGravityHookZone())
    state.velocity = float3(0.f)

[es(tag=gameClient)]
def on_gravity_hook_zone_enter(evt : EventEnterGravityHookZone;
                               eid : EntityId)
  addSubTemplate(eid, "in_gravity_hook_zone") <| $(var init)
    init |> set("gravity_hook__effectEid", evt.effectEid)


[es(tag=gameClient)]
def on_gravity_hook_zone_leave(evt : EventLeaveGravityHookZone;
                               eid : EntityId;
                               var human_net_phys : HumanActor)
  human_net_phys.phys.currentState.velocity = float3(0.f)
  removeSubTemplate(eid, "in_gravity_hook_zone")


[es(after=check_gravity_hook_zone, before=before_net_phys_sync, REQUIRE_NOT=deadEntity)]
def update_grav_direction_in_hook_zone(evt : CmdPostPhysUpdate;
                                       gravity_hook__effectEid : EntityId;
                                       human_net_phys__isInAir : bool;
                                       var human_net_phys : HumanActor;
                                       var animchar : AnimcharBaseComponent)
  query(gravity_hook__effectEid) <| $ [es] (gravity_hook_effect__zoneEid : EntityId;
                                            gravity_hook_effect__pushTime : float;
                                            gravity_hook_effect__pushLength : float;
                                            gravity_hook_effect__tickStart : int;
                                            gravity_hook_effect__tickEnd : int;
                                            var gravity_hook_effect__time : float&)
    if (evt.tick < gravity_hook_effect__tickStart ||
        (evt.tick > gravity_hook_effect__tickEnd && gravity_hook_effect__tickEnd > 0))
      // zone is not exists, use standart logic
      assume state = human_net_phys.phys.currentState
      let physPos = float3(state.location.P)
      state.gravDirection = get_grav_dir(physPos)
      animchar |> animchar_setFastPhysSystemGravityDirection(state.gravDirection)
      return
    query(gravity_hook_effect__zoneEid) <| $ [es] (transform : float3x4;
                                                   gravity_hook_zone__itm : float3x4)
      if human_net_phys__isInAir && evt.tick - gravity_hook_effect__tickStart == 0
        gravity_hook_effect__time = gravity_hook_effect__pushTime + evt.dt
      elif gravity_hook_effect__time < gravity_hook_effect__pushTime + evt.dt
        gravity_hook_effect__time = float(evt.tick - gravity_hook_effect__tickStart) * evt.dt

      assume state = human_net_phys.phys.currentState
      if gravity_hook_effect__time < gravity_hook_effect__pushTime
        let localCoord = gravity_hook_zone__itm * float3(state.location.P)
        let len = gravity_hook_effect__pushLength * (1.f - gravity_hook_effect__time / gravity_hook_effect__pushTime)
        let toPos = transform * float3(0.0f, localCoord.y - len, 0.0f)
        let pushDir = (toPos - float3(state.location.P)) / gravity_hook_effect__pushTime
        state.velocity = pushDir
      else
        if gravity_hook_effect__time - evt.dt < gravity_hook_effect__pushTime
          state.velocity = float3(0)
        state.gravDirection = normalize(-transform[1])
        animchar |> animchar_setFastPhysSystemGravityDirection(state.gravDirection)


[es(tag=input, before=human_input_es, REQUIRE=(hero, gravity_hook__effectEid), REQUIRE_NOT=deadEntity)]
def update_camera_in_hook_zone(info : UpdateStageUpdateInput;
                               human_net_phys__prevRootDir : float3;
                               human_net_phys__prevVertDir : float3;
                               human_net_phys : HumanActor;
                               var human_input__aimAngle : float2&)
  let curVertDirection = human_net_phys.phys.currentState.vertDirection
  let prevVertDirection = human_net_phys.phys.previousState.vertDirection
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, get_sync_time())
  let rotationBetweenStates = quat_rotation_arc(prevVertDirection, curVertDirection)
  let identQuat = quat(0.f, 0.f, 0.f, 1.f)
  let interpQuat = slerp(identQuat, rotationBetweenStates, interpK)

  let prevVert = human_net_phys__prevVertDir
  let prevRoot = human_net_phys__prevRootDir

  let curVert = interpQuat * prevVertDirection
  let curRoot = quat_rotation_arc(prevVert, curVert) * prevRoot

  let backRotation = quat_rotation_arc(curVert, prevVert)
  let curLook = basis_aware_angles_to_dir(human_input__aimAngle, curVert, curRoot)

  let adjustLook = backRotation * curLook
  human_input__aimAngle = basis_aware_dir_to_angles(adjustLook, curVert, curRoot)


[es(tag=gameClient, on_appear)]
def create_hook_zone_effect(evt : Event;
                            gravity_hook_zone__effect : string;
                            gravity_hook_zone__effectStep : float;
                            gravity_hook_zone__height : float;
                            var gravity_hook_zone__effectEids : EidList;
                            transform : float3x4)
  var currentOffset = 0.f
  let dir = transform[1]
  var effectTm = IDENT_TM
  make_effect_tm(effectTm, -dir, float3(0.f))
  while currentOffset < gravity_hook_zone__height
    effectTm[3] = transform[3] + dir * (currentOffset + gravity_hook_zone__effectStep)
    let new_eid = createEntity(gravity_hook_zone__effect) <| $(var init)
      init |> set("transform", effectTm)
    gravity_hook_zone__effectEids |> push(new_eid)
    currentOffset += gravity_hook_zone__effectStep


[es(tag=gameClient, no_order)]
def manage_hook_zone_effect(act : ParallelUpdateFrameDelayed;
                            gravity_hook_zone__height : float;
                            var gravity_hook_zone__effectEids : EidList;
                            gravity_hook_zone__effectStep : float;
                            transform aka zone_transform : float3x4)
  let farestEid = gravity_hook_zone__effectEids |> back()
  query(farestEid) <| $ [es] (transform aka effect_transform : float3x4)
    if distance_sq(zone_transform[3], effect_transform[3]) > square(gravity_hook_zone__height + gravity_hook_zone__effectStep)
      destroyEntity(farestEid)
      gravity_hook_zone__effectEids |> pop()


[es(tag=gameClient, on_disappear)]
def destroy_hook_zone_effect(evt : Event;
                             gravity_hook_zone__effectEids : EidList)
  for effectEid in gravity_hook_zone__effectEids
    destroyEntity(effectEid)