require ecs
require app
require net
require math.base
require math.random
require math.linear
require DagorMath
require DagorRandom
require DagorSystem
require DagorDebug3D
require Grid
require AnimV20
require GeomNodeTree
require DngDm
require HumanPhys
require GamePhys
require DngHuman
require pathfinder
require game.events.events_active_matter
require game.es.am_core_warrior_common


[es(tag=server)]
def remove_core_warriors_on_parent_core_death(evt : EventAmCoreExhausted;
                                              eid : EntityId;
                                              am_core_warrior__parentEid : EntityId;
                                              am_core_warrior__exhaustedTemplate : string;
                                              transform : float3x4)
  if evt.eid == am_core_warrior__parentEid
    destroyEntity(eid)
    createEntity(am_core_warrior__exhaustedTemplate) <| $(init)
      init |> set("transform", transform)


[es(tag=server, no_order)]
def protected_core_warrior_update(act : ParallelUpdateFrameDelayed;
                                  eid aka core_eid : EntityId;
                                  protected_by_warriors__agroRadius : float;
                                  protected_by_warriors__origin : float3;
                                  protected_by_warriors__interval : float;
                                  protected_by_warriors__enabled : bool;
                                  protected_by_warriors__warriorsPerTarget : int;
                                  var protected_by_warriors__targetsPos : Point3List;
                                  var protected_by_warriors__targetEids : EidList;
                                  var protected_by_warriors__hasAgro : bool&;
                                  var protected_by_warriors__updateAt : float&)
  if act.curTime > protected_by_warriors__updateAt
    if protected_by_warriors__enabled
      protected_by_warriors__updateAt = act.curTime + protected_by_warriors__interval
      let sphere = BSphere3(protected_by_warriors__origin, protected_by_warriors__agroRadius)
      let hadAgro = protected_by_warriors__hasAgro
      protected_by_warriors__hasAgro = false
      clear(protected_by_warriors__targetsPos)
      var currentTargetEids : array<EntityId>
      for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(target_eid : EntityId)
        query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys, heroForPlayer))] (transform : float3x4)
          protected_by_warriors__targetsPos |> push(transform[3])
          currentTargetEids |> push(target_eid)
          protected_by_warriors__hasAgro = true

      // Remove obsolete targets
      for prevTargetEid in protected_by_warriors__targetEids
        if !(currentTargetEids |> has_value(prevTargetEid))
          query() <| $ [es] (am_core_warrior__parentEid : EntityId;
                             var am_core_warrior__targetEid : EntityId&)
            if am_core_warrior__parentEid == core_eid
              if am_core_warrior__targetEid == prevTargetEid
                am_core_warrior__targetEid = INVALID_ENTITY_ID

      // Process new targets
      protected_by_warriors__targetEids |> clear()
      if length(currentTargetEids) > 0
        var freeWarriors : array<EntityId>
        var warriorsPerTarget : table<uint; int>
        query() <| $ [es] (eid aka warrior_eid : EntityId;
                           am_core_warrior__parentEid : EntityId;
                           am_core_warrior__targetEid : EntityId)
          if am_core_warrior__parentEid == core_eid
            if am_core_warrior__targetEid == INVALID_ENTITY_ID
              freeWarriors |> push(warrior_eid)
            else
              warriorsPerTarget[uint(am_core_warrior__targetEid)]++

        for currentTargetEid in currentTargetEids
          protected_by_warriors__targetEids |> push(currentTargetEid)
          let warriorsPerCurrentTarget = warriorsPerTarget[uint(currentTargetEid)]
          if (warriorsPerCurrentTarget < protected_by_warriors__warriorsPerTarget &&
              length(freeWarriors) > 0)
            let warriorIdx = length(freeWarriors) - 1
            query(freeWarriors[warriorIdx]) <| $ [es] (var am_core_warrior__targetEid : EntityId&)
              am_core_warrior__targetEid = currentTargetEid
              freeWarriors |> erase(warriorIdx)


      if !hadAgro && protected_by_warriors__hasAgro
        query() <| $ [es(REQUIRE_NOT=am_core_warrior__triggered)] (eid aka warrior_eid, am_core_warrior__parentEid : EntityId)
          if am_core_warrior__parentEid == core_eid
            sendEvent(warrior_eid, EventAmCoreAgroed())


