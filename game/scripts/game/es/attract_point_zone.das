require ecs
require DagorMath
require Grid
require game.events.events_active_matter

[es(tag=server, no_order)]
def inside_attraction_zone(info : ParallelUpdateFrameDelayed;
                           transform : float3x4;
                           attract_point_zone__radius : float;
                           attract_point_zone__affectTemplate : string;
                           attract_point_zone__checkDuration : float;
                           attract_point_zone__effectName : string;
                           var attract_point_zone__nextCheckTime : float&)
  if info.curTime < attract_point_zone__nextCheckTime
    return
  attract_point_zone__nextCheckTime = info.curTime + attract_point_zone__checkDuration

  var attracts : table<uint; EntityId>

  // collect all attraction zone effects
  query() <| $ [es] (eid, game_effect__attachedTo : EntityId; game_effect__attractionModName : string)
    if attract_point_zone__effectName == game_effect__attractionModName
      attracts.insert(uint(game_effect__attachedTo), eid)

  let sphere = BSphere3(transform[3], attract_point_zone__radius)

  for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(eid : EntityId)
    // If the effect has already been applied - extend it
    if attracts |> key_exists(uint(eid))
      let zoneEid = attracts.get_value(uint(eid))
      query(zoneEid) <| $ [es] (game_effect__timeToDestroy : float; var game_effect__destroyAt : float&)
        game_effect__destroyAt = info.curTime + game_effect__timeToDestroy
      return

    createEntity(attract_point_zone__affectTemplate) <| $(init)
      set(init, "game_effect__attachedTo", eid)
      set(init, "game_effect__attractionModName", attract_point_zone__effectName)
