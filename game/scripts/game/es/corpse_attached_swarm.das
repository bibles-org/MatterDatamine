require ecs
require app
require DagorRandom
require BehNodes
require Grid
require DagorMath
require walkerai
require active_matter.game.es.moving_zone_common
require danetlibs.swarm.main.swarm_events
require game.events.events_game
require game.events.events_active_matter
require danetlibs.weapons.shell_events
require math.base
require math.random
require game.es.level_common
require game.es.inventory_drop_common
require game.es.inventory_item_common
require game.es.inventory_equipment_common
require RendInst
require PhysMat
require game.es.grav_zones_common
require Dacoll
require DngDm

options no_global_variables = false

var // these variables keep constant values that don't change at runtime (after set), variables for non constant values are prohibited
  BOID_DIED_REACTION_ID : int
  CORPSE_ATTACHED_SWARM_NEW_CORPSE_FOUND_ID : int
  CORPSE_ATTACHED_SWARM_REPELLED_ID : int


[register_beh_nodes]
def register_nodes()
  BOID_DIED_REACTION_ID = register_reaction("boidDied")
  CORPSE_ATTACHED_SWARM_NEW_CORPSE_FOUND_ID = register_reaction("newCorpseFound")
  CORPSE_ATTACHED_SWARM_REPELLED_ID = register_reaction("swarmRepelled")


def private get_ground_pos_from_air(in_air_pos : float3) : float3
  let gravDir = get_grav_dir(in_air_pos)
  var height = 300.f
  var norm = float3()
  var res = in_air_pos
  var pmid = -1
  let matId = get_material_id("itemDropRayMat")
  var riDesc = RendInstDesc()
  if traceray_normalized(res, gravDir, height, pmid, norm, ETF_DEFAULT, riDesc, matId)
    res += height * gravDir
  else
    let lmeshHeight = traceht_lmesh(res)
    if lmeshHeight > -1e5f
      res.y = lmeshHeight
  return res


[es(tag=server, no_order)]
def corpse_swarm_search_new_swarm(upd : UpdateStageInfoAct;
                                  transform : float3x4;
                                  eid aka swarm_eid : EntityId;
                                  swarm_cluster__radius : float;
                                  corpse_attached_swarm__ignoreCorpsesWithKillTags : StringList;
                                  corpse_attached_swarm__corpseSearchPeriod : float;
                                  corpse_attached_swarm__newCorpseSearchRadius : float;
                                  corpse_attached_swarm__searchCooldownUntil : float;
                                  var beh_tree : BehaviourTree;
                                  var corpse_attached_swarm__corpseEid : EntityId&;
                                  var corpse_attached_swarm__nextCorpseSearchAt : float&)
  if doesEntityExist(corpse_attached_swarm__corpseEid)
    return

  if upd.curTime < corpse_attached_swarm__searchCooldownUntil
    return

  if upd.curTime < corpse_attached_swarm__nextCorpseSearchAt
    return

  corpse_attached_swarm__nextCorpseSearchAt = upd.curTime + corpse_attached_swarm__corpseSearchPeriod
  let searchAroundPos = get_ground_pos_from_air(transform[3])

  var smokes : array<float4>
  query() <| $ [es] (smoke_occluder__sphere : float4)
    push(smokes, smoke_occluder__sphere)

  var fires : array<float4>
  query() <| $ [es(REQUIRE=dmgzone__fireAffect)] (dmgzone__maxRadius : float; transform aka dmgzone_transform : float3x4)
    push(fires, float4(dmgzone_transform[3], dmgzone__maxRadius))

  find_entity_in_grid(ecs_hash("humans"), BSphere3(searchAroundPos, corpse_attached_swarm__newCorpseSearchRadius), GridEntCheck.POS) <| $(target_eid : EntityId; pos : float3)
    if level_common::is_pos_indoor(pos)
      return false

    for smoke in smokes
      if distance_sq(pos, smoke.xyz) < square(smoke.w + swarm_cluster__radius)
        return false

    for fire in fires
      if distance_sq(pos, fire.xyz) < square(fire.w + swarm_cluster__radius)
        return false

    var found = false
    query(target_eid) <| $ [es(REQUIRE=deadEntity, REQUIRE_NOT=not_interesting_to_corpse_swarm)] (corpse_eaten_by_swarm__swarm : EntityId = INVALID_ENTITY_ID;
                                                                                                  kill_tracking_tag : string = "";
                                                                                                  human_net_phys__isUnderwater : bool = false)
      if human_net_phys__isUnderwater
        return
      if corpse_eaten_by_swarm__swarm != INVALID_ENTITY_ID
        return
      if kill_tracking_tag != "" && has_value(corpse_attached_swarm__ignoreCorpsesWithKillTags, kill_tracking_tag)
        return
      found = true
      corpse_attached_swarm__corpseEid = target_eid
      print("[corpse attached swarm] <{swarm_eid}> chose corpse <{target_eid}>")
      beh_tree_react(beh_tree, CORPSE_ATTACHED_SWARM_NEW_CORPSE_FOUND_ID, 0f)
    return found


