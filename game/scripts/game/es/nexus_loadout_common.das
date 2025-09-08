module nexus_loadout_common shared

require ecs
require ecs.safe
require ecs.common
require math.random


def get_generator_indexes(var seed : int; generators_count : int; loadouts_count : int)
  var generatorIndexes : array<int>
  for i in range(0, max(generators_count, loadouts_count))
    generatorIndexes |> push(i % generators_count)
  shuffle_seeded(generatorIndexes, seed, loadouts_count)
  generatorIndexes.resize(loadouts_count)
  return <- generatorIndexes


def generate_loadout_items(loadout : Object; var items : Array; var itemIdCounter : int64&)
  let loadoutItemsPtr = get_ecs_array(loadout, "items")
  if loadoutItemsPtr == null
    return

  items := *loadoutItemsPtr

  var idRemapping : table<string; string>

  for item in items
    var itemPtr = getRW_ecs_object(item)
    if itemPtr == null
      continue

    let itemId = *itemPtr.itemId ?? "-1"
    let newItemId = "{itemIdCounter}"
    if key_exists(idRemapping, itemId)
      error("[generate_loadout_items] duplicate key {itemId}!")
    idRemapping.insert(itemId, newItemId)
    itemIdCounter += 1l
    set(*itemPtr, "itemId", newItemId)

  idRemapping.insert("0", "0")

  for item in items
    var itemPtr = getRW_ecs_object(item)
    if itemPtr == null
      continue

    let parentItemId = *itemPtr.parentItemId ?? "0"
    get(idRemapping, parentItemId) <| $(newParentId)
      set(*itemPtr, "parentItemId", newParentId)
