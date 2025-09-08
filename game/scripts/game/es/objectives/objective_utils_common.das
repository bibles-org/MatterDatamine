module objective_utils_common shared
require ecs
require ecs.common
require ecs.safe
require math.base
require math.random
require rapidjson
require DagorSystem
require DagorRandom
require daslib/strings_boost
require game.es.inventory_item_common
require game.es.objectives_enums_common
require game.es.objectives.objective_common
require strings
require pathfinder
require game.events.events_active_matter
require game.es.transform_common
require game.es.level_common
require game.es.ai.agent_position_mapping_common


def gather_lootable_ri_for_objective(objective_eid : EntityId;
                                     objective__params : Array;
                                     objective__containerTypes : StringList;
                                     min_volume : float = -1.0;
                                     zone_tag_name : string = "zoneTag")
  var validContainers : array<EntityId>
  var zones : array<tuple<pos : float3; radiusSq : float>> = collect_zones_for_objective(objective_eid, objective__params, zone_tag_name)
  query() <| $ [es(REQUIRE_NOT=secret_lootable_rendinst)] (eid, lootable_ri__objectiveEid : EntityId;
                                                           human_inventory__maxVolume : float;
                                                           itemContainer__type : string;
                                                           transform : float3x4)
    if lootable_ri__objectiveEid == INVALID_ENTITY_ID
      if min_volume <= .0 || human_inventory__maxVolume >= min_volume
        if find_index(objective__containerTypes, itemContainer__type) != -1
          for z in zones
            if distance_sq(transform[3], z.pos) < z.radiusSq
              validContainers |> push(eid)
              break
  return <- validContainers


def private collect_zones_for_objective(objective_eid : EntityId;
                                        objective__params : Array;
                                        zone_tag_name : string)
  var zoneTags : array<string>
  collect_objective_param_values_by_name_strict(objective_eid, objective__params, zone_tag_name, zoneTags)
  var zones : array<tuple<pos : float3; radiusSq : float>>
  query() <| $ [es] (objective_static_target__tag : string; transform : float3x4; quest_target_geometry_sphere__radius : float)
    if find_index(zoneTags, objective_static_target__tag) != -1
      zones |> push(tuple(transform[3], square(quest_target_geometry_sphere__radius)))
  if length(zones) == 0
    logerr("No zones for objective {getEntityTemplateName(objective_eid)}. zone_tag_name '{zone_tag_name}' zoneTags: {zoneTags}")
  return <- zones

def get_single_objective_item_from_params(objective__params : Array; objective__itemTemplateNameInParams : string; objective_eid, player_eid : EntityId)
  var objectiveItemNames : array<string>
  collect_objective_param_values_by_name(objective__params, objective__itemTemplateNameInParams, objectiveItemNames)
  if length(objectiveItemNames) > 1
    logerr("Too many items in objective param (only a single one expected). param: '{objective__itemTemplateNameInParams}' {getEntityTemplateName(objective_eid)} {objectiveItemNames} player_eid: {player_eid}")
    return ""
  if length(objectiveItemNames) == 0
    logerr("No items passed in objective params. param: '{objective__itemTemplateNameInParams}' {getEntityTemplateName(objective_eid)} objective__params:{objective__params} player_eid: {player_eid}")
    return ""
  return objectiveItemNames[0]


def wake_me_up_when_objective_prerequisites_are_loaded(eid : EntityId)
  var prereqLoaded = false
  find_query() <| $ [es] (var level__retriggerEids : EidList;
                          level__gameObjectsEntitiesCreated : bool;
                          level__navmeshIslandsMarked : bool;
                          level__movingZoneInited : bool;
                          level__levelLoaded : bool;
                          level__navmeshIslandsMarkerAppeared : bool)
    prereqLoaded = (level__gameObjectsEntitiesCreated &&
                    level__levelLoaded &&
                    level__movingZoneInited &&
                    level__navmeshIslandsMarked == level__navmeshIslandsMarkerAppeared)
    if !prereqLoaded
      level__retriggerEids |> push(eid)
    return true
  return !prereqLoaded


def is_point_in_objective_target_geometry(point : float3; target_eid : EntityId)
  var result = false
  query(target_eid) <| $ [es] (transform : float3x4;
                               quest_target_geometry_sphere__radius = 0f)
    if quest_target_geometry_sphere__radius > 0f
      result = is_point_in_sphere_zone(point, transform[3], square(quest_target_geometry_sphere__radius))
    else
      result = is_point_in_box_zone(point, transform)
  return result


def create_backup_container_for_objective(templ : string;
                                          eid : EntityId;
                                          objective__params : Array;
                                          zone_tag_name : string = "zoneTag")
  let zones : array<tuple<pos : float3; radiusSq : float>> = collect_zones_for_objective(eid, objective__params, zone_tag_name)
  if length(zones) == 0
    return INVALID_ENTITY_ID
  var attempts = 10
  while attempts-- > 0
    let zone = zones[grnd() % length(zones)]
    let horOffset = (rnd_point_on_disk(sqrt(zone.radiusSq)))
    let pos = zone.pos + float3(horOffset.x, .0, horOffset.y)
    let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
    var poly : dtPolyRef
    var navPos = navmesh_map_position_in_zone(pos, mappingZone)
    if !project_to_nearest_navmesh_point(navPos, float3(10, 25, 10), poly)
      continue
    navPos = navmesh_unmap_position_in_zone(navPos, mappingZone)
    if !is_polygon_accessible(poly)
      continue
    return createEntity(templ) <| $(init)
      init |> set("lootable_ri__objectiveEid", eid)
      var tm = IDENT_TM
      tm[3] = navPos
      init |> set("transform", tm)
  return INVALID_ENTITY_ID