[es(tag=server)]
def swarm_cluster_boid_died_react(evt : EventSomeSwarmBoidDied;
                                  var beh_tree : BehaviourTree)
  beh_tree_react(beh_tree, BOID_DIED_REACTION_ID, 0f)


[es(tag=server, after=swarm_cluster_boid_died_server)]
def corpse_attached_swarm_repel_on_boid_died(evt : EventSomeSwarmBoidDied;
                                             eid aka swarm_eid : EntityId;
                                             corpse_attached_swarm__repelWhenRatioDied : float;
                                             swarm_cluster__serverCount : int;
                                             swarm_cluster__maxCount : int)
  let targetCount = int(float(swarm_cluster__maxCount) * corpse_attached_swarm__repelWhenRatioDied)
  if swarm_cluster__serverCount <= targetCount
    sendEvent(swarm_eid, EventCorpseSwarmRepelled(repelPos = evt.pos, repelDuration = 120.0))


[es(tag=server)]
def corpse_attached_swarm_repel_on_explosion(evt : EventShellExplodedServer;
                                             shell__shell_id__shell_id : int;
                                             shell__shell_id__damage_id : int;
                                             shell__shell_id__ballistics_id : int)
  let maxRadius = get_shell_max_radius(shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id)
  query() <| $ [es] (eid : EntityId; transform : float3x4; swarm_cluster__radius : float)
    if distance_sq(transform[3], evt.pos) < square(maxRadius + swarm_cluster__radius)
      sendEvent(eid, EventCorpseSwarmRepelled(repelPos = evt.pos, repelDuration = 120.0))
  query() <| $ [es(REQUIRE_NOT=not_interesting_to_corpse_swarm)] (corpse_eaten_by_swarm__swarm : EntityId; transform aka corpse_transform : float3x4)
    if corpse_eaten_by_swarm__swarm == INVALID_ENTITY_ID
      return
    if distance_sq(corpse_transform[3], evt.pos) < square(maxRadius)
      sendEvent(corpse_eaten_by_swarm__swarm, EventCorpseSwarmRepelled(repelPos = evt.pos, repelDuration = 120.0))


def private sphere_volume(radius : float)
  return 4.0 / 3.0 * PI * square(radius) * radius


def private sphere_intersection_volume(first : float4; second : float4)
  // see https://en.wikipedia.org/wiki/Spherical_cap#Volumes_of_union_and_intersection_of_two_intersecting_spheres for details :)
  let dist = distance(first.xyz, second.xyz)
  let rSum = first.w + second.w
  if dist >= rSum
    return 0.0
  if dist <= abs(first.w - second.w)
    return sphere_volume(min(first.w, second.w))
  return (PI / (12.0 * dist)
         * square(rSum - dist)
         * (square(dist) + 2.0 * dist * (rSum) - 3.0 * square(first.w - second.w)))


