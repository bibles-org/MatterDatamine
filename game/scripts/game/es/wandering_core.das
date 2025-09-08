require ecs
require ecs.common
require ecs.safe
require app
require net
require strings
require math.base
require math.random
require DagorMath
require DagorSystem
require Grid
require Dacoll
require DngDm
require DngNet
require dm
require pathfinder
require game.events.events_game
require game.es.grav_zones_common
require game.events.events_active_matter
require danetlibs.dm.dm_events
require game.es.wandering_core_common


[es(tag=server, on_event=(CmdApplyDamage, EventStoneHit))]
def wandering_core_on_projectile_hit(evt : Event;
                                     eid : EntityId;
                                     wandering_core__agroOnHit : float;
                                     wandering_core__agroMax : float;
                                     wandering_core__damageAgroCooldown : float;
                                     var wandering_core__agro : float&;
                                     var wandering_core__damageAgroBlockedUntil : float&)
  let time = get_sync_time()
  if time > wandering_core__damageAgroBlockedUntil
    wandering_core__damageAgroBlockedUntil = time + wandering_core__damageAgroCooldown
    wandering_core__agro = min(wandering_core__agroMax, wandering_core__agro + wandering_core__agroOnHit)
  send_net_event(eid, EventWanderingCoreHit(agro = wandering_core__agro))


[es(no_order)]
def wandering_core_agro_update(act : ParallelUpdateFrameDelayed;
                               wandering_core__agroMax : float;
                               var wandering_core__agro : float&)
  wandering_core__agro = clamp(wandering_core__agro - act.dt, .0, wandering_core__agroMax)


def find_wandering_core_target_in_grid(pos : float3; radius : float)
  let sphere = BSphere3(pos, radius)
  let enemyEid = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(target_eid : EntityId)
    var success = false
    query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys, heroForPlayer))] (transform aka target_transform : float3x4)
      let targetPos = target_transform[3] + float3(0.0, 0.5, 0.0)
      let delta = targetPos - pos
      let distSq = length_sq(delta)
      if distSq > 1e-3
        let dist = sqrt(distSq)
        let dir = delta / dist
        var norm : float3
        var t = dist
        if traceray_normalized(pos, dir, t, norm)
          return
      success = true
    return success
  return enemyEid


def wandering_core_explode(core_eid : EntityId;
                           var damage_sphere_eid : EntityId&;
                           transform : float3x4;
                           damage_sphere_template, explosion_template : string)
  var tm = IDENT_TM
  tm[3] = transform[3]
  damage_sphere_eid = createEntity(damage_sphere_template) <| $(init)
    init |> set("am_core_damage_sphere__ownerEid", core_eid)
    init |> set("transform", tm)
  createEntity(explosion_template) <| $(init)
    init |> set("ownerEid", core_eid)
    init |> set("transform", tm)


[es(tag=server, no_order)]
def wandering_core_find_target(act : UpdateStageInfoAct; //can't PUFD because grid
                               eid : EntityId;
                               transform : float3x4;
                               wandering_core__interval : float;
                               wandering_core__searchTargetRadius : float;
                               wandering_core__damageSphereTemplate : string;
                               wandering_core__explosionTemplate : string;
                               var wandering_core__damageSphere : EntityId&;
                               var wandering_core__updateAt : float&)
  if wandering_core__updateAt < act.curTime && wandering_core__damageSphere == INVALID_ENTITY_ID
    wandering_core__updateAt = act.curTime + wandering_core__interval
    if find_wandering_core_target_in_grid(transform[3], wandering_core__searchTargetRadius) != INVALID_ENTITY_ID
      wandering_core_explode(eid,
                             wandering_core__damageSphere,
                             transform,
                             wandering_core__damageSphereTemplate,
                             wandering_core__explosionTemplate)


[es(tag=server)]
def wandering_core_died(evt : EventEntityDied;
                        eid : EntityId;
                        transform : float3x4;
                        wandering_core__damageSphereTemplate : string;
                        wandering_core__explosionTemplate : string;
                        var wandering_core__damageSphere : EntityId&)
  wandering_core_explode(eid,
                          wandering_core__damageSphere,
                          transform,
                          wandering_core__damageSphereTemplate,
                          wandering_core__explosionTemplate)


