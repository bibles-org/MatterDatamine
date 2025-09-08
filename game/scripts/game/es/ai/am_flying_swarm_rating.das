require ecs
require ecs.safe
require ecs.common
require app
require math.base
require game.es.level_common
require active_matter.game.es.ai.visual_attraction_common
require CapsuleApproximation
require DagorRandom
require DagorMath
require Dacoll
require AnimV20
require GeomNodeTree
require game.utils.team


[es(tag=server, on_appear)]
def on_swarm_created(evt : Event;
                     eid : EntityId;
                     swarm__updateInterval : float;
                     var swarm__nextUpdate : float&)
  swarm__nextUpdate = get_sync_time() + swarm__updateInterval * eid_frnd(eid)


[es(before=victim_ratings_updates)]
def clear_list_candidates(info : UpdateStageInfoAct;
                          swarm_cluster__hivePos : float3;
                          swarm_cluster__radius : float = 5.0;
                          transform : float3x4;
                          swarm_cluster__visibilityRange : float;
                          swarm_cluster__agroRange : float;
                          var swarm__hitTargets : Array&;
                          swarm__nextUpdate : float)
  if info.curTime < swarm__nextUpdate
    return

  var xenosTeam = TEAM_UNASSIGNED
  query() <| $ [es(REQUIRE=xenos_team)] (team__id : int)
    xenosTeam = team__id
  var targets : table<uint; float3>

  var smokes : array<float4>
  query() <| $ [es] (smoke_occluder__sphere : float4)
    push(smokes, smoke_occluder__sphere)

  var fires : array<float4>
  query() <| $ [es(REQUIRE=dmgzone__fireAffect)] (dmgzone__maxRadius : float; transform aka dmgzone_transform : float3x4)
    push(fires, float4(dmgzone_transform[3], dmgzone__maxRadius))

  query() <| $ [es(REQUIRE=human)] (eid : EntityId;
                                    isAlive : bool;
                                    team : int;
                                    transform : float3x4)
    if !isAlive || team == xenosTeam
      return

    for smoke in smokes
      if distance_sq(transform[3], smoke.xyz) < square(smoke.w + swarm_cluster__radius)
        return

    for fire in fires
      if distance_sq(transform[3], fire.xyz) < square(fire.w + swarm_cluster__radius)
        return

    targets.insert(uint(eid), transform[3])
  if length(targets) == 0
    swarm__hitTargets |> clear()
    return

  var missingTargets : array<int>
  for i, targetObj in iter_range(swarm__hitTargets), swarm__hitTargets
    let data = targetObj as Object
    let eidTarget = data?.eid ?? INVALID_ENTITY_ID
    let found = targets |> key_exists(uint(eidTarget))
    if !found
      missingTargets |> push(i, 0)

  for missingTarget in missingTargets
    swarm__hitTargets |> erase(missingTarget)

  let maxDistSq = square(swarm_cluster__visibilityRange)
  let argoDistSq = square(swarm_cluster__agroRange)
  for uid, targetPos in keys(targets), values(targets)
    let prevIdx = swarm__hitTargets |> each |> find_index_if <| $(it)
      return uint((it as Object)?.eid ?? INVALID_ENTITY_ID) == uid

    let origin = swarm_cluster__hivePos == float3() ? transform[3] : swarm_cluster__hivePos
    let distSq = distance_sq(origin.xz, targetPos.xz)
    if distSq > maxDistSq || level_common::is_pos_indoor(targetPos, 5.0)
      if prevIdx >= 0
        swarm__hitTargets |> erase(prevIdx)
      continue

    if prevIdx >= 0
      var rwData = swarm__hitTargets[prevIdx] |> getRW_ecs_object()
      if rwData != null
        *rwData |> set("dist", sqrt(distSq))
        *rwData |> set("pos", targetPos)
    elif distSq <= argoDistSq
      using() <| $(var obj : Object)
        obj |> set("eid", EntityId(uid))
        obj |> set("dist", sqrt(distSq))
        obj |> set("pos", targetPos)
        swarm__hitTargets |> push(obj)


def can_swarm_attack(pos : float3;
                     victim_eid : EntityId;
                     radius : float)
  var res = false
  query(victim_eid) <| $ [es] (@shared_comp capsule_approximation : CapsuleApproximation; animchar : AnimcharBaseComponent)
    let index = grnd() % length(capsule_approximation.capsuleDatas)
    assume data = capsule_approximation.capsuleDatas[index]
    let rndPos = pos + float3(rnd_float(-radius, radius), rnd_float(-radius, radius), rnd_float(-radius, radius))
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, int(data.nodeIndex), tm)
    let posVictimNode = tm[3] + (data.a + data.b) * gfrnd()
    var underwater = false
    traceht_water_at_time(posVictimNode, 0.0, get_sync_time(), underwater)
    if underwater
      return
    var lenToCenter = distance(rndPos, pos)
    var lenToVictim = distance(rndPos, posVictimNode)
    let dirToCenter = (pos - rndPos) * safeinv(lenToCenter)
    let dirToVictim = (posVictimNode - rndPos) * safeinv(lenToVictim)
    var norm : float3
    if (!traceray_normalized(rndPos, dirToVictim, lenToVictim, norm)
        && !traceray_normalized(rndPos, dirToCenter, lenToCenter, norm))
      res = true
  return res


[es(no_order)]
def victim_ratings_updates(info : UpdateStageInfoAct;
                           transform : float3x4;
                           swarm_cluster__radius : float;
                           var swarm__hitTargets : Array&;
                           var swarm__nextUpdate : float&;
                           swarm__updateInterval : float;
                           swarm_cluster__visibilityRange : float)
  if info.curTime < swarm__nextUpdate
    return
  swarm__nextUpdate = info.curTime + swarm__updateInterval

  if length(swarm__hitTargets) == 0
    return

  let swarmClusterPos = transform[3]
  var maxRatio = 0f
  var maxRatioIdx = -1
  var maxRatioEid : EntityId
  let curTime = info.curTime

  for i, target in iter_range(swarm__hitTargets), swarm__hitTargets

    let targeObj = target as Object
    if targeObj == null
      return

    let eid = (*targeObj).eid ?? INVALID_ENTITY_ID
    let lastTraceTime = (*targeObj).lastTraceTime ?? 0f
    let dist = (*targeObj).dist ?? 0f

    let ratio = calc_traceable_ratio(curTime, lastTraceTime, dist, swarm_cluster__visibilityRange, swarm_cluster__radius)
    if ratio > maxRatio
      maxRatio = ratio
      maxRatioIdx = i
      maxRatioEid = eid

  if maxRatioIdx < 0
    return

  let visible = can_swarm_attack(swarmClusterPos, maxRatioEid, swarm_cluster__radius)

  var targetRW = getRW_ecs_object(swarm__hitTargets[maxRatioIdx])
  if targetRW != null
    *targetRW |> set("lastTraceTime", info.curTime)
    *targetRW |> set("visible", visible)