def private calculate_desired_boid_kill_count(swarm_pos : float3;
                                              swarm_radius : float;
                                              explosion_pos : float3;
                                              explosion_radius : float;
                                              max_kill_ratio : float;
                                              boids_count : int) : int
  let intersectionVolume = sphere_intersection_volume(float4(swarm_pos, swarm_radius), float4(explosion_pos, explosion_radius))
  let killedRatio = intersectionVolume / sphere_volume(swarm_radius)
  let clampedRatio = clamp(killedRatio, 0.0, max_kill_ratio)
  return clamp(int(ceil(clampedRatio * float(boids_count))), 0, boids_count)


struct ExplodedSwarmInfo
  deadBoidTemplateName : string
  canKill : int
  killed : int


[es(tag=gameClient, REQUIRE=msg_sink)]
def kill_boids_on_explosion_client(evt : EventOnShellExploded)
  let maxRadius = get_shell_max_radius(int(evt.shellId), int(evt.damageId), int(evt.ballisticsId))
  var goodSwarms : table<EntityId; ExplodedSwarmInfo>
  query() <| $ [es(REQUIRE=explosionTargetSwarm)] (eid : EntityId;
                                                   transform : float3x4;
                                                   swarm_cluster__radius : float;
                                                   swarm_cluster__serverCount : int;
                                                   swarm__deadBoidTemplateName : string = "";
                                                   swarm_cluster__maxBoidsRatioKilledByExplosion : float = 1.0)
    let distSq = distance_sq(transform[3], evt.explPos)
    if distSq < square(maxRadius + swarm_cluster__radius)
      var deadBoidTemplateName : string

      if swarm__deadBoidTemplateName != ""
        deadBoidTemplateName := swarm__deadBoidTemplateName
      else
        deadBoidTemplateName := "deadBoid"

      // use serverCount to catch up to server count during the explosion
      let wantToKill = calculate_desired_boid_kill_count(transform[3], swarm_cluster__radius, evt.explPos, maxRadius, swarm_cluster__maxBoidsRatioKilledByExplosion, swarm_cluster__serverCount)

      insert(goodSwarms, eid, ExplodedSwarmInfo(deadBoidTemplateName = deadBoidTemplateName, canKill = wantToKill, killed = 0))

  query() <| $ [es(REQUIRE=boid__isHitted, REQUIRE_NOT=(boid__disabled, invulnerableBoid, boidDead))] (position : float3;
                                                                                                       parentSwarm : EntityId;
                                                                                                       eid aka boid_eid : EntityId)
    get(goodSwarms, parentSwarm) <| $(info)
      if info.canKill - info.killed <= 0
        return
      if distance_sq(position, evt.explPos) < square(maxRadius)
        info.killed += 1
        reCreateEntityFrom(boid_eid, info.deadBoidTemplateName)

  for swarm, info in keys(goodSwarms), values(goodSwarms)
    if info.killed > 0
      query(swarm) <| $ [es] (var count : int&)
        count -= info.killed


// this is server system, catching a "client" event. This is not a mistake,
// this event is also sent on the server
[es(tag=server, REQUIRE=eid)]
def kill_boids_on_explosion_server(evt : CmdShellExplodeClient)
  let maxRadius =  get_shell_max_radius(int(evt.shellId.shellId), int(evt.shellId.damageId), int(evt.shellId.ballisticsId))
  query() <| $ [es(REQUIRE=explosionTargetSwarm)] (transform : float3x4;
                                                   swarm_cluster__radius : float;
                                                   swarm_cluster__maxBoidsRatioKilledByExplosion : float = 1.0;
                                                   var swarm_cluster__serverCount : int&)
    let distSq = distance_sq(transform[3], evt.offsetedPos)
    if distSq < square(maxRadius + swarm_cluster__radius)
      let wantToKill = calculate_desired_boid_kill_count(transform[3], swarm_cluster__radius, evt.offsetedPos, maxRadius, swarm_cluster__maxBoidsRatioKilledByExplosion, swarm_cluster__serverCount)
      swarm_cluster__serverCount -= wantToKill


