require ecs
require math.base
require DagorSystem
require pathfinder
require game.events.events_active_matter
require danetlibs.pathfinder.main.pathfinder_common


def obtain_moving_zone_params(var out_moving_zone_center : float3&;
                              var out_moving_zone_radius_sq : float&;
                              outside_offset_dist : float)
  return find_query()  <| $ [es] (transform : float3x4;
                                  moving_zone__sourceRadius : float)
    out_moving_zone_center = transform[3]
    out_moving_zone_radius_sq = square(moving_zone__sourceRadius + outside_offset_dist)
    return true


def lair_gen_impl(transform : float3x4;
                  lair_gen__templateToSpawn : string;
                  lair_gen__dist : float;
                  lair_gen__numToSpawn : int)
  let numTries = 10
  for _i in range(lair_gen__numToSpawn)
    var navmeshPos = transform[3]
    for _j in range(numTries)
      if find_random_point_inside_circle(navmeshPos, lair_gen__dist, 1., navmeshPos)
        break
    createEntity(lair_gen__templateToSpawn) <| $(var init)
      var tm = IDENT_TM
      tm[3] = navmeshPos
      set(init, "transform", tm)


[es(tag=server, on_appear)]
def on_lair_gen(evt : Event;
                transform : float3x4;
                lair_gen__useMovingZone : Tag const?;
                lair_gen__movingZoneOutsideOffsetDist = 50.0;
                lair_gen__templateToSpawn : string;
                lair_gen__dist : float;
                lair_gen__numToSpawn : int)
  if lair_gen__useMovingZone != null
    var movingZoneCenter =  float3()
    var movingZoneRadiusSq = FLT_MAX
    let hasMovingZone = obtain_moving_zone_params(movingZoneCenter, movingZoneRadiusSq,
                                                  lair_gen__movingZoneOutsideOffsetDist)
    if !hasMovingZone || distance_sq(transform[3], movingZoneCenter) > movingZoneRadiusSq
      return
  lair_gen_impl(transform, lair_gen__templateToSpawn, lair_gen__dist, lair_gen__numToSpawn)


[es(tag=server, REQUIRE=lair_gen__useMovingZone)]
def on_lair_gen_moving_zone(evt : EventMovingZoneCreated;
                            eid : EntityId;
                            transform : float3x4;
                            lair_gen__movingZoneOutsideOffsetDist = 50.0;
                            lair_gen__templateToSpawn : string;
                            lair_gen__dist : float;
                            lair_gen__numToSpawn : int)
  var movingZoneCenter =  float3()
  var movingZoneRadiusSq = FLT_MAX
  let hasMovingZone = obtain_moving_zone_params(movingZoneCenter, movingZoneRadiusSq,
                                                lair_gen__movingZoneOutsideOffsetDist)
  if !hasMovingZone
    logerr("{eid}: <{getEntityTemplateName(eid)}> Moving zone is not exists!")
    return
  if distance_sq(transform[3], movingZoneCenter) > movingZoneRadiusSq
    return
  lair_gen_impl(transform, lair_gen__templateToSpawn, lair_gen__dist, lair_gen__numToSpawn)