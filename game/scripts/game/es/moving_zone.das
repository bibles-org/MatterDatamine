require ecs
require app
require net
require math.base
require math.random
require math.ang
require gameObject
require DagorMath
require DagorSystem
require level
require Dacoll
require ecs.common
require game.events.events_game
require game.es.status_tip_common
require game.es.extraction_point.extraction_point_common
require game.events.events_active_matter
require game.es.moving_zone_common


def drop_pos_on_ground(var pos : float3&)
  let dir = float3(0., -1., 0.)
  let offset = 100.
  let from = pos + float3(0., offset, 0.)
  var distance = offset * 2.
  var norm : float3
  if traceray_normalized(from, dir, distance, norm, ETF_FRT | ETF_LMESH)
    pos.y = from.y + dir.y * distance


[es(tag=server, on_appear, on_event=EventLevelLoaded, after=game_objects_events_es, before=ri_extra_gen_es)]
def moving_zone_init(evt : Event;
                     eid : EntityId;
                     moving_zone__manual_activation : bool;
                     moving_zone__sourcePos : float3;
                     sphere_zone__radius : float;
                     var moving_zone__isInitialized : bool&;
                     var transform aka zone_transform : float3x4&;
                     var active : bool&;
                     var moving_zone__sourceRadius, moving_zone__targetRadius : float&;
                     var moving_zone__targetPos : float3&;
                     var shrinkZoneRadius : float&;
                     var shrinkedZonePos : float2&;
                     moving_zone__sleepingTime : float;
                     var moving_zone__startEndTime : float2&)
  // we want to be sure that navmesh is initialized when sending EventMovingZoneCreated
  if moving_zone__isInitialized || !is_level_loaded()
    return
  moving_zone__isInitialized = true

  zone_transform[3] = moving_zone__sourcePos
  moving_zone__targetPos = moving_zone__sourcePos
  moving_zone__sourceRadius = sphere_zone__radius
  moving_zone__targetRadius = sphere_zone__radius
  shrinkZoneRadius = sphere_zone__radius
  shrinkedZonePos = moving_zone__sourcePos.xz

  active = false
  if !moving_zone__manual_activation
    moving_zone__startEndTime.x = get_sync_time() + moving_zone__sleepingTime

  broadcastEvent(EventMovingZoneCreated(eid = eid))


[es(tag=server, no_order)]
def moving_zone(info : ParallelUpdateFrameDelayed;
                eid : EntityId;
                moving_zone__manual_activation : bool;
                moving_zone__chooseFinalExtraction : bool;
                var active : bool&;
                moving_zone__sourcePos : float3;
                moving_zone__sourceRadius : float;
                sphere_zone__radius : float;
                var moving_zone__startEndTime : float2&;
                moving_zone__movingVelocity : float;
                var moving_zone__targetPos : float3&;
                var moving_zone__targetRadius : float&)
  if moving_zone__manual_activation
    return

  let shouldStart = moving_zone__startEndTime.x > 0.f && info.curTime >= moving_zone__startEndTime.x
  let shouldEnd = moving_zone__startEndTime.y > 0.f && info.curTime >= moving_zone__startEndTime.y

  if shouldStart && !shouldEnd && !active
    active = true
    broadcast_net_event(EventOnMovingZoneStarted(zoneEid = eid))
    if moving_zone__chooseFinalExtraction
      let finalExtractionEid = activate_random_final_extraction_point()
      if finalExtractionEid != INVALID_ENTITY_ID
        query(finalExtractionEid) <| $ [es] (transform : float3x4; extraction__radiusMinMax : float2)
          moving_zone__targetPos = transform[3]
          moving_zone__targetRadius = extraction__radiusMinMax.x * 0.5

    if moving_zone__movingVelocity > 0.f
      let ditsToTargetPos = distance(moving_zone__sourcePos, moving_zone__targetPos)
      let zoneMovingTime = (ditsToTargetPos + moving_zone__sourceRadius - moving_zone__targetRadius) / moving_zone__movingVelocity
      moving_zone__startEndTime.y = moving_zone__startEndTime.x + zoneMovingTime
    print("[moving zone]: zone activated automatically. startEndTime={moving_zone__startEndTime}")

  if active && sphere_zone__radius <= moving_zone__targetRadius
    active = false
    print("[moving zone]: zone is deactivated")
    broadcastEvent(EventOnMovingZoneStopped(zoneEid = eid))


[es(after=moving_zone)]
def moving_zone_update(info : ParallelUpdateFrameDelayed;
                       active : bool;
                       moving_zone__sourcePos : float3;
                       moving_zone__targetPos : float3;
                       moving_zone__sourceRadius : float;
                       moving_zone__targetRadius : float;
                       moving_zone__startEndTime : float2;
                       var transform aka zone_transform : float3x4&;
                       var sphere_zone__radius : float&)
  if !active
    return

  let t = cvt(get_sync_time(), moving_zone__startEndTime.x, moving_zone__startEndTime.y, 0.f, 1.f)
  sphere_zone__radius = lerp(moving_zone__sourceRadius, moving_zone__targetRadius, t)
  zone_transform[3] = lerp(moving_zone__sourcePos, moving_zone__targetPos, float3(t))


[es(REQUIRE=moving_zone__startEndTime, after=moving_zone_update)]
def moving_zone_update_client(info : ParallelUpdateFrameDelayed;
                              transform aka zone_transform : float3x4;
                              sphere_zone__radius : float)
  let sphereZoneRadiusSq = square(sphere_zone__radius)
  query() <| $ [es] (eid aka actor_eid : EntityId; transform : float3x4; var inStormZone : bool&)
    let value = distance_sq(transform[3], zone_transform[3]) > sphereZoneRadiusSq
    if value
      let ignore = find_query() <| $ [es(REQUIRE=am_storm_zone_ignore_affect)] (game_effect__attachedTo : EntityId)
        return actor_eid == game_effect__attachedTo
      if !ignore
        inStormZone = value
    else
      inStormZone = value


[es(tag=server, after=moving_zone_update)]
def moving_zone_update_server(info : ParallelUpdateFrameDelayed;
                              sphere_zone__radius : float;
                              transform aka zone_transform : float3x4;
                              moving_zone__checkSizeTime : float;
                              active : bool;
                              var moving_zone__nextSizeCheckTime : float&)
  if !active
    return

  if info.curTime > moving_zone__nextSizeCheckTime
    moving_zone__nextSizeCheckTime = info.curTime + moving_zone__checkSizeTime

    let zoneRadSq = square(sphere_zone__radius)
    query() <| $ [es(REQUIRE=spawnBase__teamSpawn)] (transform aka respbase_transform : float3x4; var active : bool&)
      active = distance_sq(zone_transform[3], respbase_transform[3]) < zoneRadSq


    query() <| $ [es(REQUIRE_NOT=final_extraction_point)] (transform aka extraction_transform : float3x4; var extraction__currentState : int&)
      if distance_sq(zone_transform[3], extraction_transform[3]) > zoneRadSq
        if extraction__currentState == int(ExtractionPointState.INACTIVE)
          extraction__currentState = int(ExtractionPointState.DISABLED)


[es(tag=gameClient, REQUIRE=hero)]
def notify_player_on_zone_start(evt : EventOnMovingZoneStarted)
  create_status_tip("status_tip_moving_zone_started")
