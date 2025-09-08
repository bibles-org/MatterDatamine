require ecs
require level
require math.base
require gameObject
require debug.logerr_once
require game.es.generate_loot_common
require game.es.grav_zones_common


def ensure_game_objects_registry_is_inited()
  query() <| $ [es] (used_game_objects__type : string;
                     var used_game_objects__map : BoolList;
                     var used_game_objects__inited : bool&)
    if used_game_objects__inited
      return
    used_game_objects__inited = find_query() <| $ [es] (game_objects : GameObjects)
      let scene = get_scene_game_objects_by_name(game_objects, used_game_objects__type)
      if scene == null
        return false
      let nodesAliveCount = int(*scene |> tiled_scene_getNodesAliveCount())
      used_game_objects__map |> resize(nodesAliveCount)
      *scene |> tiled_scene_iterate() <| $(ni : uint)
        let mappedIdx = map_game_obj_node_idx(ni)
        if mappedIdx < 0 || mappedIdx >= nodesAliveCount
          logerr_once("Game object node indexes are in an unexpected format. {ni} maps to {mappedIdx} (node count: {nodesAliveCount} game object type: '{used_game_objects__type}')")
        else
          used_game_objects__map[mappedIdx]
      return true
    if !used_game_objects__inited
      logerr_once("Game objects with type used_game_objects__type:<{used_game_objects__type}> not exist")


[es(on_appear, on_event=EventRetriggerEntity, REQUIRE_NOT=transform)]
def common_objects_preset_generation(evt : Event;
                                     eid : EntityId;
                                     var loot_generator__finished : bool&;
                                     loot_generator__lootPreset : string;
                                     loot_generator__seed : int const?;
                                     loot_generator__gameObjType : string;
                                     loot_generator__projAttempts = 10;
                                     loot_generator__gridStep = 100.0;
                                     loot_generator__allowVolumesOverflow = true;
                                     loot_generator__createItemsInPlace = false;
                                     loot_generator__fixedTm = false;
                                     loot_generator__compensateDropTm = false)
  if loot_generator__finished
    return
  if wake_me_up_when_gravzones_are_loaded(eid)
    return

  ensure_game_objects_registry_is_inited()

  let volumes <- collect_loot_volumes_in_zone(eid, loot_generator__gameObjType)
  if empty(volumes.nodes)
    return

  loot_generator__finished = true
  let usedIdxs <- loot_preset_generator(volumes.tms,
                                        loot_generator__lootPreset,
                                        loot_generator__seed,
                                        loot_generator__projAttempts,
                                        loot_generator__gridStep,
                                        loot_generator__gameObjType,
                                        loot_generator__allowVolumesOverflow,
                                        loot_generator__createItemsInPlace,
                                        loot_generator__fixedTm,
                                        loot_generator__compensateDropTm)
  register_used_game_objects(usedIdxs, volumes.nodes, loot_generator__gameObjType)


[es(on_appear, on_event=EventRetriggerEntity)]
def boxed_objects_preset_generation(evt : Event;
                                    eid : EntityId;
                                    var loot_generator__finished : bool&;
                                    loot_generator__lootPreset : string;
                                    transform : float3x4;
                                    loot_generator__seed : int const?;
                                    loot_generator__gameObjType : string;
                                    loot_generator__projAttempts = 10;
                                    loot_generator__gridStep = 100.0;
                                    loot_generator__allowVolumesOverflow = true;
                                    loot_generator__allowSpawnInForbiddenZone = false;
                                    loot_generator__createItemsInPlace = false;
                                    loot_generator__fixedTm = false;
                                    loot_generator__compensateDropTm = false)
  if loot_generator__finished
    return
  if wake_me_up_when_gravzones_are_loaded(eid)
    return

  ensure_game_objects_registry_is_inited()

  let volumes <- collect_loot_volumes_in_box(eid, transform, loot_generator__gameObjType, loot_generator__allowSpawnInForbiddenZone)
  if empty(volumes.nodes)
    return

  loot_generator__finished = true
  let usedIdxs <- loot_preset_generator(volumes.tms,
                                        loot_generator__lootPreset,
                                        loot_generator__seed,
                                        loot_generator__projAttempts,
                                        loot_generator__gridStep,
                                        loot_generator__gameObjType,
                                        loot_generator__allowVolumesOverflow,
                                        loot_generator__createItemsInPlace,
                                        loot_generator__fixedTm,
                                        loot_generator__compensateDropTm)
  register_used_game_objects(usedIdxs, volumes.nodes, loot_generator__gameObjType)


[es(on_appear, on_event=EventRetriggerEntity)]
def custom_game_object_objects_preset_generator(evt : Event;
                                                eid aka loot_generator_eid : EntityId;
                                                transform aka generator_transform : float3x4;
                                                var loot_generator__finished : bool&;
                                                loot_generator__lootPreset : string;
                                                loot_generator__seed : int const?;
                                                loot_generator__customGameObjName : string;
                                                loot_generator__projAttempts = 10;
                                                loot_generator__gridStep = 100.0;
                                                loot_generator__allowVolumesOverflow = true;
                                                loot_generator__createItemsInPlace = false;
                                                loot_generator__fixedTm = false;
                                                loot_generator__compensateDropTm = false)
  if loot_generator__finished
    return
  if wake_me_up_when_gravzones_are_loaded(eid)
    return

  var eids : array<EntityId>
  var volumes : array<float3x4>
  query() <| $ [es] (eid : EntityId; custom_game_object__name : string; transform : float3x4; custom_game_object__occuped : bool)
    if !custom_game_object__occuped && custom_game_object__name == loot_generator__customGameObjName
      if is_inside_tm(transform[3], generator_transform) && !is_loot_point_in_forbidden_zone(loot_generator_eid, transform[3])
        volumes |> push(transform)
        eids |> push(eid)
  if empty(volumes)
    return

  loot_generator__finished = true
  let usedIdxs <- loot_preset_generator(volumes,
                                        loot_generator__lootPreset,
                                        loot_generator__seed,
                                        loot_generator__projAttempts,
                                        loot_generator__gridStep,
                                        loot_generator__customGameObjName,
                                        loot_generator__allowVolumesOverflow,
                                        loot_generator__createItemsInPlace,
                                        loot_generator__fixedTm,
                                        loot_generator__compensateDropTm)
  for usedIdx in usedIdxs
    query(eids[usedIdx]) <| $ [es] (var custom_game_object__occuped : bool&)
      custom_game_object__occuped = true