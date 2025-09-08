require app
require ecs
require game.es.ecs_common
require level
require DagorRandom
require math.base
require math.random
require game.es.extraction_point.extraction_point_common
require game.es.dynamic_zone_mode_common
require game.events.events_game
require game.events.events_active_matter
require game.utils.team
require DagorSystem
require DagorMath
require net


def generate_point_in_circles_intersection(circle0_pos : float2;
                                           circle0_radius : float;
                                           circle1_pos : float2;
                                           circle1_radius : float;
                                           max_attempts : int = 100)
  let distSq = distance_sq(circle0_pos, circle1_pos)
  if distSq < 1e-6
    return circle0_pos + rnd_point_on_disk(min(circle0_radius, circle1_radius))

  let dist = sqrt(distSq)
  if dist > circle0_radius + circle1_radius
    logerr("Circles are not intersected!
circle0_pos={circle0_pos}
circle0_radius={circle0_radius}
circle1_pos={circle1_pos}
circle1_radius={circle1_radius}")
    return (circle0_pos + circle1_pos) * 0.5

  for _ in range(max_attempts)
    let point = circle0_pos + rnd_point_on_disk(circle0_radius)
    let toCircle1DistSq = distance_sq(point, circle1_pos)

    if toCircle1DistSq < square(circle1_radius)
      return point

  // Fallback - point in intersection circle
  let t = (square(circle0_radius) - square(circle1_radius) + distSq) / (2.0 * dist)
  let intersectionPoint = circle0_pos + t * (circle1_pos - circle0_pos) / dist
  let intersectionRadius = min(circle0_radius - t, circle1_radius - (dist - t))
  return intersectionPoint + rnd_point_on_disk(intersectionRadius)


def generate_shrinks(initial_radius : float;
                     initial_pos : float3;
                     final_radius : float;
                     final_pos : float3;
                     final_radius_safe_offset : float;
                     shrinks_count : int;
                     var out_shrinks_pos_and_radius : Point4List)
  if shrinks_count > 1
    let shrinkDeltaRadius = (initial_radius - final_radius) / float(shrinks_count)

    let finalRadiusWithSafeOffset = final_radius + final_radius_safe_offset

    var parentCirclePos = initial_pos.xz
    var parentCircleRadius = initial_radius

    for i in range(shrinks_count - 1)
      let radius = initial_radius - shrinkDeltaRadius * float(i + 1)

      let circleInsideParentRadius = max(0.0, parentCircleRadius - radius)
      let circleAroundFinalRadius = max(0.0, radius - finalRadiusWithSafeOffset)

      let pos = generate_point_in_circles_intersection(parentCirclePos, circleInsideParentRadius,
                                                       final_pos.xz, circleAroundFinalRadius)

      parentCirclePos = pos
      parentCircleRadius = radius

      let y = lerp(initial_pos.y, final_pos.y, float(i) / float(shrinks_count - 1))
      out_shrinks_pos_and_radius |> push(float4(pos.x, y, pos.y, radius))

  out_shrinks_pos_and_radius |> push(float4(final_pos.x, final_pos.y, final_pos.z, final_radius))


def cleanup_world_outside(zone_eid : EntityId)
  query(zone_eid) <| $ [es] (transform aka zone_transform : float3x4; sphere_zone__radius : float)
    let radiusSq = square(sphere_zone__radius)
    query() <| $ [es(REQUIRE=monstrify_trap__group)] (eid : EntityId; transform : float3x4)
      if distance_sq(transform[3], zone_transform[3]) > radiusSq
        destroyEntity(eid)


[es(tag=server, on_appear, on_event=EventLevelLoaded, after=moving_zone_init)]
def dynamic_zone_controller_init(evt : Event;
                                 dynamic_zone_controller__shrinksToFinalExtractionRng : int2;
                                 dynamic_zone_controller__finalZoneRadius : float;
                                 dynamic_zone_controller__finalZoneRadiusSafeOffset : float = 10.0;
                                 dynamic_zone_controller__extractionPointShrinkOffset : float3 = float3(0.0, 1.5, 0.0);
                                 var dynamic_zone_controller__finalExtractionPointEid : EntityId&;
                                 var dynamic_zone_controller__stormZoneEid : EntityId&;
                                 var dynamic_zone_controller__zoneWeatherEid : EntityId&;
                                 var dynamic_zone_controller__shrinksToFinalExtraction : int&;
                                 var dynamic_zone_controller__shrinksPosAndRadius : Point4List;
                                 var dynamic_zone_controller__state : int&)
  if !is_level_loaded()
    return

  // Select final extraction
  var extractionPointEids : array<EntityId>
  query() <| $ [es(REQUIRE=extraction_point)] (eid aka extraction_point_eid : EntityId;
                                               var extraction__currentState : int&)
    extractionPointEids |> push(extraction_point_eid)
    extraction__currentState = int(ExtractionPointState.DISABLED)

  if empty(extractionPointEids)
    logerr_dynamic_zone_controller("No extraction points found!")
    return

  let extractionPointIndex = rnd_int(0, length(extractionPointEids) - 1)
  dynamic_zone_controller__finalExtractionPointEid = extractionPointEids[extractionPointIndex]


  dynamic_zone_controller__shrinksToFinalExtraction = rnd_int(dynamic_zone_controller__shrinksToFinalExtractionRng)

  // Setup storm zone
  find_query() <| $ [es(REQUIRE=dynamic_storm_zone)] (eid aka dynamic_storm_zone_eid : EntityId;
                                                      sphere_zone__radius : float;
                                                      transform aka dynamic_storm_zone_transform : float3x4)
    dynamic_zone_controller__stormZoneEid = dynamic_storm_zone_eid
    let initialZoneRadius = sphere_zone__radius
    query(dynamic_zone_controller__finalExtractionPointEid) <| $ [es] (transform aka extraction_transform : float3x4)
      // Clamp final zone radius if required
      var finalZoneRadius = dynamic_zone_controller__finalZoneRadius
      let distanceToFinal = distance(dynamic_storm_zone_transform[3], extraction_transform[3])
      if distanceToFinal > finalZoneRadius + initialZoneRadius
        finalZoneRadius = distanceToFinal - initialZoneRadius

      generate_shrinks(initialZoneRadius, dynamic_storm_zone_transform[3],
                      finalZoneRadius,
                      extraction_transform[3] + rotate(extraction_transform, dynamic_zone_controller__extractionPointShrinkOffset),
                      dynamic_zone_controller__finalZoneRadiusSafeOffset,
                      dynamic_zone_controller__shrinksToFinalExtraction,
                      dynamic_zone_controller__shrinksPosAndRadius)
    return true

  if dynamic_zone_controller__stormZoneEid == INVALID_ENTITY_ID
    logerr_dynamic_zone_controller("No dynamic storm zone found!")
    return

  if empty(dynamic_zone_controller__shrinksPosAndRadius)
    logerr_dynamic_zone_controller("No shrink data were generated!")
    return


  find_query() <| $ [es(REQUIRE=dynamic_zone_weather)] (eid aka dynamic_zone_weather_eid : EntityId)
    dynamic_zone_controller__zoneWeatherEid = dynamic_zone_weather_eid
    return true

  print_dynamic_zone_controller("finalExtractionPoint={get_entity_info(dynamic_zone_controller__finalExtractionPointEid)}")
  print_dynamic_zone_controller("stormZone={get_entity_info(dynamic_zone_controller__stormZoneEid)}")
  print_dynamic_zone_controller("shrinksToFinalExtraction={dynamic_zone_controller__shrinksToFinalExtraction}")
  print_dynamic_zone_controller("shrinksPosAndRadius={dynamic_zone_controller__shrinksPosAndRadius}")

  dynamic_zone_controller__state = int(DynamicZoneControllerState.WAITING_FOR_ZONE_SHRINKING)


[es(tag=server, track=dynamic_zone_controller__state)]
def dynamic_zone_controller_track_state(evt : Event;
                                        dynamic_zone_controller__stormZoneEid : EntityId;
                                        dynamic_zone_controller__shrinksPosAndRadius : Point4List;
                                        dynamic_zone_controller__currentShrinkIndex : int;
                                        dynamic_zone_controller__waitingForZoneShrinkingTime : float;
                                        dynamic_zone_controller__zoneShrinkingTime : float;
                                        dynamic_zone_controller__waitingForZoneShrinkingTimePow : float;
                                        dynamic_zone_controller__zoneShrinkingTimePow : float;
                                        dynamic_zone_controller__finalExtractionPointEid : EntityId;
                                        dynamic_zone_controller__zoneWeatherEid : EntityId;
                                        dynamic_zone_controller__state : int;
                                        dynamic_zone_controller__shrinksToFinalExtraction : int;
                                        dynamic_zone_controller__finalZoneShrinkingTime : float;
                                        dynamic_zone_controller__finalZoneWaitingTime : float)
  assume waitingForZoneShrinkingTime = dynamic_zone_controller__waitingForZoneShrinkingTime
  assume zoneShrinkingTime = dynamic_zone_controller__zoneShrinkingTime
  assume waitingForZoneShrinkingTimePow = dynamic_zone_controller__waitingForZoneShrinkingTimePow
  assume zoneShrinkingTimePow = dynamic_zone_controller__zoneShrinkingTimePow
  assume currentShrinkIndex = dynamic_zone_controller__currentShrinkIndex
  assume shrinksToFinalExtraction = dynamic_zone_controller__shrinksToFinalExtraction
  assume shrinksPosAndRadius = dynamic_zone_controller__shrinksPosAndRadius

  print_dynamic_zone_controller("State changed: {dynamic_zone_controller__state}")

  if dynamic_zone_controller__state == int(DynamicZoneControllerState.WAITING_FOR_ZONE_SHRINKING)

    if currentShrinkIndex < 0 || currentShrinkIndex >= length(shrinksPosAndRadius)
      logerr_dynamic_zone_controller("Invalid shrink index - {currentShrinkIndex}!
shrinksPosAndRadius={shrinksPosAndRadius}")
      return

    let shrinkPos = shrinksPosAndRadius[currentShrinkIndex].xyz
    let shrinkRadius = shrinksPosAndRadius[currentShrinkIndex].w

    let waitTime = waitingForZoneShrinkingTime * pow(waitingForZoneShrinkingTimePow, float(currentShrinkIndex))
    let shrinkingTime = zoneShrinkingTime * pow(zoneShrinkingTimePow, float(currentShrinkIndex))

    if currentShrinkIndex > 0
      query(dynamic_zone_controller__zoneWeatherEid) <| $ [es] (dynamic_zone_weather__recoveryTimePerShrink : float)
        let recoveryTime = dynamic_zone_weather__recoveryTimePerShrink * float(currentShrinkIndex)
        send_net_event(dynamic_zone_controller__zoneWeatherEid, CmdZoneWeatherStopStorm(recoveryTime = recoveryTime))

    query(dynamic_zone_controller__stormZoneEid) <| $ [es] (transform aka zone_transform : float3x4;
                                                            sphere_zone__radius : float;
                                                            var moving_zone__manual_activation : bool&;
                                                            var moving_zone__sourcePos : float3&;
                                                            var moving_zone__sourceRadius : float&;
                                                            var moving_zone__targetPos : float3&;
                                                            var moving_zone__targetRadius : float&;
                                                            var moving_zone__startEndTime : float2&)
      moving_zone__manual_activation = false
      moving_zone__sourcePos = zone_transform[3]
      moving_zone__sourceRadius = sphere_zone__radius
      moving_zone__targetPos = shrinkPos
      moving_zone__targetRadius = shrinkRadius
      moving_zone__startEndTime.x = get_sync_time() + waitTime
      moving_zone__startEndTime.y = moving_zone__startEndTime.x + shrinkingTime
  elif dynamic_zone_controller__state == int(DynamicZoneControllerState.ZONE_SHRINKING)

    query(dynamic_zone_controller__stormZoneEid) <| $ [es] (moving_zone__startEndTime : float2)
      let stormTime = moving_zone__startEndTime.y - get_sync_time()
      query(dynamic_zone_controller__zoneWeatherEid) <| $ [es] (dynamic_zone_weather__initialStormPower : float)
        let shrinkProgress = shrinksToFinalExtraction > 1 ? float(currentShrinkIndex) / float(shrinksToFinalExtraction - 1) : 1.0
        let stormPower = max(1e-6, lerp(dynamic_zone_weather__initialStormPower, 1.0, shrinkProgress))
        let riseTime = stormTime / stormPower
        send_net_event(dynamic_zone_controller__zoneWeatherEid, CmdZoneWeatherStartStorm(riseTime = riseTime))

  elif dynamic_zone_controller__state == int(DynamicZoneControllerState.EXTERMINATION)
    // Activate final extraction
    query(dynamic_zone_controller__finalExtractionPointEid) <| $ [es] (var extraction__currentState : int&)
      extraction__currentState = int(ExtractionPointState.INACTIVE)
      broadcast_net_event(EventFinalExtractionAppear(extractionPointEid = dynamic_zone_controller__finalExtractionPointEid))

    query(dynamic_zone_controller__stormZoneEid) <| $ [es] (transform aka zone_transform : float3x4;
                                                            sphere_zone__radius : float;
                                                            var moving_zone__manual_activation : bool&;
                                                            var moving_zone__sourcePos : float3&;
                                                            var moving_zone__sourceRadius : float&;
                                                            var moving_zone__targetPos : float3&;
                                                            var moving_zone__targetRadius : float&;
                                                            var moving_zone__startEndTime : float2&)
      assume shrinkingTime = dynamic_zone_controller__finalZoneShrinkingTime
      assume waitingTime = dynamic_zone_controller__finalZoneWaitingTime

      moving_zone__manual_activation = false
      moving_zone__sourcePos = zone_transform[3]
      moving_zone__sourceRadius = sphere_zone__radius
      moving_zone__targetPos = shrinksPosAndRadius[length(shrinksPosAndRadius) - 1].xyz
      moving_zone__targetRadius = 0.0
      moving_zone__startEndTime.x = get_sync_time() + waitingTime
      moving_zone__startEndTime.y = moving_zone__startEndTime.x + shrinkingTime

      send_net_event(dynamic_zone_controller__zoneWeatherEid, CmdZoneWeatherStartStorm(riseTime = shrinkingTime))


[es(tag=server)]
def dynamic_zone_controller_on_moving_zone_started(evt : EventOnMovingZoneStarted;
                                                   dynamic_zone_controller__finalExtractionPointEid : EntityId;
                                                   var dynamic_zone_controller__state : int&)
  if dynamic_zone_controller__state == int(DynamicZoneControllerState.WAITING_FOR_ZONE_SHRINKING)
    dynamic_zone_controller__state = int(DynamicZoneControllerState.ZONE_SHRINKING)
  elif dynamic_zone_controller__state == int(DynamicZoneControllerState.EXTERMINATION)
    addSubTemplate(dynamic_zone_controller__finalExtractionPointEid, "server_destroy_in_3_sec")


[es(tag=server)]
def dynamic_zone_controller_on_moving_zone_stopped(evt : EventOnMovingZoneStopped;
                                                   dynamic_zone_controller__shrinksToFinalExtraction : int;
                                                   dynamic_zone_controller__finalExtractionPointEid : EntityId;
                                                   var dynamic_zone_controller__currentShrinkIndex : int&;
                                                   var dynamic_zone_controller__state : int&)
  if dynamic_zone_controller__state == int(DynamicZoneControllerState.ZONE_SHRINKING)
    if dynamic_zone_controller__currentShrinkIndex >= dynamic_zone_controller__shrinksToFinalExtraction - 1
      dynamic_zone_controller__state = int(DynamicZoneControllerState.EXTERMINATION)
    else
      if dynamic_zone_controller__currentShrinkIndex >= dynamic_zone_controller__shrinksToFinalExtraction - 2
        // Show final extraction
        query(dynamic_zone_controller__finalExtractionPointEid) <| $ [es] (var extraction__forceMapVisible : bool&)
          extraction__forceMapVisible = true
      dynamic_zone_controller__currentShrinkIndex++
      dynamic_zone_controller__state = int(DynamicZoneControllerState.WAITING_FOR_ZONE_SHRINKING)
  elif dynamic_zone_controller__state != int(DynamicZoneControllerState.EXTERMINATION)
    logerr_dynamic_zone_controller("EventOnMovingZoneStopped unexpected state - {dynamic_zone_controller__state}!")

  cleanup_world_outside(evt.zoneEid)


// def spawn_portal_if_only_one_team_left()
//   query() <| $ [es] (dynamic_zone_controller__finalExtractionPointEid : EntityId)
//     query(dynamic_zone_controller__finalExtractionPointEid) <| $ [es] (var extraction__currentState : int&)
//       if extraction__currentState == int(ExtractionPointState DISABLED)

//         var militantTeam = TEAM_UNASSIGNED
//         let foundMoreThanOneMilitantTeam = find_query() <| $ [es(REQUIRE=am_militant, REQUIRE_NOT=deadEntity)] (team aka militant__team : int;
//                                                                                                                 isAlive : bool = true)
//           if !isAlive
//             return false

//           if militantTeam == TEAM_UNASSIGNED || militant__team == militantTeam
//             militantTeam = team
//             return false

//           return true
//         if !foundMoreThanOneMilitantTeam && militantTeam != TEAM_UNASSIGNED
//           print_dynamic_zone_controller("Only one militant team left - {militantTeam}, spawning portal!")
//           extraction__currentState = int(ExtractionPointState INACTIVE)
//           broadcast_net_event([[EventFinalExtractionAppear extractionPointEid=dynamic_zone_controller__finalExtractionPointEid]])


// [es(tag=server, REQUIRE=dynamic_zone_controller)]
// def dynamic_zone_controller_track_any_entity_died(evt : EventAnyEntityDied)
//   query(evt.victim) <| $ [es(REQUIRE=am_militant)] ()
//     spawn_portal_if_only_one_team_left()


[es(tag=server, on_appear, REQUIRE=extraction_sequence_affect)]
def dynamic_zone_controller_track_extraction_sequence_affect_appear(evt : Event)
  query() <| $ [es] (dynamic_zone_controller__finalExtractionPointEid : EntityId)
    addSubTemplate(dynamic_zone_controller__finalExtractionPointEid, "server_destroy_in_3_sec")