[es(tag=server, track=protected_by_warriors__enabled)]
def protected_core_warrior_track_enabled(evt : Event;
                                         eid aka core_eid : EntityId;
                                         transform aka core_transform : float3x4;
                                         protected_by_warriors__origin : float3;
                                         protected_by_warriors__enabled : bool;
                                         protected_by_warriors__spawnRadius : float;
                                         var protected_by_warriors__hasAgro : bool&)
  protected_by_warriors__hasAgro = false
  query() <| $ [es] (eid aka warrior_eid : EntityId;
                     am_core_warrior__parentEid : EntityId;
                     am_core_warrior__triggeredTemplate : string;
                     var am_core_warrior__state : int&;
                     var am_core_warrior__travelPath : Point3List;
                     var am_core_warrior__moveTimeOffset : float&;
                     var transform aka warrior_transform : float3x4)
    if am_core_warrior__parentEid == core_eid
      if !protected_by_warriors__enabled
        am_core_warrior__state = int(CoreWarriorState.HIDING)
      else
        am_core_warrior__state = int(CoreWarriorState.TRAVEL)
        var rndDir = rnd_dir3()
        if rndDir. y < 0.0
          rndDir.y = -rndDir.y

        warrior_transform[3] = core_transform[3]
        am_core_warrior__travelPath |> resize(1)
        am_core_warrior__travelPath[0] = protected_by_warriors__origin + rndDir * protected_by_warriors__spawnRadius
        am_core_warrior__moveTimeOffset = 0.0
        send_net_event(eid, CmdSetCoreWarriorTravelPath(path = ecs_addr(am_core_warrior__travelPath)))
      addSubTemplate(warrior_eid, am_core_warrior__triggeredTemplate)


[es(tag=server, on_event=EventAmCoreAgroed)]
def core_warrior_on_parent_agroed(evt : Event;
                                  eid : EntityId;
                                  am_core_warrior__triggeredTemplate : string;
                                  am_core_warrior__restTime : float2;
                                  am_core_warrior__travelCooldown : float2;
                                  var am_core_warrior__actAt : float&;
                                  var am_core_warrior__travelAt : float&;
                                  var am_core_warrior__state : int&)
  addSubTemplate(eid, am_core_warrior__triggeredTemplate)
  am_core_warrior__actAt = get_sync_time() + rnd_float(am_core_warrior__restTime)
  if am_core_warrior__state == int(CoreWarriorState.IDLE)
    am_core_warrior__state = int(CoreWarriorState.REST)
  am_core_warrior__travelAt = am_core_warrior__actAt + rnd_float(am_core_warrior__travelCooldown)


def try_initiate_target_chasing_travel(warrior_eid : EntityId)
  var success = false
  query(warrior_eid) <| $ [es] (transform aka warrior_transform : float3x4;
                                am_core_warrior__targetEid : EntityId;
                                am_core_warrior__parentEid : EntityId;
                                am_core_warrior__agroRadius : float;
                                var am_core_warrior__travelPath : Point3List)
    query(am_core_warrior__parentEid) <| $ [es] (protected_by_warriors__origin : float3;
                                                 protected_by_warriors__agroRadius : float)
      let huntingSphereRadius = am_core_warrior__agroRadius * 0.75
      let maxHuntingSphereOffset = max(protected_by_warriors__agroRadius - huntingSphereRadius, 0.0)
      query(am_core_warrior__targetEid) <| $ [es] (transform aka target_transform : float3x4)
        let targetPosition = target_transform[3] + float3(0.0, 1.0, 0.0)
        let coreToTarget = targetPosition - protected_by_warriors__origin
        let coreToTargetDistance = length(coreToTarget)
        if coreToTargetDistance < 1e-3
          return

        let coreToTargetDirection = coreToTarget / coreToTargetDistance
        let huntingSpherePosition = protected_by_warriors__origin + coreToTargetDirection * min(maxHuntingSphereOffset, coreToTargetDistance)

        var huntintPointDirection = rnd_dir3()
        if huntintPointDirection.y < 0.0
          huntintPointDirection.y = -huntintPointDirection.y

        let huntingPoint = huntingSpherePosition + huntintPointDirection * rnd_float(0.0, huntingSphereRadius)

        var maxAttempts = 3
        while maxAttempts-- > 0
          find_core_warrior_straight_path(warrior_transform[3], huntingPoint, am_core_warrior__travelPath)
          if length(am_core_warrior__travelPath) > 0
            success = true
            return

          find_core_warrior_arc_path(warrior_transform[3], huntingPoint, am_core_warrior__travelPath)
          if length(am_core_warrior__travelPath) > 0
            success = true
            return

  return success


