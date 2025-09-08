require ecs
require ecs.safe
require app
require net
require DagorRandom
require DagorMath
require math.base
require math.random
require danetlibs.swarm.main.swarm_events
require game.es.inventory_drop_common
require game.events.events_active_matter


[es(on_appear, REQUIRE=hasHive)]
def swarm_cluster_hive_pos(evt : Event; var swarm_cluster__targetPos : float3&; var swarm_cluster__hivePos : float3&; transform : float3x4)
  swarm_cluster__hivePos = transform[3]
  swarm_cluster__targetPos = transform[3]


[es(on_appear)]
def swarm_cluster_init_position(evt : Event; var position : float3&; transform : float3x4)
  position = transform[3]


// Assume that this event is sent only by the killing client
[es(tag=gameClient, on_event=EventSomeSwarmBoidDied)]
def swarm_cluster_request_open_note(evt : Event; death_note__name : string)
  find_query() <| $ [es] (eid aka player_eid : EntityId; is_local : bool; active_matter_player__unlockedNotes : StringList)
    if !is_local
      return false

    if !has_value(active_matter_player__unlockedNotes, death_note__name)
      send_net_event(player_eid, CmdOpenSwarmNote())
    return true


[es(tag=server)]
def swarm_cluster_boid_died_server(evt : EventSomeSwarmBoidDied;
                                   eid : EntityId;
                                   var swarm_cluster__serverCount : int&;
                                   swarm_cluster__destroyOnAllBoidDies : Tag const?)
  if swarm_cluster__serverCount > 0
    swarm_cluster__serverCount -= 1

  if swarm_cluster__serverCount == 0 && swarm_cluster__destroyOnAllBoidDies != null
    print("swarm_cluster: swarm {eid} totally destroyed")
    destroyEntity(eid)


[es(tag=server)]
def swarm_drop_loot_on_boid_died(evt : EventSomeSwarmBoidDied;
                                 deathDrop : Array)
  for loot in deathDrop
    let lootObj = get_ecs_object(loot)
    if lootObj != null
      let chance = (*lootObj).chance ?? 0.0
      if chance > gfrnd()
        let templateName = get_ecs_string(*lootObj, "proto")
        if templateName != null
          createEntity("{string(*templateName)}+item_in_world") <| $(var init : ComponentsInitializer)
            var tm = IDENT_TM
            tm[3] = evt.pos
            drop_item_on_ground(tm)
            init |> set("transform", tm)


[es(tag=server)]
def swarm_cluster_boid_died_last_time(evt : EventSomeSwarmBoidDied;
                                      var swarm_cluster__lastHitReactionTime : float&)
  swarm_cluster__lastHitReactionTime = get_sync_time()


[es(tag=server, on_appear)]
def swarm_cluster_decrease_aggressive_swarm_init(evt : Event;
                                                 swarm_cluster__hearingRange : float;
                                                 swarm_cluster__visibilityRange : float;
                                                 aggressive_swarm__nearSwarmsAggressionCheckTime : float;
                                                 var aggressive_swarm__baseHearingRange : float&;
                                                 var aggressive_swarm__baseVisibilityRange : float&;
                                                 var aggressive_swarm__nearSwarmsAggressionCheckAt : float&)
  aggressive_swarm__baseHearingRange = swarm_cluster__hearingRange
  aggressive_swarm__baseVisibilityRange = swarm_cluster__visibilityRange
  aggressive_swarm__nearSwarmsAggressionCheckAt = get_sync_time() + aggressive_swarm__nearSwarmsAggressionCheckTime


[es(tag=server)]
def swarm_cluster_increase_aggression_level_by_hit(evt : EventSomeSwarmBoidDied;
                                                   var aggressive_swarm__aggressionLevel : float&)
  aggressive_swarm__aggressionLevel = 1f


