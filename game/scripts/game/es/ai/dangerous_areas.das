require ecs
require app
require level
require ecs.common
require math.base
require pathfinder
require game.events.events_game
require active_matter.game.utils.poly_area
require active_matter.game.es.pathfinder_utils_common
require daslib/enum_trait
require DagorSystem
require Grid
require DagorMath


let
  DEFAULT_PROJECTION_EXTENTS = float3(0.1, 2.0, 0.1)
  DEFAULT_HEIGHT_HALF_OFFSET = 1.8

  areaNames = fixed_array<string>(
    "{AMPolyArea.POLYAREA_UNWALKABLE}",
    "{AMPolyArea.POLYAREA_GROUND}",
    "{AMPolyArea.POLYAREA_OBSTACLE}",
    "{AMPolyArea.POLYAREA_JUMP}",
    "{AMPolyArea.POLYAREA_DANGER}",
    "{AMPolyArea.POLYAREA_WALKABLE_ISLE}",
    "{AMPolyArea.POLYAREA_WALKABLE}"
  )


[es(tag=server, on_appear)]
def init_dangerous_areas(evt : Event;
                         eid : EntityId;
                         entity_bound_area__name : string;
                         var entity_bound_area__num : uint8&)
  for enumValue, enumName in each_enum(type<AMPolyArea>), areaNames
    if entity_bound_area__name == enumName
      entity_bound_area__num = uint8(enumValue)
      return

  logerr("entity_bound_area: {eid}: unable to link area '{entity_bound_area__name}' to any area. Valid names are {areaNames}")


def unmark_polys(var owner_entity_bound_area__nmeshPolyRefs : UInt64List; tm : float3x4; owner_entity_bound_area__radius : float)
  var prevArea : uint8
  for polyRef in owner_entity_bound_area__nmeshPolyRefs
    get_poly_area(polyRef, prevArea)
    if prevArea == uint8(int(AMPolyArea.POLYAREA_DANGER))
      set_poly_area(polyRef, uint8(int(AMPolyArea.POLYAREA_WALKABLE)))
  owner_entity_bound_area__nmeshPolyRefs |> clear()
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("creatures")), BSphere3(tm[3], owner_entity_bound_area__radius * 2.), GridEntCheck.BOUNDING) <| $(eid : EntityId; pos : float3)
    query(eid) <| $ [es] (entity_bound_area__num : uint8;
                          entity_bound_area__nmeshPolyRefs : UInt64List;
                          entity_bound_area__radius : float;
                          isAlive : bool = true)
      if isAlive && distance_sq(tm[3], pos) <= square(owner_entity_bound_area__radius + entity_bound_area__radius)
        mark_polys(entity_bound_area__nmeshPolyRefs, entity_bound_area__num)


def mark_polys(entity_bound_area__nmeshPolyRefs : UInt64List; entity_bound_area__num : uint8)
  for polyRef in entity_bound_area__nmeshPolyRefs
    var prevArea : uint8
    get_poly_area(polyRef, prevArea)
    if prevArea == uint8(int(AMPolyArea.POLYAREA_WALKABLE))
      set_poly_area(polyRef, entity_bound_area__num)


def mark_polys_around(var entity_bound_area__nmeshPolyRefs : UInt64List&; pos : float3; entity_bound_area__num : uint8; entity_bound_area__projectExtents : float3; entity_bound_area__radius, entity_bound_area__heightHalfOffset : float)
  var center = pos
  if project_to_nearest_navmesh_point(center, entity_bound_area__projectExtents)
    find_polys_in_circle(center, entity_bound_area__radius, entity_bound_area__heightHalfOffset) <| $(polyRefs)
      entity_bound_area__nmeshPolyRefs |> resize(length(polyRefs))
      for i in iter_range(polyRefs)
        entity_bound_area__nmeshPolyRefs[i] = polyRefs[i]
      mark_polys(entity_bound_area__nmeshPolyRefs, entity_bound_area__num)


[es(tag=server, on_appear, on_event=EventTilecacheSyncFinished, after=init_dangerous_areas)]
def mark_dangerous_areas(evt : Event;
                         transform : float3x4;
                         entity_bound_area__radius : float;
                         entity_bound_area__num : uint8;
                         entity_bound_area__projectExtents = DEFAULT_PROJECTION_EXTENTS;
                         entity_bound_area__heightHalfOffset = DEFAULT_HEIGHT_HALF_OFFSET;
                         var entity_bound_area__nmeshPolyRefs : UInt64List&)
  mark_polys_around(entity_bound_area__nmeshPolyRefs, transform[3], entity_bound_area__num, entity_bound_area__projectExtents, entity_bound_area__radius, entity_bound_area__heightHalfOffset)

[es(tag=server, on_event=(EventTilecacheSyncWillBeStarted, EventEntityDied), on_disappear)]
def remove_dangerous_area(evt : Event;
                          transform : float3x4;
                          entity_bound_area__radius : float;
                          var entity_bound_area__nmeshPolyRefs : UInt64List&)
  if !is_level_unloading()
    unmark_polys(entity_bound_area__nmeshPolyRefs, transform, entity_bound_area__radius)


[es(tag=server, on_appear, before=update_dangerous_area)]
def randomize_dangerous_area_update(evt : Event;
                                    eid : EntityId;
                                    entity_bound_area__updateInterval : float;
                                    var entity_bound_area__nextUpdate : float&)
  entity_bound_area__nextUpdate = get_sync_time() + entity_bound_area__updateInterval * eid_frnd(eid)


[es(tag=server, before=remove_dangerous_area, REQUIRE_NOT=deadEntity)]
def update_dangerous_area(act : UpdateStageInfoAct;
                          transform : float3x4;
                          entity_bound_area__radius : float;
                          entity_bound_area__num : uint8;
                          entity_bound_area__projectExtents = DEFAULT_PROJECTION_EXTENTS;
                          entity_bound_area__heightHalfOffset = DEFAULT_HEIGHT_HALF_OFFSET;
                          entity_bound_area__updateInterval : float;
                          entity_bound_area__negligibleDstSq : float = 1.0;
                          var entity_bound_area__lastPos : float3&;
                          var entity_bound_area__nextUpdate : float&;
                          var entity_bound_area__nmeshPolyRefs : UInt64List&)
  if act.curTime < entity_bound_area__nextUpdate
    return
  entity_bound_area__nextUpdate += entity_bound_area__updateInterval

  if distance_sq(entity_bound_area__lastPos, transform[3]) < entity_bound_area__negligibleDstSq
    mark_polys(entity_bound_area__nmeshPolyRefs, entity_bound_area__num) //Just refresh the old ones if someone has removed them
  else
    unmark_polys(entity_bound_area__nmeshPolyRefs, transform, entity_bound_area__radius)
    mark_polys_around(entity_bound_area__nmeshPolyRefs, transform[3], entity_bound_area__num, entity_bound_area__projectExtents, entity_bound_area__radius, entity_bound_area__heightHalfOffset)
    entity_bound_area__lastPos = transform[3]