[es(tag=server, no_order)]
def corpse_attached_swarm_repel_on_smoke(upd : UpdateStageInfoAct;
                                         transform : float3x4;
                                         eid aka swarm_eid : EntityId;
                                         swarm_cluster__radius : float;
                                         corpse_attached_swarm__repelFromSmokeUpdateInterval : float2;
                                         corpse_attached_swarm__corpseEid : EntityId = INVALID_ENTITY_ID;
                                         var corpse_attached_swarm__repelFromSmokeUpdateAt : float&)
  if upd.curTime < corpse_attached_swarm__repelFromSmokeUpdateAt
    return

  corpse_attached_swarm__repelFromSmokeUpdateAt = upd.curTime + rnd_float(corpse_attached_swarm__repelFromSmokeUpdateInterval.x, corpse_attached_swarm__repelFromSmokeUpdateInterval.y)

  var hasCorpse = false
  var corpsePos : float3
  query(corpse_attached_swarm__corpseEid) <| $ [es] (transform aka corpse_transform : float3x4)
    corpsePos = corpse_transform[3]
    hasCorpse = true

  find_query() <| $ [es] (smoke_occluder__sphere : float4)
    if distance_sq(transform[3], smoke_occluder__sphere.xyz) < square(smoke_occluder__sphere.w + swarm_cluster__radius)
      sendEvent(swarm_eid, EventCorpseSwarmRepelled(repelPos = smoke_occluder__sphere.xyz, repelDuration = 120.0))
      return true
    if hasCorpse && distance_sq(corpsePos, smoke_occluder__sphere.xyz) < square(smoke_occluder__sphere.w + swarm_cluster__radius)
      sendEvent(swarm_eid, EventCorpseSwarmRepelled(repelPos = smoke_occluder__sphere.xyz, repelDuration = 120.0))
      return true
    return false


[es(tag=server, no_order)]
def corpse_attached_swarm_repel_on_fire(upd : UpdateStageInfoAct;
                                        transform aka swarm_transform : float3x4;
                                        eid aka swarm_eid : EntityId;
                                        swarm_cluster__radius : float;
                                        corpse_attached_swarm__repelFromFireUpdateInterval : float2;
                                        corpse_attached_swarm__corpseEid : EntityId = INVALID_ENTITY_ID;
                                        var corpse_attached_swarm__repelFromFireUpdateAt : float&)
  if upd.curTime < corpse_attached_swarm__repelFromFireUpdateAt
    return

  corpse_attached_swarm__repelFromFireUpdateAt = upd.curTime + rnd_float(corpse_attached_swarm__repelFromFireUpdateInterval.x, corpse_attached_swarm__repelFromFireUpdateInterval.y)

  var hasCorpse = false
  var corpsePos : float3
  query(corpse_attached_swarm__corpseEid) <| $ [es] (transform aka corpse_transform : float3x4)
    corpsePos = corpse_transform[3]
    hasCorpse = true

  find_query() <| $ [es(REQUIRE=dmgzone__fireAffect)] (dmgzone__maxRadius : float; transform aka dmgzone_transform : float3x4)
    if distance_sq(swarm_transform[3], dmgzone_transform[3]) < square(dmgzone__maxRadius + swarm_cluster__radius)
      sendEvent(swarm_eid, EventCorpseSwarmRepelled(repelPos = dmgzone_transform[3], repelDuration = 120.0))
      return true
    if hasCorpse && distance_sq(corpsePos, dmgzone_transform[3]) < square(dmgzone__maxRadius + swarm_cluster__radius)
      sendEvent(swarm_eid, EventCorpseSwarmRepelled(repelPos = dmgzone_transform[3], repelDuration = 120.0))
      return true
    return false


