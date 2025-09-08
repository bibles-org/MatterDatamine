module level_common shared
require math.maybe_pos public
require math.base
require math.random
require ecs
require DngNet
require DagorMath
require DagorRandom
require DagorSystem
require DagorDataBlock
require DagorFiles
require gameObject
require level
require pathfinder
require active_matter.game.utils.poly_area
require game.es.random_common
require game.es.custom_region_common


def level_environment_print_log(text)
  print("[Level Environment] {text}")


def is_pos_indoor(pos : float3; search_threshold = 0.5f) : bool
  var indoor = false
  find_query() <| $ [es] (game_objects : GameObjects)
    indoor = is_pos_indoor(game_objects, pos, search_threshold)
    return true
  return indoor


def is_pos_indoor(game_objects : GameObjects; pos : float3; search_threshold = 0.5f) : bool
  let box = BBox3(pos, search_threshold)
  var indoor = false
  game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    indoor ||= IDENT_BBOX & (inverse(tm) * pos)
  return indoor


def get_nearest_indoor_pos(pos : float3; radius : float) : MaybePos
  var result = MaybePos()
  find_query() <| $ [es] (game_objects : GameObjects)
    result = get_nearest_indoor_pos(game_objects, pos, radius)
    return true
  return result


def get_nearest_indoor_pos(game_objects : GameObjects; pos : float3; radius : float) : MaybePos
  let box = BBox3(pos, radius * 2f)
  var result = MaybePos()
  var maxDistanceSq = square(radius)
  game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    let distSq = distance_sq(pos, tm[3])
    if distSq < maxDistanceSq
      maxDistanceSq = distSq
      result = MaybePos(tm[3])
  return result


def get_nearest_indoor_tm(pos : float3; radius : float) : MaybeTm
  var result = MaybeTm()
  find_query() <| $ [es] (game_objects : GameObjects)
    result = get_nearest_indoor_tm(game_objects, pos, radius)
    return true
  return result


def get_nearest_indoor_tm(game_objects : GameObjects; pos : float3; radius : float) : MaybeTm
  let box = BBox3(pos, radius * 2f)
  var result = MaybeTm()
  var maxDistanceSq = square(radius)
  game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    let distSq = distance_sq(pos, tm[3])
    if distSq < maxDistanceSq
      maxDistanceSq = distSq
      result = MaybeTm(clone_to_move(tm))
  return result


