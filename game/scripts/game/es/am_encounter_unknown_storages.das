require ecs
require ecs.safe
require DagorSystem
require DagorMath
require DagorRandom
require Grid
require gameObject
require inventory
require math
require math.base
require game.events.events_game
require game.es.transform_common
require game.es.inventory_drop_common
require game.es.grav_zones_common


def push_game_object_tm_if_valid(var tms : array<float3x4>;
                                 tm;
                                 zone_pos : float3;
                                 zone_itm : float3x4;
                                 zone_radius_sq : float;
                                 pred_cb : block<(var tm : float3x4) : bool>)
  if is_point_in_box_or_sphere_zone(tm[3], zone_pos, zone_itm, zone_radius_sq)
    var resultTm : float3x4 = tm
    if pred_cb |> invoke(resultTm)
      tms |> push(resultTm)


def gather_game_object_transforms_in_zones(game_object_type : string;
                                           zone_eids : array<EntityId>;
                                           pred_cb : block<(var tm : float3x4) : bool>)
  var tms : array<float3x4>

  let gameObjectTypeHash = ecs_hash(game_object_type)

  find_query() <| $ [es] (game_objects : GameObjects)
    for zoneEid in zone_eids
      query(zoneEid) <| $ [es] (transform aka zone_transform : float3x4;
                                sphere_zone__radius : float const?)
        let zoneRadiusSq = sphere_zone__radius != null ? square(*sphere_zone__radius) : 0.0
        let zoneRadius = (sphere_zone__radius != null ? *sphere_zone__radius
                                                      : 0.5 * max(length(float3(transform[0][0], transform[0][1], transform[0][2])),
                                                                  length(float3(transform[1][0], transform[1][1], transform[1][2])),
                                                                  length(float3(transform[2][0], transform[2][1], transform[2][2]))))
        let searchBox = BBox3(zone_transform[3] - float3(zoneRadius), zone_transform[3] + float3(zoneRadius))
        let zoneTransformInv = sphere_zone__radius == null ? inverse(zone_transform) : IDENT_TM

        game_objects |> get_scene_game_objects_by_name(game_object_type) |> for_scene_game_objects(searchBox) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
          tms |> push_game_object_tm_if_valid(tm, zone_transform[3], zoneTransformInv, zoneRadiusSq, pred_cb)
        query() <| $ [es] (transform aka additional_object_point_transform : float3x4;
                           encounter_additional_game_object_point__typeHash : int)
          if int(gameObjectTypeHash) == encounter_additional_game_object_point__typeHash
            tms |> push_game_object_tm_if_valid(additional_object_point_transform, zone_transform[3], zoneTransformInv, zoneRadiusSq, pred_cb)
    return true

  return <- tms


def gather_game_object_transforms_in_zones(game_object_type : string;
                                           zone_eids : array<EntityId>)
  return <- gather_game_object_transforms_in_zones(game_object_type, zone_eids) <| $ [unused_argument(tm)] (var tm : float3x4)
    return true


def process_door_for_encounter_unknown_storage(door_pos : float3;
                                               encounter_pos : float3;
                                               encounter_tm_inverse : float3x4;
                                               encounter_radius_sq : float;
                                               var locked__isLocked : bool&)
  if !is_point_in_box_or_sphere_zone(door_pos, encounter_pos, encounter_tm_inverse, encounter_radius_sq)
    return

  locked__isLocked = true


[es(tag=server, on_event=EventLevelLoaded, REQUIRE=encounter_unknown_storage)]
def encounter_unknown_storage_init(evt : Event;
                                   transform aka encounter_transform : float3x4;
                                   sphere_zone__radius : float const?)
  let zoneRadiusSq = sphere_zone__radius != null ? square(*sphere_zone__radius) : 0.0
  let itm = sphere_zone__radius == null ? inverse(encounter_transform) : IDENT_TM

  query() <| $ [es] (transform aka door_transform : float3x4;
                     isDoor : bool;
                     var locked__isLocked : bool&)
    if !isDoor
      return
    process_door_for_encounter_unknown_storage(door_transform[3], encounter_transform[3], itm,
                                               zoneRadiusSq, locked__isLocked)