[es(tag=server, on_appear)]
def corpse_attached_swarm_init(evt : Event;
                               corpse_attached_swarm__corpseEid : EntityId;
                               var transform aka swarm_transform : float3x4&;
                               var corpse_attached_swarm__corpsePosition : float3&)
  query(corpse_attached_swarm__corpseEid) <| $ [es] (transform : float3x4)
    corpse_attached_swarm__corpsePosition = transform[3]
    swarm_transform = transform


[es(tag=server, track=am_storage__value)]
def corpse_attached_swarm_update_state_on_am_value_change(evt : Event;
                                                          am_storage__value : int;
                                                          corpse_attached_swarm__addMaxBoidsPerAm : int;
                                                          corpse_attached_swarm__addMaxDamagePerAm : float;
                                                          var swarm_cluster__serverCount : int&;
                                                          var swarm_cluster__maxDamage : float&;
                                                          var swarm_cluster__maxCount : int&;
                                                          var corpse_attached_swarm__prevAmValue : int&)
  let delta = am_storage__value - corpse_attached_swarm__prevAmValue
  corpse_attached_swarm__prevAmValue = am_storage__value
  swarm_cluster__maxDamage += float(delta) * corpse_attached_swarm__addMaxDamagePerAm
  swarm_cluster__maxCount += delta * corpse_attached_swarm__addMaxBoidsPerAm
  swarm_cluster__serverCount += delta * corpse_attached_swarm__addMaxBoidsPerAm


[es(tag=server, track=swarm_cluster__serverCount, on_appear)]
def swarm_track_server_count_change(evt : Event;
                                    swarm_cluster__serverCount : int;
                                    var corpse_attached_swarm__serverCountPrevious : int&)
  corpse_attached_swarm__serverCountPrevious = swarm_cluster__serverCount


[es(tag=server, track=swarm_cluster__serverCount, before=swarm_track_server_count_change)]
def corpse_attached_swarm_update_continuous_shooting(evt : Event;
                                                     swarm_cluster__serverCount : int;
                                                     corpse_attached_swarm__serverCountPrevious : int;
                                                     corpse_attached_swarm__repelWhenShotContinuouslyFor : float;
                                                     corpse_attached_swarm__resetContinousShotAfterSilence : float;
                                                     var corpse_attached_swarm__nextContinousShotResetAt : float&;
                                                     var corpse_attached_swarm__nextContinousShotRepelAt : float&)
  if corpse_attached_swarm__serverCountPrevious - swarm_cluster__serverCount <= 0
    return
  let curTime = get_sync_time()
  corpse_attached_swarm__nextContinousShotResetAt = curTime + corpse_attached_swarm__resetContinousShotAfterSilence
  if corpse_attached_swarm__nextContinousShotRepelAt <= 0.0
    corpse_attached_swarm__nextContinousShotRepelAt = curTime + corpse_attached_swarm__repelWhenShotContinuouslyFor


[es(tag=server, no_order)]
def corpse_attached_swarm_reset_continuous_shooting_timer(upd : UpdateStageInfoAct;
                                                          var corpse_attached_swarm__nextContinousShotResetAt : float&;
                                                          var corpse_attached_swarm__nextContinousShotRepelAt : float&)
  if corpse_attached_swarm__nextContinousShotResetAt <= 0.0 || upd.curTime <= corpse_attached_swarm__nextContinousShotResetAt
    return

  corpse_attached_swarm__nextContinousShotResetAt = -1.0
  corpse_attached_swarm__nextContinousShotRepelAt = -1.0