def try_initiate_warrior_travel(warrior_eid : EntityId)
  var parentEid : EntityId
  query(warrior_eid) <| $ [es] (am_core_warrior__parentEid : EntityId)
    parentEid = am_core_warrior__parentEid
  var success = false
  var positions : array<float3>
  query() <| $ [es] (eid : EntityId;
                     am_core_warrior__origin : float3;
                     am_core_warrior__travelPath : Point3List;
                     am_core_warrior__parentEid : EntityId)
    if warrior_eid != eid && am_core_warrior__parentEid == parentEid
      if length(am_core_warrior__travelPath) > 0
        positions |> push(am_core_warrior__travelPath[length(am_core_warrior__travelPath) - 1])
      else
        positions |> push(am_core_warrior__origin)

  query(warrior_eid) <| $ [es] (transform : float3x4; am_core_warrior__elevationRnd : float2; var am_core_warrior__travelPath : Point3List)
    query(parentEid) <| $ [es] (protected_by_warriors__spawnRadius : float;
                                protected_by_warriors__minProximity : float;
                                protected_by_warriors__travelToBestOutOf : int;
                                protected_by_warriors__targetsPos : Point3List;
                                protected_by_warriors__origin : float3)
      if length(protected_by_warriors__targetsPos) == 0
        return
      let startingLength = length(positions)
      add_core_warrior_spawn_positions(protected_by_warriors__origin,
                                      protected_by_warriors__spawnRadius,
                                      protected_by_warriors__minProximity,
                                      protected_by_warriors__travelToBestOutOf,
                                      protected_by_warriors__travelToBestOutOf * 4,
                                      positions)
      let elevation = float3(0.0, rnd_float(am_core_warrior__elevationRnd), 0.0)
      var destinations : array<tuple<pos : float3; dst : float>>
      for pIdx in range(startingLength, length(positions))
        var minDstSq = FLT_MAX
        for tp in protected_by_warriors__targetsPos
          minDstSq = min(minDstSq, distance_sq(positions[pIdx] + elevation, tp))
        destinations |> emplace((positions[pIdx] + elevation, minDstSq))
      destinations |> sort() <| $(a, b)
        return a.dst < b.dst
      var maxAttempts = 3
      while maxAttempts-- > 0 && length(destinations) > 0

        find_core_warrior_straight_path(transform[3], destinations[0].pos, am_core_warrior__travelPath)
        if length(am_core_warrior__travelPath) > 0
          success = true
          return

        find_core_warrior_arc_path(transform[3], destinations[0].pos, am_core_warrior__travelPath)
        if length(am_core_warrior__travelPath) > 0
          success = true
          return

  return success

def go_to_rest_or_idle(am_core_warrior__parentEid : EntityId;
                       eid : EntityId;
                       am_core_warrior__triggeredTemplate : string;
                       am_core_warrior__restTime : float2;
                       var am_core_warrior__actAt : float&;
                       var am_core_warrior__state : int&)
  query(am_core_warrior__parentEid) <| $ [es] (protected_by_warriors__hasAgro : bool)
    if protected_by_warriors__hasAgro
      am_core_warrior__actAt = get_sync_time() + rnd_float(am_core_warrior__restTime)
      am_core_warrior__state = int(CoreWarriorState.REST)
    else
      am_core_warrior__state = int(CoreWarriorState.IDLE)
      removeSubTemplate(eid, am_core_warrior__triggeredTemplate)