[es(tag=gameClient, on_appear, on_event=EventNoLongerInNetStash)]
def wandering_core_fx_init(evt : Event;
                           eid : EntityId;
                           transform : float3x4;
                           wandering_core__fxCount : int2;
                           wandering_core__fxTemplate : string;
                           var wandering_core__fxList : EidList)
  var seed = int(uint(eid))
  let count = _rnd_int(seed, wandering_core__fxCount)
  for _ in range(count)
    let fxEid = createEntity(wandering_core__fxTemplate) <| $(init)
      init |> set("transform", transform)
    wandering_core__fxList |> push(fxEid)


[es(tag=gameClient, on_disappear, on_event=EventWentToNetStash)]
def wandering_core_fx_destroy(evt : Event; var wandering_core__fxList : EidList)
  for eid in wandering_core__fxList
    destroyEntity(eid)
  clear(wandering_core__fxList)


[es(tag=gameClient)]
def client_on_wandering_core_hit(evt : EventWanderingCoreHit; wandering_core__fxList : EidList; var wandering_core__agro : float&)
  wandering_core__agro = evt.agro
  for eid in wandering_core__fxList
    query(eid) <| $ [es] (var wandering_core_fx__timeHit : float&)
      wandering_core_fx__timeHit = get_sync_time()


[es(tag=gameClient, no_order, REQUIRE_NOT=wandering_core__exploadAt)]
def update_wandering_core_fx_scale(act : ParallelUpdateFrameDelayed;
                                   wandering_core_fx__timeHit : float;
                                   wandering_core_fx__scaleTime : float;
                                   wandering_core_fx__scaleMinMax : float2;
                                   wandering_core_fx__radiusMult : float;
                                   var transform : float3x4)
  let deltaT = act.curTime - wandering_core_fx__timeHit
  let scale = cvt(deltaT, 0.0, wandering_core_fx__scaleTime, wandering_core_fx__scaleMinMax.y, wandering_core_fx__scaleMinMax.x)
  transform[0] = float3(1, 0, 0) * scale * wandering_core_fx__radiusMult
  transform[1] = float3(0, 1, 0) * scale * wandering_core_fx__radiusMult
  transform[2] = float3(0, 0, 1) * scale * wandering_core_fx__radiusMult


[es(tag=gameClient, no_order, REQUIRE_NOT=wandering_core__exploadAt)]
def wandering_core_fx_update(act : ParallelUpdateFrameDelayed;
                             transform aka core_transform : float3x4;
                             wandering_core__agro : float;
                             wandering_core__agroMax : float;
                             wandering_core__fxSpeed : float;
                             wandering_core__triggerCharge : float;
                             wandering_core__charge : float;
                             wandering_core_fxMetaSpeed : float = 1.7;
                             wandering_core_oscilationsPerDuration : float = 2.0;
                             wandering_core__fxRadius : float2;
                             wandering_core__fxList : EidList;
                             wandering_core__oscilateUntil : float;
                             wandering_core__chargeOscilationRange : float;
                             wandering_core__oscilateStart : float;
                             wandering_core__oscilateDuration : float;
                             var wandering_core__fxTime : float&;
                             var wandering_core__fxTm : float3x4)
  let radius = lerp(wandering_core__fxRadius.x, wandering_core__fxRadius.y, wandering_core__agro / wandering_core__agroMax)
  let gravDir = get_grav_dir(transform[3], true)
  wandering_core__fxTime += act.dt
  for i in range(3)
    //Rotate all axis regardless of fx count. Because axis are used to rotate each other.
    let k = (i + 1) % 3
    let q2 = quat(wandering_core__fxTm[k], wandering_core_fxMetaSpeed * act.dt)
    wandering_core__fxTm[i] = q2 * wandering_core__fxTm[i]
    if length(wandering_core__fxList) > i
      //Create local slow downs and speed ups with extra time
      let extraTime = sin(wandering_core__fxTime * wandering_core__fxSpeed * 0.5 + PI * 2.0 / 3.0 * float(i)) * 6.0
      query(wandering_core__fxList[i]) <| $ [es] (var transform aka fx_transform : float3x4; var wandering_core_fx__radiusMult : float&)
        let angle = 2.0 * PI / float(length(wandering_core__fxList)) * float(i) + wandering_core__fxSpeed * wandering_core__fxTime + extraTime
        let q = quat(wandering_core__fxTm[i], angle)
        let disDir = quat_get_forward(q)
        let downDot = max(0., dot(disDir, gravDir)) * 0.3 //reduce down dir to avoid touching the groud
        let circlingMotion = disDir * (radius - downDot)
        fx_transform[3] = core_transform[3] + circlingMotion
        if wandering_core__oscilateUntil > act.curTime
          let frac = lerp(0.25, 1.0, wandering_core__charge / wandering_core__triggerCharge)
          let oscRange = lerp(.0, wandering_core__chargeOscilationRange, frac)
          let oscSpeed = PI * 2.0 * wandering_core_oscilationsPerDuration / wandering_core__oscilateDuration
          wandering_core_fx__radiusMult = 1.0 + cos((act.curTime - wandering_core__oscilateStart) * oscSpeed) * oscRange
        else
          wandering_core_fx__radiusMult = 1.0


