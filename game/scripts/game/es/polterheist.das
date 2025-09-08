require ecs
require math.base
require math.random
require GamePhys
require PhysObj
require DngPhysObj
require PhysDecl
require DagorMath
require RendInst
require Dacoll
require game.es.grav_zones_common
require game.events.events_active_matter


[es(no_order, tag=server, REQUIRE_NOT=deadEntity)]
def polterheist_activation_server_es(info : UpdateStageInfoAct;
                                     polterheist_activation__radius : float;
                                     var polterheist_activation__score : float&;
                                     polterheist_activation__speed : float;
                                     var polterheist_activation__targetScore : float&;
                                     polterheist_activation__targetScoreRange : float2;
                                     polterheist_activation__delay : float;
                                     var polterheist_activation__rndSeed : int&;
                                     transform aka human_transform : float3x4;
                                     human__aimTm : float3x4)
  var activate = false
  var items : array<EntityId>
  ecs::find_query() <| $ [es(REQUIRE=potlerheistItem)] (eid : EntityId; transform : float3x4; polterheist_item__stage : int; ri_extra__handle : riex_handle_t)
    if polterheist_item__stage != 0 || distance_sq(human_transform[3], transform[3]) > square(polterheist_activation__radius)
      return false
    let dirUp = -get_grav_dir(transform[3])
    let from = transform[3] + float3(0.0, 0.1, 0.0)
    if rayhit_normalized(from, dirUp, 1.0, ETF_DEFAULT, -1, null, ri_extra__handle)
      return false
    let fullDir = transform[3] - human__aimTm[3]
    let len = length(fullDir)
    let dir = fullDir * safeinv(len)
    if rayhit_normalized(human__aimTm[3], dir, len, ETF_DEFAULT, -1, null, ri_extra__handle)
      return false
    if !activate
      if polterheist_activation__targetScore <= 0.0
        polterheist_activation__targetScore = rnd_float(polterheist_activation__targetScoreRange.x, polterheist_activation__targetScoreRange.y)
      polterheist_activation__score += polterheist_activation__speed * info.dt
      if polterheist_activation__score < polterheist_activation__targetScore
        return true
      polterheist_activation__score = 0.0
      polterheist_activation__targetScore = -1.0
      activate = true

    if activate
      items |> push(eid)
    return false

  if !empty(items)
    let polterheistItemEid = items[rnd_int(0, length(items) - 1)]
    ecs::query(polterheistItemEid) <| $ [es] (var polterheist_item__startAt : float&; var polterheist_item__rndSeed : int&)
      polterheist_item__startAt = info.curTime + polterheist_activation__delay
      polterheist_activation__rndSeed = _rnd_int(polterheist_activation__rndSeed, 0, 32766)
      polterheist_item__rndSeed = polterheist_activation__rndSeed


[es(no_order, tag=gameClient, REQUIRE_NOT=deadEntity)]
def polterheist_activation_client_es(info : UpdateStageInfoAct;
                                     polterheist_activation__radius : float;
                                     var polterheist_activation_client__score : float&;
                                     polterheist_activation_client__speed : float;
                                     var polterheist_activation_client__targetScore : float&;
                                     polterheist_activation_client__targetScoreRange : float2;
                                     polterheist_activation__delay : float;
                                     var polterheist_activation__rndSeed : int&;
                                     transform aka human_transform : float3x4;
                                     human__aimTm : float3x4)
  var activate = false
  var items : array<EntityId>
  ecs::find_query() <| $ [es(REQUIRE=potlerheistItem)] (eid : EntityId; transform : float3x4; polterheist_item__stage : int; ri_extra__handle : riex_handle_t)
    if polterheist_item__stage != 0 || distance_sq(human_transform[3], transform[3]) > square(polterheist_activation__radius)
      return false
    let dirUp = -get_grav_dir(transform[3])
    let from = transform[3] + float3(0.0, 0.1, 0.0)
    if rayhit_normalized(from, dirUp, 1.0, ETF_DEFAULT, -1, null, ri_extra__handle)
      return false
    let fullDir = transform[3] - human__aimTm[3]
    let len = length(fullDir)
    let dir = fullDir * safeinv(len)
    if rayhit_normalized(human__aimTm[3], dir, len, ETF_DEFAULT, -1, null, ri_extra__handle)
      return false
    if !activate
      if polterheist_activation_client__targetScore <= 0.0
        polterheist_activation_client__targetScore = rnd_float(polterheist_activation_client__targetScoreRange.x, polterheist_activation_client__targetScoreRange.y)
      polterheist_activation_client__score += polterheist_activation_client__speed * info.dt
      if polterheist_activation_client__score < polterheist_activation_client__targetScore
        return true
      polterheist_activation_client__score = 0.0
      polterheist_activation_client__targetScore = -1.0
      activate = true

    if activate
      items |> push(eid)
    return false

  if !empty(items)
    let polterheistItemEid = items[rnd_int(0, length(items) - 1)]
    ecs::query(polterheistItemEid) <| $ [es] (var polterheist_item__startAt : float&; var polterheist_item__rndSeed : int&)
      polterheist_item__startAt = info.curTime + polterheist_activation__delay
      polterheist_activation__rndSeed = _rnd_int(polterheist_activation__rndSeed, 0, 32766)
      polterheist_item__rndSeed = polterheist_activation__rndSeed