[es(tag=server, no_order, REQUIRE=am_core_warrior__triggered)]
def core_warrior_update(act : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        am_core_warrior__parentEid : EntityId;
                        am_core_warrior__agroRadius : float;
                        am_core_warrior__damageRadius : float;
                        am_core_warrior__damageThickness : float;
                        am_core_warrior__chargeTime : float;
                        am_core_warrior__restTime : float2;
                        am_core_warrior__travelCooldown : float2;
                        am_core_warrior__damage : float2;
                        am_core_warrior__node : string;
                        am_core_warrior__triggeredTemplate : string;
                        var am_core_warrior__targetEid : EntityId&;
                        var transform aka warrior_transform : float3x4;
                        var am_core_warrior__travelPath : Point3List;
                        var am_core_warrior__normal : float3&;
                        var am_core_warrior__actAt : float&;
                        var am_core_warrior__travelAt : float&;
                        var am_core_warrior__moveTimeOffset : float&;
                        var am_core_warrior__state : int&)
  if am_core_warrior__state == int(CoreWarriorState.REST)
    if act.curTime > am_core_warrior__actAt

      if !doesEntityExist(am_core_warrior__targetEid)
        am_core_warrior__targetEid = INVALID_ENTITY_ID

      var targets : array<float3>
      var hasMainTargetAgro = false
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], am_core_warrior__agroRadius), GridEntCheck.POS) <| $(target_eid : EntityId)
        query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys))] (animchar : AnimcharBaseComponent; transform aka pt_transform : float3x4; nphys__ccdOffset : float3 const?)
          var success = false
          let geomNodeTree = animchar.nodeTree
          if geomNodeTree != null
            let idx = geomtree_findNodeIndex(*geomNodeTree, am_core_warrior__node)
            if idx != -1
              let pos = geomtree_getNodeWpos(*geomNodeTree, idx)
              targets |> push(pos)
              success = true
          if !success && nphys__ccdOffset != null
            let pos = pt_transform[3] + *nphys__ccdOffset
            targets |> push(pos)
            success = true
          if success && target_eid == am_core_warrior__targetEid
            hasMainTargetAgro = true

      var travelAvailable = true
      if am_core_warrior__targetEid != INVALID_ENTITY_ID
        if hasMainTargetAgro
          travelAvailable = false
        elif try_initiate_target_chasing_travel(eid)
          am_core_warrior__state = int(CoreWarriorState.TRAVEL)
          am_core_warrior__moveTimeOffset = 0.0
          send_net_event(eid, CmdSetCoreWarriorTravelPath(path = ecs_addr(am_core_warrior__travelPath)))
          return

      if length(targets) == 1
        query(am_core_warrior__parentEid) <| $ [es] (protected_by_warriors__origin : float3)
          targets |> push(protected_by_warriors__origin)
      elif length(targets) > 2
        shuffle(targets)

      if travelAvailable && length(targets) < 2
        if am_core_warrior__travelAt < act.curTime
          if try_initiate_warrior_travel(eid)
            am_core_warrior__state = int(CoreWarriorState.TRAVEL)
            am_core_warrior__moveTimeOffset = 0.0
            send_net_event(eid, CmdSetCoreWarriorTravelPath(path = ecs_addr(am_core_warrior__travelPath)))
          else
            am_core_warrior__travelAt = act.curTime + rnd_float(am_core_warrior__travelCooldown)
        else
          am_core_warrior__actAt = act.curTime + rnd_float(am_core_warrior__restTime)
        return

      am_core_warrior__actAt = act.curTime + am_core_warrior__chargeTime
      am_core_warrior__state = int(CoreWarriorState.CHARGE)
      am_core_warrior__normal = cross(targets[0] - transform[3], targets[1] - transform[3]) |> normalize()

  elif am_core_warrior__state == int(CoreWarriorState.CHARGE)
    if act.curTime > am_core_warrior__actAt
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], am_core_warrior__damageRadius), GridEntCheck.BOUNDING) <| $(target_eid : EntityId)

        var to, from : float3
        query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka target_transform : float3x4; human_net_phys : HumanActor)
          from = target_transform[3]
          var ccdTm : float3x4
          location_toTM(human_net_phys.phys.currentState.location, ccdTm)
          let worldCcd = (ccdTm * human_net_phys.phys.ccdPos)
          to = from + (worldCcd - from) * 2.0
        query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka target_transform : float3x4; nphys__ccdOffset : float3; nphys_coll__capsuleHeight : float)
          from = target_transform[3] + nphys__ccdOffset
          from.y -= nphys_coll__capsuleHeight
          to = from
          to.y += 2.0 * nphys_coll__capsuleHeight

        if from != float3()
          var dst = get_segment_to_disk_intersection_dst(from, to, am_core_warrior__normal, warrior_transform[3])
          if dst > am_core_warrior__damageRadius
            let from2Plane = point_to_plane_dst(from, am_core_warrior__normal, warrior_transform[3])
            let to2Plane = point_to_plane_dst(to, am_core_warrior__normal, warrior_transform[3])
            if abs(from2Plane) <= abs(to2Plane) && abs(from2Plane) < am_core_warrior__damageThickness
              let nPlaneP = from + am_core_warrior__normal * from2Plane
              dst = distance(nPlaneP, warrior_transform[3])
            elif abs(from2Plane) > abs(to2Plane) && abs(to2Plane) < am_core_warrior__damageThickness
              let nPlaneP = to + am_core_warrior__normal * to2Plane
              dst = distance(nPlaneP, warrior_transform[3])
            else
              return
          let dstF = dst / am_core_warrior__damageRadius
          if dstF < 1.0
            let damage = lerp(am_core_warrior__damage.y, am_core_warrior__damage.x, saturate(dstF))
            let dd = DamageDesc(DamageType.DM_ZONE, damage, warrior_transform[3])
            damage_entity(target_eid, eid, dd)
      go_to_rest_or_idle(am_core_warrior__parentEid, eid, am_core_warrior__triggeredTemplate,
          am_core_warrior__restTime, am_core_warrior__actAt, am_core_warrior__state)
  elif am_core_warrior__state == int(CoreWarriorState.HIDING)
    query(am_core_warrior__parentEid) <| $ [es] (transform aka core_transform : float3x4)
      let distanceSq = distance_sq(warrior_transform[3], core_transform[3])
      if distanceSq < 1e-3
        warrior_transform[3] = core_transform[3]
        am_core_warrior__state = int(CoreWarriorState.HIDDEN)
        removeSubTemplate(eid, am_core_warrior__triggeredTemplate)
      else
        am_core_warrior__travelPath |> resize(1)
        am_core_warrior__travelPath[0] = core_transform[3]
        am_core_warrior__moveTimeOffset = 0.0
        send_net_event(eid, CmdSetCoreWarriorTravelPath(path = ecs_addr(am_core_warrior__travelPath)))
  if am_core_warrior__state == int(CoreWarriorState.TRAVEL)
    if length(am_core_warrior__travelPath) == 0
      am_core_warrior__travelAt = am_core_warrior__actAt + rnd_float(am_core_warrior__travelCooldown)
      go_to_rest_or_idle(am_core_warrior__parentEid, eid, am_core_warrior__triggeredTemplate,
          am_core_warrior__restTime, am_core_warrior__actAt, am_core_warrior__state)