[es(tag=server, no_order)]
def corpse_attached_swarm_repel_on_continous_shooting(upd : UpdateStageInfoAct;
                                                      eid : EntityId;
                                                      transform : float3x4;
                                                      var corpse_attached_swarm__nextContinousShotRepelAt : float&;
                                                      var corpse_attached_swarm__nextContinousShotResetAt : float&)
  if corpse_attached_swarm__nextContinousShotRepelAt <= 0.0 || upd.curTime <= corpse_attached_swarm__nextContinousShotRepelAt
    return

  sendEvent(eid, EventCorpseSwarmRepelled(repelPos = transform[3], repelDuration = 120.0))
  corpse_attached_swarm__nextContinousShotRepelAt = -1.0
  corpse_attached_swarm__nextContinousShotResetAt = -1.0


[es(tag=server)]
def swarm_drop_am_on_boid_death(evt : EventSomeSwarmBoidDied;
                                corpse_attached_swarm__maxDroppedAmPerBoid : int;
                                var am_storage__value : int&)
  if am_storage__value <= 0
    return
  let chance = min(1.0, float(am_storage__value) * 0.1)
  if gfrnd() > chance
    return

  var amToSpawn = 1
  if am_storage__value >= corpse_attached_swarm__maxDroppedAmPerBoid
    let seed = square(gfrnd()) // more likely to drop small amounts
    amToSpawn = int(ceil(seed * float(corpse_attached_swarm__maxDroppedAmPerBoid)))
    amToSpawn = clamp(amToSpawn, 1, am_storage__value)

  am_storage__value -= amToSpawn
  let templateName = "active_matter_pile+coin_item_count_1+item_in_world"
  createEntity(templateName) <| $(var init : ComponentsInitializer)
    var tm = IDENT_TM
    tm[3] = evt.pos
    drop_item_on_ground(tm)
    set(init, "transform", tm)
    set(init, "item__count", amToSpawn)


[es(tag=gameClient, no_order)]
def corpse_gathering_effect_update(upd : UpdateStageInfoAct;
                                   eid : EntityId;
                                   corpse_swarm_gathering_effect__corpseEid : EntityId;
                                   corpse_swarm_gathering_effect__swarmEid : EntityId;
                                   corpse_swarm_gathering_effect__effectEid : EntityId)
  if !doesEntityExist(corpse_swarm_gathering_effect__corpseEid)
    destroyEntity(eid)
    return
  var corpsePosition : float3
  query(corpse_swarm_gathering_effect__corpseEid) <| $ [es] (transform : float3x4)
    corpsePosition = transform[3]

  var closestBoidPosition : float3
  var bestDist = FLT_MAX
  query() <| $ [es(REQUIRE_NOT=boid__disabled, REQUIRE=boidElement)] (position : float3; parentSwarm : EntityId)
    if parentSwarm != corpse_swarm_gathering_effect__swarmEid
      return
    let dist = distance_sq(position, corpsePosition)
    if dist < bestDist
      bestDist = dist
      closestBoidPosition = position

  if bestDist >= FLT_MAX
    return
  query(corpse_swarm_gathering_effect__effectEid) <| $ [es] (var active_matter_gather_effect__pilePos : float3&;
                                                             var active_matter_gather_effect__gatherPos : float3&)
    active_matter_gather_effect__pilePos = corpsePosition
    active_matter_gather_effect__gatherPos = closestBoidPosition


[es(tag=gameClient, on_appear)]
def corpse_swarm_gathering_effect_init(evt : Event;
                                       corpse_swarm_gathering_effect__corpseEid : EntityId;
                                       var corpse_swarm_gathering_effect__effectEid : EntityId&)
  query(corpse_swarm_gathering_effect__corpseEid) <| $ [es] (transform : float3x4)
    corpse_swarm_gathering_effect__effectEid = createEntity("active_matter_gather_effect") <| $(init)
      set(init, "active_matter_gather_effect__flySpeed", 12.0)
      set(init, "active_matter_gather_effect__requiredDistanceToTarget", 0.5)
      set(init, "active_matter_gather_effect__pilePos", transform[3])
      set(init, "active_matter_gather_effect__gatherPos", transform[3])
      set(init, "transform", transform)


