require ecs
require DagorRandom
require DagorMath
require Grid
require DngHuman
require game.es.ai.walker_common
require DngWalkerai


[es(on_appear)]
def attach_look_around_target(evt : Event; eid : EntityId; var wander_looker__lookAroundTarget : EntityId&)
  wander_looker__lookAroundTarget = createEntity("look_around_target") <| $(init)
    set(init, "look_around__owner", eid)


[es(on_disappear)]
def remove_look_around_target_on_disappear(evt : Event; wander_looker__lookAroundTarget : EntityId)
  destroyEntity(wander_looker__lookAroundTarget)


[es(track=isAlive)]
def remove_look_around_target_on_death(evt : Event; isAlive : bool; wander_looker__lookAroundTarget : EntityId)
  if !isAlive
    destroyEntity(wander_looker__lookAroundTarget)


[es(no_order)]
def update_rolling_forward(info : UpdateStageInfoAct;
                           look_around__owner : EntityId;
                           look_around__rollingOwnerForwardUpdateInterval : float;
                           var look_around__rollingOwnerForwardUpdateAt : float&;
                           var look_around__rollingOwnerForward : float3&)
  if info.curTime < look_around__rollingOwnerForwardUpdateAt
    return
  look_around__rollingOwnerForwardUpdateAt = info.curTime + look_around__rollingOwnerForwardUpdateInterval

  query(look_around__owner) <| $ [es] (transform : float3x4; human_net_phys : HumanActor)
    assume velocity = human_net_phys.phys.currentState.velocity
    let speed = length(velocity)
    let forward = speed > 0.0 ? velocity / speed : transform[3]
    look_around__rollingOwnerForward = normalize(look_around__rollingOwnerForward * 0.9 + forward * 0.1)


[es(on_appear)]
def init_look_around_target(evt : Event; var look_around__randomTimeOffset : float&)
  look_around__randomTimeOffset = rnd_float(0.0, PI)


[es(no_order)]
def look_around_target(info : UpdateStageInfoAct;
                       look_around__owner : EntityId;
                       look_around__speed : float;
                       look_around__amplitude : float2;
                       look_around__rollingOwnerForward : float3;
                       look_around__randomTimeOffset : float;
                       var transform aka target_transform : float3x4&)
  let time = info.curTime
  var sinTime : float
  var cosTime : float
  sincos(time * look_around__speed + look_around__randomTimeOffset, sinTime, cosTime)
  let xdiff = cosTime * look_around__amplitude.x
  let ydiff = sinTime * look_around__amplitude.y
  query(look_around__owner) <| $ [es] (transform aka owner_transform : float3x4; human_net_phys : HumanActor; walker_agent : EntityAgent)
    let stance = determinate_stance(human_net_phys.phys.currentState)
    let ownerShootPos = walker_agent.shootFrom[stance]
    let up = owner_transform[1]
    let right = owner_transform[2]
    target_transform[3] = ownerShootPos + look_around__rollingOwnerForward + up * ydiff + right * xdiff


[es(no_order)]
def update_teammate_to_watch(info : UpdateStageInfoAct;
                             eid aka looker_eid : EntityId;
                             transform aka looker_transform : float3x4;
                             team aka looker_team : int;
                             wander_looker__teammatesUpdateInterval : float;
                             wander_looker__teammateSearchRadius : float;
                             wander_looker__teammateSearchCosThreshold : float;
                             human_net_phys : HumanActor;
                             var wander_looker__teammatesUpdateAt : float&;
                             var wander_looker__teammateToWatch : EntityId&)
  if info.curTime < wander_looker__teammatesUpdateAt
    return
  wander_looker__teammatesUpdateAt = info.curTime + wander_looker__teammatesUpdateInterval
  assume searchPos = looker_transform[3]
  assume velocity = human_net_phys.phys.currentState.velocity
  let speed = length(velocity)
  let forward = speed > 0.0 ? velocity / speed : looker_transform[3]

  var closestDistanceSq = FLT_MAX
  wander_looker__teammateToWatch = INVALID_ENTITY_ID
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(searchPos, wander_looker__teammateSearchRadius), GridEntCheck.BOUNDING) <| $(other_eid : EntityId)
    if other_eid == looker_eid
      return
    query(other_eid) <| $ [es] (transform aka other_transform : float3x4; team aka other_team : int)
      if other_team != looker_team
        return
      let toTeammate = normalize(other_transform[3] - searchPos)
      let cs = dot(toTeammate, forward)
      if cs < wander_looker__teammateSearchCosThreshold
        return
      let distSq = distance_sq(searchPos, other_transform[3])
      if distSq < closestDistanceSq
        closestDistanceSq = distSq
        wander_looker__teammateToWatch = other_eid


[es(no_order)]
def choose_wander_target(info : UpdateStageInfoAct;
                         wander_looker__lookAroundTarget : EntityId;
                         wander_looker__teammateToWatch : EntityId;
                         wander_looker__updateInterval : float;
                         var wander_looker__updateAt : float&;
                         var wander_looker__targetBb : int&)
  if info.curTime < wander_looker__updateAt
    return
  wander_looker__updateAt = info.curTime + wander_looker__updateInterval

  var possibleTargets : array<EntityId>
  if wander_looker__lookAroundTarget != INVALID_ENTITY_ID
    push(possibleTargets, wander_looker__lookAroundTarget)

  if wander_looker__teammateToWatch != INVALID_ENTITY_ID
    push(possibleTargets, wander_looker__teammateToWatch)

  if empty(possibleTargets)
    return

  let idx = rnd_int(0, length(possibleTargets) - 1)
  wander_looker__targetBb = int(uint(possibleTargets[idx]))