[es(tag=server, no_order)]
def swarm_cluster_decrease_aggression_level_by_time(evt : ParallelUpdateFrameDelayed;
                                                    attract_point__eid, swarm_cluster__target : EntityId;
                                                    transform aka swarm_transform : float3x4;
                                                    var aggressive_swarm__aggressionLevel : float&;
                                                    aggressive_swarm__aggressionReduceSpd = 1f;
                                                    swarm_cluster__hearingRange = 300.f)
  var hasAttractPoint = false
  query(attract_point__eid) <| $ [es] (transform : float3x4)
    hasAttractPoint = (
         attract_point__eid |> has("smellAttractPoint")
      || distance_sq(transform[3], swarm_transform[3]) <= square(swarm_cluster__hearingRange)
    )
  if hasAttractPoint || swarm_cluster__target != INVALID_ENTITY_ID
    aggressive_swarm__aggressionLevel = 1f
  else
    aggressive_swarm__aggressionLevel -= evt.dt * aggressive_swarm__aggressionReduceSpd
    if aggressive_swarm__aggressionLevel < 0f
      aggressive_swarm__aggressionLevel = 0f


[es(tag=server, after=swarm_cluster_decrease_aggression_level_by_time)]
def swarm_cluster_check_aggression_near_swarms(evt : ParallelUpdateFrameDelayed;
                                               eid : EntityId;
                                               swarm_cluster__hearingRange : float;
                                               transform : float3x4;
                                               aggressive_swarm__nearSwarmsAggressionCheckTime : float;
                                               var aggressive_swarm__aggressionLevel aka our_aggressive_swarm__aggressionLevel : float&;
                                               var aggressive_swarm__nearSwarmsAggressionCheckAt : float&)
  if aggressive_swarm__nearSwarmsAggressionCheckAt <= evt.curTime
    return
  aggressive_swarm__nearSwarmsAggressionCheckAt = evt.curTime + aggressive_swarm__nearSwarmsAggressionCheckTime

  let ourPosition = transform[3]
  let ourEid = eid
  query() <| $ [es] (eid : EntityId; swarm_cluster__aggressionLevel : float; transform : float3x4)
    if eid != ourEid && length_sq(ourPosition - transform[3]) <= swarm_cluster__hearingRange
      our_aggressive_swarm__aggressionLevel = max(our_aggressive_swarm__aggressionLevel, swarm_cluster__aggressionLevel)


[es(tag=server, after=swarm_cluster_decrease_aggression_level_by_time)]
def swarm_cluster_modify_sensitivity_by_aggression_level(evt : ParallelUpdateFrameDelayed;
                                                         aggressive_swarm__aggressionLevel : float;
                                                         aggressive_swarm__baseHearingRange : float;
                                                         aggressive_swarm__baseVisibilityRange : float;
                                                         aggressive_swarm__aggressionSensitivityMult : float;
                                                         var swarm_cluster__hearingRange : float&;
                                                         var swarm_cluster__visibilityRange : float&)
  let maxMult = aggressive_swarm__aggressionSensitivityMult
  swarm_cluster__hearingRange = aggressive_swarm__baseHearingRange * lerp(1f, maxMult, aggressive_swarm__aggressionLevel)
  swarm_cluster__visibilityRange = aggressive_swarm__baseVisibilityRange * lerp(1f, maxMult, aggressive_swarm__aggressionLevel)


