module equipment_generator_common shared
require ecs
require strings
require ecs.safe
require DagorRandom
require DagorSystem
require game.es.inventory_weapon_common


def private is_corrupted(chance)
  return chance >= gfrnd()


def private get_end_value_with_weight(items_list : Object; var seed : int&)
  var totalWeight = 0
  for item in items_list
    totalWeight += get_int(item.value) ?? 0
  let rndVal = _rnd_int(seed, 0, totalWeight)
  var acc = 0
  for item in items_list
    acc += get_int(item.value) ?? 0
    if rndVal <= acc
      return item.key
  return "EMPTY"


def private get_item_id(var counter : int&) : int
  return counter++


def private generate_equipment(data : Object;
                               corrupt_chance : float;
                               var seed : int&;
                               var result : Array;
                               var item_id_counter : int&;
                               var available_volume : table<string; float>) : int
  var backpackId = -1
  using() <| $(var suit_select_object : Object)
    for suit in data
      let suitObject = get_ecs_object(suit.value)
      if suitObject == null
        continue
      let suitChance = *suitObject |> get_int("chance")
      if suitChance != null
        suit_select_object |> set(suit.key, *suitChance)
    let suitName = get_end_value_with_weight(suit_select_object, seed)

    let suitId = get_item_id(item_id_counter)
    using <| $(var suitItem : Object)
      suitItem |> set("itemId", "{suitId}")
      suitItem |> set("parentItemId", "0")
      suitItem |> set("slotName", "equipment_chronogene_primary_1")
      suitItem |> set("templateName", suitName)
      suitItem |> set("isCorrupted", false)
      result |> push(suitItem)

    let suitObject = data |> get_ecs_object(suitName)
    if suitObject == null // impossible, because we select it before
      return
    for suitEquipment in *suitObject
      if suitEquipment.key == "chance"
        continue
      let suitEquipmentObject = suitEquipment.value |> get_ecs_object()
      if suitEquipmentObject == null
        continue
      let suitEquipmentName = get_end_value_with_weight(*suitEquipmentObject, seed)
      if suitEquipmentName != "EMPTY"
        let equipmentId = get_item_id(item_id_counter)
        var charges = 1
        var backpackVolume = 0.0
        var pouchExtensionVolume = 0.0
        let templ = getTemplateByName(suitEquipmentName)
        if templ != null
          let item__hp = int(getTemplateComponent(*templ, "item__hp") ?? -1.0)
          let item_holder__maxItemCount = getTemplateComponent(*templ, "item_holder__maxItemCount") ?? -1
          let item__maxAmount = getTemplateComponent(*templ, "item__maxAmount") ?? -1
          if item__hp >= 0
            charges = item__hp
          elif item_holder__maxItemCount >= 0
            charges = item_holder__maxItemCount
          elif item__maxAmount >= 0
            charges = item__maxAmount
          backpackVolume = getTemplateComponent(*templ, "human_inventory__maxVolume") ?? 0.0
          pouchExtensionVolume = getTemplateComponent(*templ, "item__inventoryExtension") ?? 0.0

        if suitEquipment.key == "equipment_backpack"
          backpackId = equipmentId
          available_volume.insert("BACKPACK", backpackVolume)
        elif suitEquipment.key == "equipment_pouch"
          available_volume.insert("POUCH", (available_volume?["POUCH"] ?? 0.f) + pouchExtensionVolume)

        using <| $(var suitAddonItem : Object)
          suitAddonItem |> set("itemId", "{equipmentId}")
          suitAddonItem |> set("parentItemId", "{suitId}")
          suitAddonItem |> set("slotName", "{suitEquipment.key}")
          suitAddonItem |> set("templateName", suitEquipmentName)
          suitAddonItem |> set("charges", charges)
          suitAddonItem |> set("isCorrupted", is_corrupted(corrupt_chance))
          result |> push(suitAddonItem)
  return backpackId