[es(tag=gameClient, no_order)]
def wandering_core_exploading_fx_update(act : ParallelUpdateFrameDelayed;
                                        transform aka core_transform : float3x4;
                                        wandering_core__exploadAt : float;
                                        wandering_core__fxTimings : FloatList;
                                        wandering_core__fxScales : FloatList;
                                        wandering_core__fxList : EidList)
  let timeLeft = max(.0, wandering_core__exploadAt - act.curTime)
  var targetScale : float
  for idx in iter_range(wandering_core__fxTimings)
    if wandering_core__fxTimings[idx] > timeLeft
      targetScale = cvt(timeLeft,
                wandering_core__fxTimings[idx - 1],
                wandering_core__fxTimings[idx],
                wandering_core__fxScales[idx - 1],
                wandering_core__fxScales[idx])
      break

  for e in wandering_core__fxList
    query(e) <| $ [es] (var wandering_core_fx__radiusMult : float&; var transform : float3x4)
      wandering_core_fx__radiusMult = targetScale
      transform = core_transform


[es(tag=server)]
def damage_wandering_cores_on_shell_exploded(evt : EventShellExplodedServer;
                                             shell__owner : EntityId;
                                             shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id : int;
                                             shell__damageMult  = 1.0;
                                             shell__damageRadiusMult  = 1.0)
  let radius = get_shell_max_radius(shell__shell_id__shell_id,
                                    shell__shell_id__damage_id,
                                    shell__shell_id__ballistics_id) * shell__damageRadiusMult
  if radius <= 0f
    return
  let splash = get_shell_splash_params(shell__shell_id__damage_id, false)
  damage_wandering_cores_in_radius(evt.pos, splash, radius, shell__damageMult, shell__owner)


def damage_wandering_cores_in_radius(pos : float3; splash : SplashParams; radius, damage_mult : float; offender : EntityId)
  for_each_entity_in_grid(ecs_hash("am_cores"), BSphere3(pos, radius), GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=hitpoints__hp)] (transform : float3x4;
                                                                         hitpoints__shellSplashDmgMult : float = 1.0)
      let delta = transform[3] - pos
      let distanceToEpicenter = length(delta)
      var damage = splash.damage * damage_mult * hitpoints__shellSplashDmgMult
      damage *= cvt(distanceToEpicenter, splash.innerRadius, splash.outerRadius, 1.0, 0.0)

      if damage > .0
        let dmDesc = DamageDesc(DamageType.DM_EXPLOSION, damage, pos)
        damage_entity(eid, offender, dmDesc)