[es(tag=gameClient, no_order, REQUIRE=swarm__distanceOptimization)]
def update_swarm_visibility(evt : ParallelUpdateFrameDelayed;
                            eid aka swarm_eid : EntityId;
                            transform : float3x4 const?;
                            game_effect__attachedTo : EntityId const?;
                            swarm__visibleDistSq : float;
                            swarm__invisibleDistSq : float;
                            swarm__disableBoidUpdateTemplate : string;
                            swarm__updatableBoidRatio : float;
                            count : int;
                            radius : float;
                            var swarm__visible : bool&)
  if transform == null && game_effect__attachedTo == null
    return
  var swarmPosition = float3(0.0)
  if transform != null
    swarmPosition = (*transform)[3]
  else
    query(*game_effect__attachedTo) <| $ [es] (transform : float3x4)
      swarmPosition = transform[3]

  var becameVisible = true
  var becameInvisible = false
  query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if camera__active
      becameVisible = distance_sq(swarmPosition, camera_transform[3]) < swarm__visibleDistSq
      becameInvisible = distance_sq(swarmPosition, camera_transform[3]) > swarm__invisibleDistSq
  let previousVisible = swarm__visible
  if !previousVisible && becameVisible
    query() <| $ [es(REQUIRE=boid__disabled)] (eid aka boid_eid, parentSwarm : EntityId;
                                               var position : float3&)
      if swarm_eid != parentSwarm
        return
      boid_eid |> removeSubTemplate(swarm__disableBoidUpdateTemplate)
      let shift = normalize(float3(rnd_float(-1.0, 1.0), rnd_float(-1.0, 1.0), rnd_float(-1.0, 1.0)))
      position = swarmPosition + normalize(shift) * radius
    swarm__visible = true
  elif previousVisible && becameInvisible
    var updatableCount = 0
    // move boids
    query() <| $ [es] (eid aka boid_eid, parentSwarm : EntityId;
                       var position : float3&)
      if swarm_eid != parentSwarm
        return
      if updatableCount < int(float(count) * swarm__updatableBoidRatio)
        updatableCount += 1
        return
      // make boid unupdatable
      boid_eid |> addSubTemplate(swarm__disableBoidUpdateTemplate)
      position = float3(0)
    swarm__visible = false


[es(tag=gameClient, no_order)]
def set_cluster_rot_speed_based_on_count(act : ParallelUpdateFrameDelayed;
                                         count : int;
                                         swarm_cluster__maxCount : int;
                                         swarm__rotSpeedPerCount : float2;
                                         var swarm__rotSpeed : float&)
  swarm__rotSpeed = cvt(float(count), .0, float(swarm_cluster__maxCount), swarm__rotSpeedPerCount.y, swarm__rotSpeedPerCount.x)


[es(tag=gameClient, track=swarm_cluster__serverCount, REQUIRE_NOT=swarm_cluster__nextServerCatchUp)]
def replenish_boids(evt : Event; swarm_cluster__serverCount : int; var count : int&; eid : EntityId)
  let delta = swarm_cluster__serverCount - count
  if delta > 0
    count += delta
    sendEvent(eid, EventSomeSwarmBoidBorn(count = delta))


[es(tag=gameClient, no_order)]
def swarm_client_catchup_to_server(upd : UpdateStageInfoAct;
                                   eid aka swarm_eid : EntityId;
                                   swarm_cluster__maxServerCatchUpPerFrame : int;
                                   swarm_cluster__serverCatchUpPeriod : float2;
                                   swarm_cluster__serverCount : int;
                                   var count : int&;
                                   var swarm_cluster__nextServerCatchUp : float&)
  if upd.curTime <= swarm_cluster__nextServerCatchUp
    return

  swarm_cluster__nextServerCatchUp = upd.curTime + rnd_float(swarm_cluster__serverCatchUpPeriod)

  let delta = sign(swarm_cluster__serverCount - count) * min(abs(swarm_cluster__serverCount - count), swarm_cluster__maxServerCatchUpPerFrame)
  count += delta
  if delta > 0
    sendEvent(swarm_eid, EventSomeSwarmBoidBorn(count = delta))
  elif delta < 0
    var removed = 0
    find_query() <| $ [es(REQUIRE_NOT=boidDead)] (eid aka boid_eid : EntityId; parentSwarm : EntityId)
      if swarm_eid != parentSwarm
        return false
      removed += 1
      destroyEntity(boid_eid)
      return -delta == removed


[es(tag=server, on_appear,
  REQUIRE=boids_spawner, REQUIRE_NOT=(steer__dasScript, flying_critters))]
def set_server_initial_boids_count(evt : Event; swarm_cluster__maxCount : int; swarm_cluster__initialCount : int const?; var swarm_cluster__serverCount : int&)
  swarm_cluster__serverCount = swarm_cluster__initialCount ?? swarm_cluster__maxCount