[es(tag=server, on_appear)]
def encounter_unknown_storage_door_detect(evt : Event;
                                          transform aka door_transform : float3x4;
                                          isDoor : bool;
                                          var locked__isLocked : bool&)
  if !isDoor
    return
  query() <| $ [es(REQUIRE=encounter_unknown_storage)] (transform aka encounter_transform : float3x4;
                                                        sphere_zone__radius : float const?
                                                        )
    let zoneRadiusSq = sphere_zone__radius != null ? square(*sphere_zone__radius) : 0.0
    let itm = sphere_zone__radius == null ? inverse(encounter_transform) : IDENT_TM
    process_door_for_encounter_unknown_storage(door_transform[3], encounter_transform[3], itm,
                                               zoneRadiusSq, locked__isLocked)


def shuffle_indices(var indices : array<int>;
                    from : int;
                    to : int)
  for i in range(from, to)
    swap(indices[i], indices[from + (grnd() % (to - from))])


[es(tag=server, on_event=(EventGameObjectsCreated, EventRetriggerEntity), after=(moving_zone_init), REQUIRE=encounter_unknown_storages_controller)]
def encounter_unknown_storages_controller_init(evt : Event; eid : EntityId;
                                               encounter_unknown_storages_controller__storagesSetupByGroup : Object)
  if wake_me_up_when_gravzones_are_loaded(eid)
    return
  assume storagesSetupByGroup = encounter_unknown_storages_controller__storagesSetupByGroup

  var zoneRadiusSq = FLT_MAX
  var zoneCenter = float3(0, 0, 0)
  find_query() <| $ [es(REQUIRE=moving_zone__startEndTime)] (sphere_zone__radius : float; transform : float3x4)
    zoneRadiusSq = square(sphere_zone__radius)
    zoneCenter = transform[3]
    return true

  var activeStoragesByGroup : table<string; table<string; array<EntityId>>>
  query() <| $ [es(REQUIRE=encounter_unknown_storage)] (eid : EntityId;
                                                        transform : float3x4;
                                                        encounter_zone__name : string;
                                                        encounter_unknown_storage__group : string)
    if distance_sq(transform[3], zoneCenter) > zoneRadiusSq
      return
    activeStoragesByGroup[encounter_unknown_storage__group][encounter_zone__name] |> push(eid)

  for groupName, groupStorages in keys(activeStoragesByGroup), values(activeStoragesByGroup)
    var findGroupSetup = storagesSetupByGroup[groupName] ?as Object
    if findGroupSetup == null
      findGroupSetup = storagesSetupByGroup["default"] ?as Object
      if findGroupSetup == null
        logerr("It's impossible to get setup for the encounter unknown storages group {groupName}
               - there are no direct setup and no default fallback group!")
        continue
    let groupSetup = findGroupSetup
    let presets = groupSetup?.presets ?as Array
    if presets == null || length(*presets) == 0
      logerr("There are no presets for the encounter unknown storages group {groupName}!")
      continue
    let groupStoragesCount = length(groupStorages)

    var presetIndices : array<int>
    while length(presetIndices) < groupStoragesCount
      let startPresetIndicesLength = length(presetIndices)
      for presetIndex in iter_range(*presets)
        for _ in range((*presets)[presetIndex] as Object?.count ?? 1)
          presetIndices |> push(presetIndex)
      shuffle_indices(presetIndices, startPresetIndicesLength, length(presetIndices))

    for i, storageKey, storageEids in range(groupStoragesCount), keys(groupStorages), values(groupStorages)
      let storagePreset = (*presets)[presetIndices[i]] as Object
      let presetName = storagePreset?.name ?? "nameless"
      print("Unknown storage '{storageKey}' have preset '{presetName}'")

      let lootGeneratorsSetup = storagePreset?.loot_generators ?as Object
      if lootGeneratorsSetup != null
        encounter_unknown_storages_generate_loot(storageEids, *lootGeneratorsSetup)

      let itemsGeneratorSetup = storagePreset?.items_generator ?as Object
      if itemsGeneratorSetup != null
        encounter_unknown_storages_generate_items(storageEids, *itemsGeneratorSetup)

      let entitiesGeneratorSetup = storagePreset?.entities_generator ?as Object
      if entitiesGeneratorSetup != null
        encounter_unknown_storages_generate_entities(storageEids, *entitiesGeneratorSetup)


def encounter_unknown_storages_generate_items(storageEids : array<EntityId>;
                                              items_generator_setup : Object)
  let generatableObjects = items_generator_setup.generatableObjects ?as Array
  let minDistanceBetweenItems = items_generator_setup.minDistanceBetweenItems ?? 0.2
  if generatableObjects == null
    return

  var generatePositions : table<string; array<float3x4>>
  for item in *generatableObjects
    let generatableObject = item as Object
    if generatableObject == null
      continue

    let gameObjectType = generatableObject |> get_string("type", "loot_box")
    let countRange = generatableObject |> get_Point2("countRange") ?? float2()
    var itemsCount = int(rnd_float(countRange.x, countRange.y) + 0.5)
    let itemsToGenerate = generatableObject |> get_ecs_array("items")
    if itemsToGenerate == null || length(*itemsToGenerate) == 0
      continue

    if !generatePositions |> key_exists(gameObjectType)
      generatePositions[gameObjectType] <- gather_game_object_transforms_in_zones(gameObjectType, storageEids) <| $(var tm : float3x4)
        drop_item_on_ground(tm)
        return !is_entity_found_in_grid(ecs_hash("loot"), BSphere3(tm[3], minDistanceBetweenItems), GridEntCheck.POS)

    assume positions = generatePositions[gameObjectType]
    itemsCount = min(itemsCount, positions |> length())
    for _i in range(itemsCount)
      let itemIndex = grnd() % length(*itemsToGenerate)
      let itemObject = get_ecs_object((*itemsToGenerate)[itemIndex])
      if itemObject != null
        let itemName = itemObject |> get_string("template", "")
        var modTm = IDENT_TM
        let positionIndex = grnd() % length(positions)
        modTm[3] = positions[positionIndex][3]
        positions |> erase(positionIndex)
        drop_item_on_ground(modTm)
        let eid = createEntity("{itemName}+item_in_world") <| $(var init : ComponentsInitializer)
          init |> set("transform", modTm)
        sendEvent(eid, EventOnItemGenerated())
        if has(*itemObject, "subTemplate") && has(*itemObject, "quantitySubTemplate")
          let subTemplate = get_string(itemObject, "subTemplate", "")
          let quantitySubTemplate = get_float(itemObject, "quantitySubTemplate") ?? 0.f
          for _j in range(quantitySubTemplate)
            let subEid = createEntity("{subTemplate}+item_in_world") <| $(var init : ComponentsInitializer)
              init |> set("transform", modTm)
            sendEvent(subEid, EventOnItemGenerated())


def encounter_unknown_storages_generate_loot(storageEids : array<EntityId>;
                                             loot_generators_setup : Object)
  let lootGeneratorTemplates = loot_generators_setup.loot_generators ?as Array
  if lootGeneratorTemplates == null
    logerr("loot_generators array is missing!")
    return

  for storageEid in storageEids
    query(storageEid) <| $ [es] (transform : float3x4)
      for lootGeneratorTemplate in *lootGeneratorTemplates
        createEntity(lootGeneratorTemplate ?? "") <| $(init)
          init |> set("transform", transform)


def encounter_unknown_storages_generate_entities(storageEids : array<EntityId>;
                                                 entities_generator_setup : Object)
  let generatableObjects = entities_generator_setup.generatableObjects ?as Array
  if generatableObjects == null
    return

  var generatePositions : table<string; array<float3x4>>
  for item in *generatableObjects
    let generatableObject = item as Object
    if generatableObject == null
      continue

    let gameObjectType = generatableObject |> get_string("type", "loot_box")
    let countRange = generatableObject |> get_Point2("countRange") ?? float2(1.0)
    var entitiesCount = int(rnd_float(countRange.x, countRange.y) + 0.5)
    let entitiesToGenerate = generatableObject |> get_ecs_array("entities")
    if entitiesToGenerate == null || length(*entitiesToGenerate) == 0
      continue

    if !generatePositions |> key_exists(gameObjectType)
      generatePositions[gameObjectType] <- gather_game_object_transforms_in_zones(gameObjectType, storageEids)

    assume positions = generatePositions[gameObjectType]
    entitiesCount = min(entitiesCount, positions |> length())

    for _i in range(entitiesCount)
      let itemIndex = grnd() % length(*entitiesToGenerate)
      let itemObject = get_ecs_object((*entitiesToGenerate)[itemIndex])
      if itemObject != null
        let templateName = itemObject |> get_string("template", "")
        var modTm = IDENT_TM
        let positionIndex = grnd() % length(positions)
        modTm[3] = positions[positionIndex][3]
        positions |> erase(positionIndex)
        let eid = createEntity("{templateName}") <| $(var init : ComponentsInitializer)
          init |> set("transform", modTm)
        sendEvent(eid, EventOnItemGenerated())