[es(tag=server, on_appear)]
def wandering_core_bind_to_waypoints(evt : Event;
                                     var wandering_core__waypointsEid : EntityId&;
                                     transform aka core_transform : float3x4;
                                     wandering_core__patrolRadius : float = .0;
                                     wandering_core__waypointSearchRadius : float;
                                     embryo__updateAt : float const?;
                                     eid aka core_eid : EntityId)
  if wandering_core__waypointsEid != INVALID_ENTITY_ID
    return

  var bestDst = FLT_MAX
  var waypointsExist = false
  query() <| $ [es] (eid : EntityId;
                     transform aka wp_transform : float3x4;
                     navmesh_waypoints__waypoints : Point3List;
                     navmesh_waypoints__projectedWaypoints : Point3List const?;
                     navmesh_waypoints__localSpace : bool)
    waypointsExist = true
    let useProjected = navmesh_waypoints__projectedWaypoints != null
    let (dst, _) = find_nearest_waypoint(core_transform[3],
                                        useProjected ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints,
                                        wp_transform,
                                        useProjected ? false : navmesh_waypoints__localSpace)
    if dst < bestDst
      bestDst = dst
      if dst < wandering_core__waypointSearchRadius
        wandering_core__waypointsEid = eid
  if wandering_core__waypointsEid == INVALID_ENTITY_ID
    if embryo__updateAt == null && wandering_core__patrolRadius <= .0
      logerr("Wandering core failed to find waypoints at {core_transform[3]}. waypointsExist: {waypointsExist} bestDst:{bestDst} <{eid}>({getEntityTemplateName(eid)})")
      destroyEntity(eid)


[es(tag=server, on_appear, REQUIRE=curious_core__grid, after=wandering_core_bind_to_waypoints)]
def init_core_curiosity_area(evt : Event; eid, wandering_core__waypointsEid : EntityId)
  if wandering_core__waypointsEid == INVALID_ENTITY_ID
    init_as_waypointless_core(eid)
  else
    init_as_waypointed_core(eid)


def init_as_waypointless_core(eid : EntityId)
  query(eid) <| $ [es] (transform : float3x4;
                        wandering_core__patrolRadius : float;
                        var curious_core__gridCellSize : float&;
                        var curious_core__defaultWeight : float&;
                        var curious_core__grid : FloatList;
                        var curious_core__gridSizeX : int&;
                        var curious_core__gridMin : float3&;
                        var curious_core__gridMax : float3&)
    if wandering_core__patrolRadius <= .0
      return
    addSubTemplate(eid, "waypointless_core")
    curious_core__defaultWeight = 99999.0 // overpower all other factors
    survery_grid_points(transform[3],
                          wandering_core__patrolRadius,
                          curious_core__gridCellSize,
                          curious_core__gridMin,
                          curious_core__gridMax)
    curious_core__gridMin.y -= curious_core__gridCellSize
    curious_core__gridMax.y += curious_core__gridCellSize
    resize(curious_core__grid, 4)
    curious_core__gridSizeX = 2
    curious_core__gridCellSize = wandering_core__patrolRadius


def survery_grid_points(pos : float3; radius, step : float; var grid_min, grid_max : float3&)
  var bbox = BBox3()
  let sideLength = int(ceil(radius / step)) * 2
  let steps = square(sideLength)
  let startP = pos - float3(radius, .0, radius)
  let north = float3(1, 0, 0)
  let west = float3(0, 0, 1)
  for i in range(steps)
    var p = startP + float(i % sideLength) * step * north + float(i / sideLength) * step * west
    if project_to_nearest_navmesh_point(p, float3(10.0, 300.0, 10.0))
      bbox |> bbox3_add(p)
  grid_min = bbox.boxMin
  grid_max = bbox.boxMax