[es(after=after_net_phys_sync)]
def polterheist_item_update_es(info : UpdateStageInfoAct;
                               var transform aka item_transform : float3x4;
                               var phys_obj_net_phys : PhysObjActor?;
                               var phys_body : PhysBody?;
                               var polterheist_item__stage : int&;
                               var polterheist_item__startAt : float&;
                               var polterheist_item__rndSeed : int&;
                               polterheist_item__riseVel : float;
                               var polterheist_item__riseTime : float&;
                               var polterheist_item__rotationCounter : float&;
                               polterheist_item__rotationTime : float;
                               var polterheist_item__riseRotationStep : float3&;
                               polterheist_item__rotationSpeed : float;
                               polterheist_item__throwPower : float;
                               polterheist_item__throwOffsetY : float2;
                               polterheist_item__throwOffsetXZ : float2;
                               polterheist_item__throwRotationMult : float;
                               polterheist_item__throwToCameraChance : float;
                               ri_extra__handle : riex_handle_t)
  if info.curTime > polterheist_item__startAt && polterheist_item__startAt > 0.0
    polterheist_item__startAt = -1.0
    let maxAngle = HALF_PI
    polterheist_item__riseRotationStep = float3(_rnd_float(polterheist_item__rndSeed, -maxAngle, maxAngle),
                                                _rnd_float(polterheist_item__rndSeed, -maxAngle, maxAngle),
                                                _rnd_float(polterheist_item__rndSeed, -maxAngle, maxAngle)) / (polterheist_item__riseTime)
    if phys_body != null
      phys_body_disableGravity(*phys_body, true)
    polterheist_item__stage = 1
  if polterheist_item__stage == 1 || polterheist_item__stage == 2
    var riseVel = polterheist_item__riseVel
    if polterheist_item__stage == 2
      riseVel -= (polterheist_item__riseVel / polterheist_item__rotationTime) * polterheist_item__rotationCounter
      riseVel *= cos(PI * polterheist_item__rotationCounter)
    let gravDir = get_grav_dir(transform[3])
    let offs = -gravDir * riseVel * info.dt
    transform[3] += offs
    if phys_obj_net_phys != null
      (*phys_obj_net_phys).phys.currentState.location.P += DPoint3(offs)
    polterheist_item__riseTime -= info.dt
    if polterheist_item__riseTime <= 0.0
      polterheist_item__stage = 2
    let angles = polterheist_item__riseRotationStep * polterheist_item__rotationSpeed * info.dt
    var q : quat
    euler_to_quat(angles.x, angles.y, angles.z, q)
    if phys_obj_net_phys != null
      q = normalize((*phys_obj_net_phys).phys.currentState.location.O.quat + q)
      (*phys_obj_net_phys).phys.currentState.location.O |> orient_setQuat(q)
    var rotTm : float3x4
    make_tm(q, rotTm)
    transform = transform * rotTm
    if phys_body != null
      phys_body_setTm(*phys_body, transform)
  if polterheist_item__stage == 2
    polterheist_item__rotationCounter += info.dt
    if polterheist_item__rotationCounter >= polterheist_item__rotationTime
      polterheist_item__stage = 3
      if phys_obj_net_phys != null
        (*phys_obj_net_phys).phys |> wakeUp()
      if phys_body != null
        phys_body_disableGravity(*phys_body, false)
      var targetPos : float3
      var powerMult : float
      let found = ecs::find_query() <| $ [es] (polterheist_activation__radius : float; transform aka human_transform, human__aimTm : float3x4)
        let distSq = distance_sq(human_transform[3], item_transform[3])
        if distSq > square(polterheist_activation__radius)
          return false
        if _rnd_float(polterheist_item__rndSeed, 0.0, 1.0) <= polterheist_item__throwToCameraChance
          targetPos = human__aimTm * float3(0.15, 1.2, 0.0)
        else
          targetPos = human_transform * float3(_rnd_float(polterheist_item__rndSeed, polterheist_item__throwOffsetXZ.x, polterheist_item__throwOffsetXZ.y),
                                               _rnd_float(polterheist_item__rndSeed, polterheist_item__throwOffsetY.x, polterheist_item__throwOffsetY.y),
                                               _rnd_float(polterheist_item__rndSeed, polterheist_item__throwOffsetXZ.x, polterheist_item__throwOffsetXZ.y))
        powerMult = min(1.0, sqrt(distSq) / 2.0)
        let fullDir = targetPos - item_transform[3]
        let len = length(fullDir)
        let dir = fullDir * safeinv(len)
        return !rayhit_normalized(item_transform[3], dir, len, ETF_DEFAULT, -1, null, ri_extra__handle)
      if found
        let throwVel = normalize(targetPos - item_transform[3]) * polterheist_item__throwPower * powerMult
        let angVel = polterheist_item__riseRotationStep * polterheist_item__throwRotationMult
        if phys_obj_net_phys != null
          (*phys_obj_net_phys).phys.currentState.velocity = throwVel
          (*phys_obj_net_phys).phys.currentState.omega = angVel
        if phys_body != null
          phys_body_setVelocity(*phys_body, throwVel, true)
          phys_body_setAngularVelocity(*phys_body, angVel, true)