[es(tag=netClient)]
def core_warrior_set_travel_path_from_server(evt : CmdSetCoreWarriorTravelPath; var am_core_warrior__travelPath : Point3List)
  am_core_warrior__travelPath := *evt.path


[es(before=core_warrior_update)]
def handle_warrior_travel(act : ParallelUpdateFrameDelayed;
                          am_core_warrior__travelSpeed : float;
                          var am_core_warrior__moveTimeOffset : float&;
                          var am_core_warrior__origin : float3&;
                          var am_core_warrior__travelPath : Point3List;
                          var transform : float3x4)
  if length(am_core_warrior__travelPath) > 0
    var travelDst = act.dt * am_core_warrior__travelSpeed
    while travelDst > 0.0 && length(am_core_warrior__travelPath) > 0
      let dstToNextPathPoint = distance(am_core_warrior__travelPath[0], transform[3])
      if dstToNextPathPoint < travelDst
        travelDst -= dstToNextPathPoint
        transform[3] = am_core_warrior__travelPath[0]
        am_core_warrior__travelPath |> erase(0)
      else
        let dir = normalize(am_core_warrior__travelPath[0] - transform[3])
        transform[3] += dir * travelDst
        break
    if length(am_core_warrior__travelPath) == 0
      am_core_warrior__moveTimeOffset = act.curTime
    am_core_warrior__origin = transform[3]