def find_random_game_object(game_objects : GameObjects; obj_type : string; box : BBox3; is_valid : block<(pos : float3x4#) : variant<pos : auto(T); invalid : bool>>) : variant<pos : T; invalid : bool>
  var positions : array<T>
  game_objects |> get_scene_game_objects_by_name(obj_type) |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    let res = invoke(is_valid, tm)
    if res is pos
      positions |> push(res as pos)
  return length(positions) == 0 ? variant<pos : T; invalid : bool>(invalid = true) : variant<pos : T; invalid : bool>(pos = positions[grnd() % length(positions)])


def find_random_game_object_in_tm(game_objects : GameObjects; obj_type : string; transform : float3x4;
                                  is_valid : block<(pos : float3x4#) : variant<pos : auto(T); invalid : bool>>) : variant<pos : T; invalid : bool> const
  let zoneBox = transform * IDENT_BBOX
  let invTm = inverse(transform)
  let res = find_random_game_object(game_objects, obj_type, zoneBox) <| $(pos : float3x4#)
    if IDENT_BBOX & (invTm * pos[3])
      return invoke(is_valid, pos)
    return variant<pos : T; invalid : bool>(invalid = true)
  return res


def is_pos_within_region(pos : float3; region_name : string)
  var result = false
  in_region_with_name(region_name) <| $(points, indicies, data)
    result = is_point_inside_region(pos, points, indicies, data.bbox)
  return result


def private check_pos_accessibility(var bases : array<tuple<pos : float3; dst : float>>; point : float3; resp_base_radius : float; max_checks : int = 3)
  let distance_limit = square(resp_base_radius)
  query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    let dst = distance_sq(transform[3], point)
    if distance_sq(transform[3], point) < distance_limit
      emplace(bases,  (transform[3], dst))
  query() <| $ [es(REQUIRE=extraction_point)] (transform : float3x4)
    let dst = distance_sq(transform[3], point)
    if distance_sq(transform[3], point) < distance_limit
      emplace(bases,  (transform[3], dst))
  sort(bases) <| $(a; b)
    return a.dst < b.dst
  let limit = min(max_checks, length(bases))
  let extents = float3(0.5, FLT_MAX, 0.5)
  for i in range(limit)
    let resPath = find_path(point, bases[i].pos, extents, 1.0, 1.0)
    if resPath == FindPathResult.FPR_FULL
      return true
  return false


def check_pos_accessibility(point : float3; resp_base_radius : float; max_checks : int = 3)
  var bases : array<tuple<pos : float3; dst : float>>
  return bases |> check_pos_accessibility(point, resp_base_radius, max_checks)


def check_pos_accessibility(point : float3; resp_base_radius : float; max_checks : int; known_safe_pos : float3)
  var bases : array<tuple<pos : float3; dst : float>>
  bases |> emplace((known_safe_pos, distance_sq(known_safe_pos, point)))
  return bases |> check_pos_accessibility(point, resp_base_radius, max_checks)


def check_pos_accessibility(point : float3; resp_base_radius : float; max_checks : int; known_safe_pos : Point3List?)
  var bases : array<tuple<pos : float3; dst : float>>
  if known_safe_pos != null
    for pos in *known_safe_pos
      bases |> emplace((pos, distance_sq(pos, point)))
  return bases |> check_pos_accessibility(point, resp_base_radius, max_checks)

def is_polygon_accessible(poly : dtPolyRef)
  var area : uint8
  get_poly_area(poly, area)
  return area == uint8(int(AMPolyArea.POLYAREA_WALKABLE)) || area == uint8(int(AMPolyArea.POLYAREA_DANGER))


def generate_level_evnironment_index(cur_time_seconds : int;
                                     interval_seconds : int;
                                     indices_count : int;
                                     chain_segments : int;
                                     seed : int = 0)
  if interval_seconds <= 0
    return -1
  let timeIndex = abs(seed) % int(0xFFFF) + (cur_time_seconds / interval_seconds)
  return generate_non_duplicate_sequence_index(timeIndex, indices_count, chain_segments, seed)


def parse_level_weather_and_time_from_scene(scene_path : string;
                                            cb : block<(level__weatherChoice : Object;
                                              level__timeVec : Array;
                                              level_synced_environment__timeOfDayChangeInterval : int;
                                              level_synced_environment__timeOfDayChainSegments : int;
                                              level_synced_environment__timeOfDaySeed : int;
                                              level_synced_environment__weatherChangeInterval : int;
                                              level_synced_environment__weatherChainSegments : int;
                                              level_synced_environment__weatherSeed : int) : void>)
  var result = false
  var fileStat : DagorStat
  if df_stat(scene_path, fileStat) < 0
    return result

  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, scene_path)
      logerr("Failed to load scene data block: '{scene_path}'!")
      return
    for blkIndex in range(blk.blockCount)
      blk |> datablock_get_block(uint(blkIndex)) <| $(node)
        if node.getBlockName == "entity"
          let entityTemplateName = datablock_getStr(node, "_template", "")
          if entityTemplateName != ""
            let entityTemplate = buildTemplateByName(entityTemplateName)
            if entityTemplate != null
              let levelWeatherChoiceComp = getTemplateComponent(*entityTemplate, "level__weatherChoice")
              if levelWeatherChoiceComp == null || levelWeatherChoiceComp.isNull
                return
              var levelWeatherChoice = get_ecs_object(levelWeatherChoiceComp)
              if levelWeatherChoice == null
                return

              let levelTimeVecComp = getTemplateComponent(*entityTemplate, "level__timeVec")
              if levelTimeVecComp == null || levelTimeVecComp.isNull
                return
              var levelTimeVec = get_ecs_array(levelTimeVecComp)
              if levelTimeVecComp == null
                return

              let level_synced_environment__timeOfDayChangeIntervalComp = getTemplateComponent(*entityTemplate, "level_synced_environment__timeOfDayChangeInterval")
              let level_synced_environment__timeOfDayChainSegmentsComp = getTemplateComponent(*entityTemplate, "level_synced_environment__timeOfDayChainSegments")
              let level_synced_environment__timeOfDaySeedComp = getTemplateComponent(*entityTemplate, "level_synced_environment__timeOfDaySeed")

              let level_synced_environment__weatherChangeIntervalComp = getTemplateComponent(*entityTemplate, "level_synced_environment__weatherChangeInterval")
              let level_synced_environment__weatherChainSegmentsComp = getTemplateComponent(*entityTemplate, "level_synced_environment__weatherChainSegments")
              let level_synced_environment__weatherSeedComp = getTemplateComponent(*entityTemplate, "level_synced_environment__weatherSeed")

              if (level_synced_environment__timeOfDayChangeIntervalComp == null || level_synced_environment__timeOfDayChangeIntervalComp.isNull ||
                 level_synced_environment__timeOfDayChainSegmentsComp == null || level_synced_environment__timeOfDayChainSegmentsComp.isNull ||
                 level_synced_environment__timeOfDaySeedComp == null || level_synced_environment__timeOfDaySeedComp.isNull ||
                 level_synced_environment__weatherChangeIntervalComp == null || level_synced_environment__weatherChangeIntervalComp.isNull ||
                 level_synced_environment__weatherChainSegmentsComp == null || level_synced_environment__weatherChainSegmentsComp.isNull ||
                 level_synced_environment__weatherSeedComp == null || level_synced_environment__weatherSeedComp.isNull)
                return

              using() <| $(var levelWeatherChoiceOverride : Object)
                let levelWeatherChoiceOverrided = node |> datablock_get_block("level__weatherChoice:object") <| $(levelWeatherChoiceObject)
                  for paramIdx in range(levelWeatherChoiceObject.paramCount)
                    let paramName = levelWeatherChoiceObject |> datablock_getParamName(uint(paramIdx))
                    let paramValue = levelWeatherChoiceObject |> datablock_getReal(paramIdx)
                    levelWeatherChoiceOverride |> set(paramName, paramValue)

                using() <| $(var levelTimeVecOverride : Array)
                  let levelTimeVecOverrided = node |> datablock_get_block("level__timeVec:array") <| $(levelWeatherChoiceArray)
                    for paramIdx in range(levelWeatherChoiceArray.paramCount)
                      let paramValue = levelWeatherChoiceArray |> datablock_getReal(paramIdx)
                      levelTimeVecOverride |> push(paramValue)

                  cb |> invoke(
                    levelWeatherChoiceOverrided ? levelWeatherChoiceOverride : *levelWeatherChoice,
                    levelTimeVecOverrided ? levelTimeVecOverride : *levelTimeVec,
                    node |> datablock_getInt("level_synced_environment__timeOfDayChangeInterval", get_int(level_synced_environment__timeOfDayChangeIntervalComp) ?? 0),
                    node |> datablock_getInt("level_synced_environment__timeOfDayChainSegments", get_int(level_synced_environment__timeOfDayChainSegmentsComp) ?? 0),
                    node |> datablock_getInt("level_synced_environment__timeOfDaySeed", get_int(level_synced_environment__timeOfDaySeedComp) ?? 0),
                    node |> datablock_getInt("level_synced_environment__weatherChangeInterval", get_int(level_synced_environment__weatherChangeIntervalComp) ?? 0),
                    node |> datablock_getInt("level_synced_environment__weatherChainSegments", get_int(level_synced_environment__weatherChainSegmentsComp) ?? 0),
                    node |> datablock_getInt("level_synced_environment__weatherSeed", get_int(level_synced_environment__weatherSeedComp) ?? 0))
              result = true

      if result
        break

  return result


def is_raid_mode() : bool
  return find_query() <| $ [es(REQUIRE=raid_mode)] () => true

def is_nexus_mode() : bool
  return find_query() <| $ [es(REQUIRE=nexus_mode)] () => true

def is_player_session() : bool
  return find_query() <| $ [es(REQUIRE=player_session)] () => true

def is_player_base() : bool
  return find_query() <| $ [es(REQUIRE=player_base)] () => true


def get_current_time_of_day()
  var timeOfDay = 12.0
  query() <| $ [es] (level__timeOfDay : float&)
    timeOfDay = level__timeOfDay

  return timeOfDay