def init_as_waypointed_core(eid : EntityId)
  query(eid) <| $ [es] (wandering_core__waypointsEid : EntityId;
                        curious_core__gridCellSize : float;
                        curious_core__extraCells : int;
                        var curious_core__updateAt : float&;
                        var curious_core__grid : FloatList;
                        var curious_core__gridSizeX : int&;
                        var curious_core__gridMin : float3&;
                        var curious_core__gridMax : float3&)
    curious_core__updateAt = get_sync_time()
    query(wandering_core__waypointsEid) <| $ [es] (navmesh_waypoints__waypoints : Point3List;
                                                   navmesh_waypoints__localSpace : bool;
                                                   transform aka waypoints_transform : float3x4;
                                                   navmesh_waypoints__projectedWaypoints : Point3List const?)
      let useProjected = navmesh_waypoints__projectedWaypoints != null
      find_min_max_waypoint(curious_core__gridMin,
                            curious_core__gridMax,
                            useProjected ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints,
                            useProjected ? false : navmesh_waypoints__localSpace,
                            waypoints_transform)
      let width = curious_core__gridMax - curious_core__gridMin
      let extraX = floor(width.x / curious_core__gridCellSize) - width.x / curious_core__gridCellSize
      let extraZ = floor(width.z / curious_core__gridCellSize) - width.z / curious_core__gridCellSize
      let extraCells = float(curious_core__extraCells) * curious_core__gridCellSize
      curious_core__gridMin.x -= extraX * 0.5 + extraCells
      curious_core__gridMin.z -= extraZ * 0.5 + extraCells
      curious_core__gridMax.x += extraX * 0.5 + extraCells
      curious_core__gridMax.z += extraZ * 0.5 + extraCells
      curious_core__gridMin.y -= extraCells
      curious_core__gridMax.y += extraCells
      curious_core__gridSizeX = int(width.x / curious_core__gridCellSize) + 1 + curious_core__extraCells
      let sizeZ = int(width.z / curious_core__gridCellSize) + 1 + curious_core__extraCells
      resize(curious_core__grid, curious_core__gridSizeX * sizeZ)


def find_min_max_waypoint(var grid_min, grid_max : float3&; waypoints : Point3List; local_space : bool; transform : float3x4)
  var bbox = BBox3()
  for wp in waypoints
    let p = local_space ? transform * wp : wp
    bbox |> bbox3_add(p)
  grid_min = bbox.boxMin
  grid_max = bbox.boxMax


[es(tag=server, no_order, REQUIRE_NOT=wandering_core__exploadAt)]
def update_wandering_core_charge(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 transform : float3x4;
                                 wandering_core__triggerCharge : float;
                                 wandering_core__chargeFade : float2;
                                 wandering_core__chargeUpdtInterval : float;
                                 wandering_core__exploadDelay : float;
                                 var wandering_core__lastUpdatePos : float3&;
                                 var wandering_core__charge : float&;
                                 var wandering_core__chargeUpdtAt : float&)
  if act.curTime > wandering_core__chargeUpdtAt
    let dt = act.curTime - wandering_core__chargeUpdtAt + wandering_core__chargeUpdtInterval
    wandering_core__chargeUpdtAt = act.curTime + wandering_core__chargeUpdtInterval
    wandering_core__lastUpdatePos = transform[3]

    let fade = cvt(wandering_core__charge, .0, wandering_core__triggerCharge, wandering_core__chargeFade.x, wandering_core__chargeFade.y)
    wandering_core__charge = max(0.0, wandering_core__charge - fade * dt)
    if wandering_core__triggerCharge < wandering_core__charge
      send_net_event(eid, CmdExplodeCore(exploadAt = act.curTime + wandering_core__exploadDelay))


[es(tag=server, REQUIRE_NOT=wandering_core__exploadAt)]
def curios_wandering_core_on_stone_hit(evt : EventStoneHit;
                                       wandering_core__stoneHitCd : float;
                                       wandering_core__chargePerStoneHit : float;
                                       var wandering_core__lastStoneHitAt : float&;
                                       var wandering_core__charge : float&)
  let t = get_sync_time()
  if t - wandering_core__lastStoneHitAt > wandering_core__stoneHitCd
    wandering_core__lastStoneHitAt = t
    wandering_core__charge += wandering_core__chargePerStoneHit


[es(tag=server, REQUIRE_NOT=wandering_core__exploadAt)]
def curios_wandering_core_on_projectile_hit(evt : CmdApplyDamage;
                                            wandering_core__chargePerHpLost : float;
                                            var wandering_core__charge : float&;
                                            var hitpoints__hp : float&)
  hitpoints__hp += evt.deltaHp
  wandering_core__charge += evt.deltaHp * wandering_core__chargePerHpLost