[es(no_order)]
def oscillate_core_warriror(act : ParallelUpdateFrameDelayed;
                            am_core_warrior__moveAmplitude : float;
                            am_core_warrior__moveFreq : float;
                            am_core_warrior__actAt : float;
                            am_core_warrior__moveTimeOffset : float;
                            am_core_warrior__origin : float3;
                            am_core_warrior__state : int;
                            var transform : float3x4)
  if (am_core_warrior__state != int(CoreWarriorState.CHARGE) &&
      am_core_warrior__state != int(CoreWarriorState.TRAVEL) &&
      am_core_warrior__state != int(CoreWarriorState.HIDING) &&
      am_core_warrior__state != int(CoreWarriorState.HIDDEN) &&
    !(am_core_warrior__state == int(CoreWarriorState.REST) && am_core_warrior__actAt < act.curTime)) //for the case when client has not received state update
    transform[3] = am_core_warrior__origin
    transform[3].y += -sin((act.curTime - am_core_warrior__moveTimeOffset) * am_core_warrior__moveFreq * PI * 2.0) * am_core_warrior__moveAmplitude


[es(tag=server, track=am_core_warrior__state)]
def move_osc_offset_when_charging(evt : Event;
                                  am_core_warrior__state : int;
                                  am_core_warrior__chargeTime : float;
                                  var am_core_warrior__moveTimeOffset : float&)
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    am_core_warrior__moveTimeOffset += am_core_warrior__chargeTime


[es(tag=gameClient, no_order)]
def am_warrior_spinning(act : ParallelUpdateFrameDelayed;
                        am_core_warrior__state : int;
                        am_core_warrior__actAt : float;
                        am_core_warrior__chargeTime : float;
                        am_core_warrior__rotSpeed : float;
                        am_core_warrior__rotDeaccelTime : float;
                        am_core_warrior__lastHitAt : float;
                        am_core_warrior__normal : float3;
                        var transform : float3x4)
  if am_core_warrior__normal == float3()
    return
  var fromSpeed, toSpeed, timePassed, duration, t : float
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    fromSpeed = 0.0
    toSpeed = am_core_warrior__rotSpeed
    duration = am_core_warrior__chargeTime
    timePassed = act.curTime - am_core_warrior__actAt + am_core_warrior__chargeTime
    t = square(timePassed / duration)
  else
    fromSpeed = am_core_warrior__rotSpeed
    toSpeed = 0.0
    timePassed = act.curTime - am_core_warrior__lastHitAt
    duration = am_core_warrior__rotDeaccelTime
    t = sqrt(max(0.0, timePassed / duration))
  if timePassed > duration
    return
  let speed = lerp(fromSpeed, toSpeed, t)
  let q = quat(am_core_warrior__normal, speed * 2.0 * PI * act.dt)
  transform[0] = q * transform[0]
  transform[1] = q * transform[1]
  transform[2] = q * transform[2]
  orthonormalize(transform)