def private get_inventory_for_item(itemTemplate : string;
                                   isBoxedItem : bool;
                                   corrupted : bool;
                                   var parentId : int&;
                                   var charges : int&;
                                   var volume : float&;
                                   var slotName : string&;
                                   var result : Array;
                                   var item_id_counter : int&;
                                   backpack_id : int;
                                   var available_volume : table<string; float>)
  // check volume
  if slotName |> starts_with("POUCH") && available_volume.get_value("POUCH") >= volume
    slotName = "inventory"
    parentId = 0
    available_volume.insert("POUCH", available_volume.get_value("POUCH") - volume)
  elif isBoxedItem && slotName |> starts_with("POUCH")
    // split between pouch and backpack
    let pouch_charges = max_boxed_item_count_in_volume(itemTemplate, available_volume.get_value("POUCH"))
    if pouch_charges > 0
      using <| $(var item : Object)
        item |> set("itemId", "{get_item_id(item_id_counter)}")
        item |> set("parentItemId", "0")
        item |> set("slotName", "inventory")
        item |> set("templateName", itemTemplate)
        item |> set("charges", pouch_charges)
        item |> set("isCorrupted", corrupted)
        result |> push(item)
      charges = charges - pouch_charges
      volume = calculate_boxed_item_volume(itemTemplate, pouch_charges)
      available_volume.insert("POUCH", available_volume.get_value("POUCH") - volume)
    // rest put in backpack, if exist
    charges = min(charges, max_boxed_item_count_in_volume(itemTemplate, available_volume.get_value("BACKPACK")))
    if charges == 0 || backpack_id == -1
      return false
    slotName = "inventory"
    parentId = backpack_id
    volume = calculate_boxed_item_volume(itemTemplate, charges)
    available_volume.insert("BACKPACK", available_volume.get_value("BACKPACK") - volume)
  elif (slotName |> starts_with("BACKPACK") || available_volume.get_value("POUCH") < volume) && available_volume.get_value("BACKPACK") >= volume && backpack_id != -1
    slotName = "inventory"
    parentId = backpack_id
    available_volume.insert("BACKPACK", available_volume.get_value("BACKPACK") - volume)
  else
    // no place for item
    return false
  return true


def private generate_weapon(data : Array;
                            corrupt_chance : float;
                            var seed : int&;
                            var result : Array;
                            var item_id_counter : int&;
                            backpack_id, weapon_slot_idx : int;
                            var available_volume : table<string; float>)
  var totalWeight = 0
  for item in data
    totalWeight += (item as Object)?.weight ?? 1
  let rndVal = _rnd_int(seed, 0, totalWeight)
  var acc = 0
  var rndWeaponIdx = -1
  for i in iter_range(data)
    acc += (data[i] as Object)?.weight ?? 1
    if rndVal <= acc
      rndWeaponIdx = i
      break

  if rndWeaponIdx == -1
    return
  let weapon = data[rndWeaponIdx] as Object
  if weapon != null
    let templateName = weapon |> get_string("templateName", "EMPTY")
    if templateName != "EMPTY"
      let weaponTempl = getTemplateByName(templateName)
      let weaponCharges = getTemplateComponent(*weaponTempl, "gun__maxAmmo") ?? 0
      let weaponId = get_item_id(item_id_counter)
      using <| $(var item : Object)
        item |> set("itemId", "{weaponId}")
        item |> set("parentItemId", "0")
        item |> set("slotName", "weapon_{weapon_slot_idx}")
        item |> set("templateName", templateName)
        item |> set("charges", weaponCharges)
        item |> set("isCorrupted", is_corrupted(corrupt_chance))
        result |> push(item)
      for subItem in *weapon
        let items = get_ecs_object(subItem.value)
        if items == null
          continue
        let itemTemplate = get_end_value_with_weight(*items, seed)
        if itemTemplate == "EMPTY"
          continue
        let corrupted = is_corrupted(corrupt_chance)
        var charges = 0
        var volume = 0.f
        var isBoxedItem = false
        let templ = getTemplateByName(itemTemplate)
        if templ != null
          charges = getTemplateComponent(*templ, "item__countPerStack") ?? getTemplateComponent(*templ, "item_holder__maxItemCount") ?? 0
          isBoxedItem = templateHasComponent(*templ, "boxedItem")
          volume = isBoxedItem ? (getTemplateComponent(*templ, "item__volumePerStack") ?? 0.0) : (getTemplateComponent(*templ, "item__volume") ?? 0.0)
        var slotName = subItem.key
        var parentId = weaponId
        if slotName |> starts_with("POUCH") || slotName |> starts_with("BACKPACK")
          if !get_inventory_for_item(itemTemplate, isBoxedItem, corrupted, parentId, charges, volume, slotName, result, item_id_counter, backpack_id, available_volume)
            continue
        using <| $(var item : Object)
          item |> set("itemId", "{get_item_id(item_id_counter)}")
          item |> set("parentItemId", "{parentId}")
          item |> set("slotName", slotName)
          item |> set("templateName", itemTemplate)
          item |> set("charges", charges)
          item |> set("isCorrupted", corrupted)
          result |> push(item)


def private generate_melee_weapon(data : Object;
                                  corrupt_chance : float;
                                  var seed : int&;
                                  var result : Array;
                                  var item_id_counter : int&)
  let itemTemplate = get_end_value_with_weight(data, seed)
  if itemTemplate == "EMPTY"
    return
  using <| $(var item : Object)
    item |> set("itemId", "{get_item_id(item_id_counter)}")
    item |> set("parentItemId", "0")
    item |> set("slotName", "weapon_3")
    item |> set("templateName", itemTemplate)
    item |> set("isCorrupted", is_corrupted(corrupt_chance))
    result |> push(item)