[es(tag=gameClient, on_disappear)]
def corpse_swarm_gathering_effect_clean(evt : Event; corpse_swarm_gathering_effect__effectEid : EntityId)
  destroyEntity(corpse_swarm_gathering_effect__effectEid)


[es(tag=gameClient, track=corpse_attached_swarm__isGatheringAm, on_appear)]
def corpse_attached_swarm_client_show_gathering(evt : Event;
                                                eid aka swarm_eid : EntityId;
                                                corpse_attached_swarm__isGatheringAm : bool;
                                                corpse_attached_swarm__corpseEid : EntityId)
  if corpse_attached_swarm__isGatheringAm
    createEntity("corpse_swarm_gathering_effect") <| $(init)
      set(init, "corpse_swarm_gathering_effect__corpseEid", corpse_attached_swarm__corpseEid)
      set(init, "corpse_swarm_gathering_effect__swarmEid", swarm_eid)
  else
    query() <| $ [es] (eid : EntityId; corpse_swarm_gathering_effect__swarmEid : EntityId)
      if corpse_swarm_gathering_effect__swarmEid != swarm_eid
        return
      destroyEntity(eid)


[es(tag=server, on_appear)]
def corpse_eaten_by_swarm_init(evt : Event;
                               corpse_eaten_by_swarm__destroyDelayMinMax : float2;
                               var corpse_eaten_by_swarm__eatTimeLeft : float&)
  corpse_eaten_by_swarm__eatTimeLeft = rnd_float(corpse_eaten_by_swarm__destroyDelayMinMax)


[es(tag=gameClient, on_disappear, REQUIRE=corpse_attached_swarm__isGatheringAm)]
def corpse_attached_swarm_client_cleanup(evt : Event;
                                         eid aka swarm_eid : EntityId)
  query() <| $ [es] (eid : EntityId; corpse_swarm_gathering_effect__swarmEid : EntityId)
    if corpse_swarm_gathering_effect__swarmEid != swarm_eid
      return
    destroyEntity(eid)


[es(tag=server, on_appear, track=level__loadingGen, REQUIRE=level__loadingGen)]
def spawn_corpse_swarms_on_moving_zone_appeared(evt : Event; level__movingZoneInited : bool)
  if !level__movingZoneInited
    return

  find_query() <| $ [es] (corpse_swarm_manager__swarmTemplate : string;
                          corpse_swarm_manager__numSwarmsMinMax : int2;
                          var corpse_swarm_manager__finished : bool&)
    if corpse_swarm_manager__finished
      return true
    corpse_swarm_manager__finished = true
    let numSwarms = rnd_int(corpse_swarm_manager__numSwarmsMinMax)
    let movingZone = get_target_moving_zone()
    for _ in range(numSwarms)
      let pos2d = rnd_point_on_ring(movingZone.radius * 0.8, movingZone.radius * 0.95)
      var tm = IDENT_TM
      tm[3] = float3(pos2d.x, 50.0, pos2d.y) + movingZone.pos
      createEntity(corpse_swarm_manager__swarmTemplate) <| $(init)
        set(init, "transform", tm)
        set(init, "patroller__aroundPos", movingZone.pos + float3(0.0, 50.0, 0.0))
        set(init, "patroller__radius", movingZone.radius * 0.95)
    return true


