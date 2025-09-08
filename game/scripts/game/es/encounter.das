require ecs
require game.events.events_game
require math.base
require math.random
require pathfinder
require DagorMath


[es(tag=server)]
def interesting_encounter_zone_enter(evt : EventZoneEnter;
                                     var base_interesting_encounter__visitorsList : EidList&)
  query(evt.visitorEid) <| $ [es] (possessedByPlr : EntityId)
    if !has_value(base_interesting_encounter__visitorsList, possessedByPlr)
      base_interesting_encounter__visitorsList |> push(possessedByPlr)


[es(tag=gameClient, on_appear, track=base_interesting_encounter__visitorsList)]
def interesting_encounter_zone_market_update(evt : Event;
                                             base_interesting_encounter__visitorsList : EidList;
                                             var map_object_marker__isActive : bool&)
  find_query() <| $ [es(REQUIRE=hero)] (possessedByPlr : EntityId)
    if has_value(base_interesting_encounter__visitorsList, possessedByPlr)
      map_object_marker__isActive = false
    return true


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def interesting_encounter_zone_market_init(evt : Event; possessedByPlr : EntityId)
  query() <| $ [es] (base_interesting_encounter__visitorsList : EidList; var map_object_marker__isActive : bool&)
    if has_value(base_interesting_encounter__visitorsList, possessedByPlr)
      map_object_marker__isActive = false


enum SpawnCircleRotateType
  TRANSFORM
  TO_CENTER
  FROM_CENTER
  RANDOM


[es(tag=server, on_appear)]
def spawn_circle_appear(evt : Event;
                        transform : float3x4;
                        spawn_circle__template : string;
                        spawn_circle__radius : float;
                        spawn_circle__count : int2;
                        spawn_circle__offsetRnd : float2;
                        spawn_circle__rotateType : int;
                        spawn_circle__projectToNavmeshDist : float = 1.0;
                        var spawn_circle__spawnedEntities : EidList)
  let centerPos = transform[3]
  let count = rnd_int(spawn_circle__count)

  for i in range(count)
    let progress = float(i) / float(count)
    var horzOffsVec : float3
    sincos(progress * TWOPI, horzOffsVec.z, horzOffsVec.x)
    let spawnDir = rotate(transform, horzOffsVec)

    var spawnPos = centerPos + spawnDir * spawn_circle__radius

    let offset = rnd_float(spawn_circle__offsetRnd)
    sincos(rnd_float(0.0, TWOPI), horzOffsVec.z, horzOffsVec.x)
    spawnPos += offset * rotate(transform, horzOffsVec)

    if spawn_circle__projectToNavmeshDist > 0.0
      project_to_nearest_navmesh_point(spawnPos, spawn_circle__projectToNavmeshDist)

    let newEid = createEntity(spawn_circle__template) <| $ [es] (var init : ComponentsInitializer)
      var tm = transform

      if spawn_circle__rotateType == int(SpawnCircleRotateType.TO_CENTER)
        tm[0] = -spawnDir
        tm[2] = cross(tm[0], tm[1])
      elif spawn_circle__rotateType == int(SpawnCircleRotateType.FROM_CENTER)
        tm[0] = spawnDir
        tm[2] = cross(tm[0], tm[1])
      elif spawn_circle__rotateType == int(SpawnCircleRotateType.RANDOM)
        sincos(rnd_float(0.0, TWOPI), horzOffsVec.z, horzOffsVec.x)
        tm[0] = rotate(transform, horzOffsVec)
        tm[2] = cross(tm[0], tm[1])

      tm[3] = spawnPos
      init |> set("transform", tm)

    spawn_circle__spawnedEntities |> push(newEid)


[es(tag=server, on_disappear)]
def spawn_circle_disappear(evt : Event;
                           spawn_circle__spawnedEntities : EidList)
  for eid in spawn_circle__spawnedEntities
    destroyEntity(eid)