[es(tag=server, REQUIRE_NOT=wandering_core__exploadAt, before=update_wandering_core_charge)] //uses the same dt
def wandering_core_am_sensitivity(act : UpdateStageInfoAct; // can't PUFD because grid
                                  transform : float3x4;
                                  wandering_core__amChargeMulti : float;
                                  wandering_core__playerAmChargeMulti : float;
                                  wandering_core__amChargeRadius : float;
                                  wandering_core__chargeUpdtAt : float;
                                  wandering_core__lastUpdatePos : float3;
                                  var wandering_core__trackedObjectPos : Point3List;
                                  var wandering_core__trackedObjectEid : EidList;
                                  var wandering_core__charge : float&)
  if act.curTime > wandering_core__chargeUpdtAt
    let sphere = BSphere3(transform[3], wandering_core__amChargeRadius * 2.0)
    var affected : array<tuple<eid : EntityId; pos : float3>>

    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      charge_from_am_soource(human_eid,
                              wandering_core__lastUpdatePos,
                              transform[3],
                              wandering_core__playerAmChargeMulti,
                              affected,
                              wandering_core__trackedObjectPos,
                              wandering_core__trackedObjectEid,
                              wandering_core__charge)
    for_each_entity_in_grid(ecs_hash("interactable"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      charge_from_am_soource(human_eid,
                              wandering_core__lastUpdatePos,
                              transform[3],
                              wandering_core__amChargeMulti,
                              affected,
                              wandering_core__trackedObjectPos,
                              wandering_core__trackedObjectEid,
                              wandering_core__charge)
    for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      charge_from_am_soource(human_eid,
                              wandering_core__lastUpdatePos,
                              transform[3],
                              wandering_core__amChargeMulti,
                              affected,
                              wandering_core__trackedObjectPos,
                              wandering_core__trackedObjectEid,
                              wandering_core__charge)
    for_each_entity_in_grid(ecs_hash("vehicles"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      charge_from_am_soource(human_eid,
                              wandering_core__lastUpdatePos,
                              transform[3],
                              wandering_core__amChargeMulti,
                              affected,
                              wandering_core__trackedObjectPos,
                              wandering_core__trackedObjectEid,
                              wandering_core__charge)
    clear(wandering_core__trackedObjectPos)
    clear(wandering_core__trackedObjectEid)
    for af in affected
      wandering_core__trackedObjectPos |> push(af.pos)
      wandering_core__trackedObjectEid |> push(af.eid)


def charge_from_am_soource(eid : EntityId;
                           last_pos : float3;
                           this_pos : float3;
                           mult : float;
                           var affected : array<tuple<eid : EntityId; pos : float3>>;
                           var wandering_core__trackedObjectPos : Point3List;
                           var wandering_core__trackedObjectEid : EidList;
                           var wandering_core__charge : float&)
  query(eid) <| $ [es(REQUIRE=chargesWanderingCore)] (transform : float3x4;
                                                      am_storage__value : int = 0;
                                                      item__count : int = 0;
                                                      wandering_core_am_equivalent__value = 0)
    let amVal = am_storage__value + item__count + wandering_core_am_equivalent__value
    if amVal > 0
      affected |> push((eid, transform[3]))
      for idx, trackedEid in iter_range(wandering_core__trackedObjectEid), wandering_core__trackedObjectEid
        if trackedEid == eid
          let prevPos = wandering_core__trackedObjectPos[idx]
          let v1 = prevPos - last_pos
          let v2 = transform[3] - this_pos
          let dAngle = acos(clamp(dot(v1, v2) * safeinv(length(v1)) * safeinv(length(v2)), -1.0, 1.0))
          wandering_core__charge += abs(dAngle) * mult * float(amVal)
          break


[es]
def wandering_core_explosion_triggered(evt : CmdExplodeCore; eid : EntityId; wandering_core__triggeredTemplate : string)
  addSubTemplate(eid, wandering_core__triggeredTemplate) <| $(init)
    init |> set("wandering_core__exploadAt", evt.exploadAt)


[es(tag=server, no_order)]
def wandering_core_explosion_process(act : UpdateStageInfoAct;
                                     eid : EntityId;
                                     transform : float3x4;
                                     var wandering_core__damageSphere : EntityId&;
                                     wandering_core__damageSphereTemplate : string;
                                     wandering_core__explosionTemplate : string;
                                     var wandering_core__exploadAt : float&)
  if (act.curTime > wandering_core__exploadAt)
    wandering_core__exploadAt += 999999.9 //don't double-fire
    wandering_core_explode(eid,
                          wandering_core__damageSphere,
                          transform,
                          wandering_core__damageSphereTemplate,
                          wandering_core__explosionTemplate)


[es(tag=gameClient, before=wandering_core_fx_update)]
def spawn_wandering_core_charge_fx(act : ParallelUpdateFrameDelayed;
                                   transform : float3x4;
                                   wandering_core__charge : float;
                                   wandering_core__chargeFx : string;
                                   wandering_core__oscilateDuration : float;
                                   var wandering_core__oscilateStart : float&;
                                   var wandering_core__oscilateUntil : float&;
                                   var wandering_core__prevCharge : float&)
  if wandering_core__charge > wandering_core__prevCharge
    if wandering_core__oscilateUntil < act.curTime
      wandering_core__oscilateStart = act.curTime
      wandering_core__oscilateUntil = act.curTime + wandering_core__oscilateDuration
    elif wandering_core__oscilateUntil - act.curTime < wandering_core__oscilateDuration
      wandering_core__oscilateUntil += wandering_core__oscilateDuration //keep periods full
    createEntity(wandering_core__chargeFx) <| $(init)
      init |> set("transform", transform)
  wandering_core__prevCharge = wandering_core__charge


[es(tag=server, no_order, REQUIRE_NOT=waypointless_core)]
def curious_core_update(act : UpdateStageInfoAct;//can't PUFD because grid
                        eid : EntityId;
                        transform : float3x4;
                        curious_core__interval : float;
                        curious_core__curiosityInterval : float2;
                        curious_core__presenceFadeMult : float;
                        curious_core__gridCellSize : float;
                        curious_core__gridSizeX : int;
                        curious_core__gridMin : float3;
                        wandering_core__targetEid : EntityId;
                        curious_core__curiosityCell : int;
                        var curious_core__grid : FloatList;
                        var curious_core__updateAt : float&;
                        var curious_core__exploreCuriosityAt : float&)
  if curious_core__updateAt < act.curTime
    let dt = act.curTime - curious_core__updateAt + curious_core__interval
    curious_core__updateAt = act.curTime + curious_core__interval
    for v in curious_core__grid
      v = max(.0, v - dt * curious_core__presenceFadeMult)
    let meAt = pos_to_grid_cell(transform[3], curious_core__gridMin, curious_core__gridCellSize, curious_core__gridSizeX)
    if meAt >= 0 && meAt < length(curious_core__grid)
      curious_core__grid[meAt] += dt

    var seed = wandering_core_time_dependent_seed(eid, act.curTime)
    let nextCuriosity = act.curTime + _rnd_float(seed, curious_core__curiosityInterval)
    if curious_core__curiosityCell != -1 || wandering_core__targetEid != INVALID_ENTITY_ID
      curious_core__exploreCuriosityAt = nextCuriosity
    elif curious_core__exploreCuriosityAt < act.curTime
      if curious_core__exploreCuriosityAt == .0
        curious_core__exploreCuriosityAt = nextCuriosity
        return
      curious_core__exploreCuriosityAt = nextCuriosity
      init_curiosity_cell(eid)


[es(tag=server, no_order)]
def wandering_core_embryo_update(act : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 transform aka embryo_transform : float3x4;
                                 wandering_core__waypointsEid : EntityId;
                                 embryo__spawnTemplate : string;
                                 embryo__myTemplate : string;
                                 embryo__interval : float;
                                 embryo__humanSearchRadius : float;
                                 var embryo__updateAt : float&)
  if embryo__updateAt < act.curTime
    embryo__updateAt = act.curTime + embryo__interval
    if wandering_core__waypointsEid != INVALID_ENTITY_ID
      query(wandering_core__waypointsEid) <| $ [es] (navmesh_waypoints__waypoints : Point3List;
                                                     navmesh_waypoints__localSpace : bool;
                                                     transform aka waypoints_transform : float3x4;
                                                     navmesh_waypoints__projectedWaypoints : Point3List const?)
        let useProjected = navmesh_waypoints__projectedWaypoints != null
        let sortedWP = sort_waypoint(embryo_transform[3],
                                      useProjected ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints,
                                      useProjected ? false : navmesh_waypoints__localSpace,
                                      waypoints_transform)
        for wp in sortedWP
          if try_spawn_at_point(wp.pos,
                                embryo__humanSearchRadius,
                                embryo__spawnTemplate,
                                embryo__myTemplate,
                                eid,
                                embryo__updateAt)
            break
    else
      try_spawn_at_point(embryo_transform[3],
                         embryo__humanSearchRadius,
                         embryo__spawnTemplate,
                         embryo__myTemplate,
                         eid,
                         embryo__updateAt)


def try_spawn_at_point(pos : float3; radius : float; templ_plus, templ_minus : string; my_eid : EntityId; var embryo__updateAt : float&)
  let success = !find_entity_in_grid(ecs_hash("humans"),
                                        BSphere3(pos, radius),
                                        GridEntCheck.POS) <| $(human_eid : EntityId)
    var humanFound = false
    query(human_eid) <| $ [es(REQUIRE=heroForPlayer, REQUIRE_NOT=deadEntity)] ()
      humanFound = true
    return humanFound
  if success
    let templ1 = remove_any_sub_template(getEntityTemplateName(my_eid), templ_minus)
    let templ2 = templ1 == "" ? templ_plus : add_sub_template_name(templ1, templ_plus)
    remote_recreate_entity_from(my_eid, templ2)
    embryo__updateAt = FLT_MAX
  return success

//a hack because remove_sub_template_name doesn't remove the first template
def remove_any_sub_template(str : string; templ_minus : string) : string
  let str1 = replace(str, templ_minus, "")
  let str2 = replace(str1, "++", "+")
  if starts_with(str2, "+")
    return slice(str2, 1)
  if ends_with(str2, "+")
    return slice(str2, 0, length(str2) - 1)
  return str2


def sort_waypoint(pos : float3; waypoints : Point3List; local_space : bool; transform : float3x4)
  var res : array<tuple<pos : float3; distSq : float>>
  for wp in waypoints
    let p = local_space ? transform * wp : wp
    let dstSq = distance_sq(p, pos)
    res |> emplace((p, dstSq))
    sort(res) <| $(lhs, rhs)
      return lhs.distSq < rhs.distSq
  return <- res


[es(tag=server, on_appear, REQUIRE_NOT=embryo__updateAt, before=wandering_core_bind_to_waypoints)]
def init_patrol_radius_from_span_pos(evt : Event;
                                     eid : EntityId;
                                     wandering_core__waypointsEid : EntityId;
                                     var wandering_core__patrolRadius : float&)
  find_query() <| $ [es] (spawn_pos__managedEntityEid : EntityId; wandering_core_spawn__radius = .0)
    if spawn_pos__managedEntityEid == eid
      if wandering_core__waypointsEid == INVALID_ENTITY_ID && wandering_core__patrolRadius <= .0
        wandering_core__patrolRadius = wandering_core_spawn__radius
      return true
    return false


[es(tag=server, on_appear, before=wandering_core_bind_to_waypoints)]
def init_wandering_core_embryo_search_radius(evt : Event; var wandering_core__waypointSearchRadius : float&; embryo__spawnTemplate : string)
  var templ = getTemplateByName(embryo__spawnTemplate)
  if templ == null
    templ = buildTemplateByName(embryo__spawnTemplate)
  if templ != null
    wandering_core__waypointSearchRadius = getTemplateComponent(*templ, "wandering_core__waypointSearchRadius") ?? .0