[es(tag=server, on_event=EventCorpseEaten, REQUIRE_NOT=not_interesting_to_corpse_swarm)]
def corpse_with_inventories_eaten_by_swarm(evt : Event;
                                           eid aka corpse_eid : EntityId;
                                           ragdoll_phys_obj__physObjEid : EntityId const?;
                                           attachable_suit_controller__suitType : int const?;
                                           var itemContainer : EidList?)
  query() <| $ [es(REQUIRE_NOT=item__dontUnequipOnDeath)] (item__humanOwnerEid : EntityId; equipable_item__curSlot : string)
    if item__humanOwnerEid != corpse_eid || equipable_item__curSlot == ""
      return
    unequip_equipment_from_slot(equipable_item__curSlot, item__humanOwnerEid)

  var allItems : array<EntityId>
  if itemContainer != null
    assume container = *itemContainer
    for item in container
      allItems |> push(item)
  if ragdoll_phys_obj__physObjEid != null
    query(*ragdoll_phys_obj__physObjEid) <| $ [es] (itemContainer : EidList)
      for item in itemContainer
        allItems |> push(item)

  shuffle(allItems)
  let itemsDestroyRatio = rnd_float(0.0, 0.25)
  let numItemsToDestroy = int(float(length(allItems)) * itemsDestroyRatio)
  for i in iter_range(allItems)
    assume item = allItems[i]
    if i < numItemsToDestroy
      destroyEntity(item)
    else
      drop_item_from_inventory_container(item, corpse_eid)

  addSubTemplate(eid, "not_interesting_to_corpse_swarm")
  if attachable_suit_controller__suitType != null
    find_query() <| $ [es(REQUIRE=item__chronogene)] (eid aka suit_eid : EntityId; slot_attach__slotName : string; item__humanOwnerEid : EntityId)
      if item__humanOwnerEid != corpse_eid || slot_attach__slotName != "suit"
        return false
      destroyEntity(suit_eid)
      return true
    let suitTempl = (*attachable_suit_controller__suitType) == 0 ? "suit_militant_bloody_item" : "suit_militant_female_bloody_item"
    create_item_in_equipment(suitTempl, "chronogene_primary_1", eid)


[es(on_appear, tag=server, REQUIRE=not_interesting_to_corpse_swarm)]
def swarms_eaten_swarm_detract(evt : Event; eid aka corpse_eid : EntityId; transform : float3x4)
  query() <| $ [es] (eid aka swarm_eid : EntityId; corpse_attached_swarm__corpseEid : EntityId)
    if corpse_attached_swarm__corpseEid != corpse_eid
      return
    sendEvent(eid, EventCorpseSwarmRepelled(repelPos = transform[3], repelDuration = 120.0))


[es(tag=server, on_event=EventCorpseSwarmRepelled)]
def corpse_attached_swarm_forget_corpse_on_repelling(evt : Event;
                                                     corpse_attached_swarm__searchCooldownAfterRepelled : float;
                                                     var corpse_attached_swarm__searchCooldownUntil : float&;
                                                     var corpse_attached_swarm__corpseEid : EntityId&)
  query(corpse_attached_swarm__corpseEid) <| $ [es] (var corpse_eaten_by_swarm__swarm : EntityId&)
    corpse_eaten_by_swarm__swarm = INVALID_ENTITY_ID

  corpse_attached_swarm__corpseEid = INVALID_ENTITY_ID

  corpse_attached_swarm__searchCooldownUntil = max(corpse_attached_swarm__searchCooldownUntil, get_sync_time() + corpse_attached_swarm__searchCooldownAfterRepelled)


[es(tag=server)]
def repel_swarm(evt : EventCorpseSwarmRepelled;
                var beh_tree : BehaviourTree;
                var corpse_attached_swarm__detractUntil : float&;
                var corpse_attached_swarm__detractPos : float3&)
  let curTime = get_sync_time()

  if curTime >= corpse_attached_swarm__detractUntil // not being repelled already
    corpse_attached_swarm__detractPos = evt.repelPos
  corpse_attached_swarm__detractUntil = max(curTime + evt.repelDuration, corpse_attached_swarm__detractUntil)

  beh_tree_react(beh_tree, CORPSE_ATTACHED_SWARM_REPELLED_ID, 0f)