def private generate_stuff(data : Array;
                           corrupt_chance : float;
                           var seed : int&;
                           var result : Array;
                           var item_id_counter : int&;
                           backpack_id : int;
                           var available_volume : table<string; float>)
  let rndStuffIdx = _rnd_int(seed, 0, length(data) - 1)
  let stuff = data[rndStuffIdx] as Object
  if stuff != null
    for subItem in *stuff
      let items = get_ecs_object(subItem.value)
      if items == null
        continue
      let itemTemplate = get_end_value_with_weight(*items, seed)
      if itemTemplate == "EMPTY"
        continue
      var charges = 0
      var volume = 0.f
      var isBoxedItem = false
      let corrupted = is_corrupted(corrupt_chance)
      let templ = getTemplateByName(itemTemplate)
      if templ != null
        charges = (getTemplateComponent(*templ, "item__countPerStack")
                   ?? getTemplateComponent(*templ, "item_holder__maxItemCount")
                   ?? getTemplateComponent(*templ, "item__amount")
                   ?? 0)
        isBoxedItem = templateHasComponent(*templ, "boxedItem")
        volume = isBoxedItem ? (getTemplateComponent(*templ, "item__volumePerStack") ?? 0.0) : (getTemplateComponent(*templ, "item__volume") ?? 0.0)
      var slotName = subItem.key
      var parentId = item_id_counter
      if slotName |> starts_with("POUCH") || slotName |> starts_with("BACKPACK")
        if !get_inventory_for_item(itemTemplate, isBoxedItem, corrupted, parentId, charges, volume, slotName, result, item_id_counter, backpack_id, available_volume)
          continue
      using <| $(var item : Object)
        item |> set("itemId", "{get_item_id(item_id_counter)}")
        item |> set("parentItemId", "{parentId}")
        item |> set("slotName", slotName)
        item |> set("templateName", itemTemplate)
        item |> set("charges", charges)
        item |> set("isCorrupted", corrupted)
        result |> push(item)


def generate_loadout(name : string;
                     corrupt_chance : float;
                     inventory_volume : float;
                     is_fill_inventories : bool;
                     var seed : int&;
                     cb : block<(result : Array) : void> const)
  var itemIdCounter = 1
  var available_volume : table<string; float>
  available_volume.insert("POUCH", inventory_volume)
  available_volume.insert("BACKPACK", 0.f)

  let generatorTemplate = getOrBuildTemplateByName(name)
  if generatorTemplate == null
    logerr("Equipment preset not found in the generator '{name}'")
    return

  let dataObj = getTemplateComponent(*generatorTemplate, "equipment_generator__data") ?as Object
  if dataObj == null
    logerr("'equipment_generator__data' not found in the generator '{name}'")
    return

  using() <| $(var result : Array)
    var backpackId = -1

    let equipments = (*dataObj)["equipments"] ?as Object
    if equipments != null && length(*equipments) > 0
      backpackId = generate_equipment(*equipments, corrupt_chance, seed, result, itemIdCounter, available_volume)

    if !is_fill_inventories
      available_volume |> clear() // so nothink created in backpacks or pouches

    let mainWeapons = (*dataObj)["main_weapons"] ?as Array
    if mainWeapons != null && length(*mainWeapons) > 0
      generate_weapon(*mainWeapons, corrupt_chance, seed, result, itemIdCounter, backpackId, 0, available_volume)

    let pistolWeapons = (*dataObj)["pistol_weapons"] ?as Array
    if pistolWeapons != null && length(*pistolWeapons) > 0
      generate_weapon(*pistolWeapons, corrupt_chance, seed, result, itemIdCounter, backpackId, 2, available_volume)

    let meleeWeapons = (*dataObj)["melee_weapons"] ?as Object
    if meleeWeapons != null && length(*meleeWeapons) > 0
      generate_melee_weapon(*meleeWeapons, corrupt_chance, seed, result, itemIdCounter)

    let medicines = (*dataObj)["medicines"] ?as Array
    if is_fill_inventories && medicines != null && length(*medicines) > 0
      generate_stuff(*medicines, corrupt_chance, seed, result, itemIdCounter, backpackId, available_volume)

    let trash = (*dataObj)["trash"] ?as Array
    if is_fill_inventories && trash != null && length(*trash) > 0
      generate_stuff(*trash, corrupt_chance, seed, result, itemIdCounter, backpackId, available_volume)

    cb |> invoke(result)
