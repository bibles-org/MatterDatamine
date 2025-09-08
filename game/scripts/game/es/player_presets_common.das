module player_presets_common shared
require ecs
require ecs.safe
require ecs.common
require strings
require DngHuman
require game.es.level_common
require game.es.status_tip_common
require game.events.events_active_matter
require game.utils.spawn
require game.es.boxed_item_common
require game.es.inventory_weapon_mod_common
require game.es.human_reload_common
require game.es.inventory_transactions_common
require game.es.inventory_checks_common
require game.es.inventory_weapon_common
require game.es.inventory_item_common
require game.es.inventory_equipment_mod_common
require game.es.inventory_equipment_common
require game.es.inventory_drop_common
require DagorSystem
require DaWeaponProps
require daslib/strings_boost
require HumanPhys
require math.base

def get_preset_unequip_volume_int(hero_eid : EntityId; backpack_eid : EntityId; safepack_eid : EntityId)
  var needVolume = 0.0
  var needVolumeFromInventories = 0

  //check pockets & armorplates
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList; human_equipment__slots : Object)
    for weapEid in human_weap__gunEids
      if has(weapEid, "default_stub_item")
        continue

      query(weapEid) <| $ [es] (item__volume aka weapon_item__volume : float; gun_mods__curModInSlots : Object const?)
        needVolume += weapon_item__volume

        if gun_mods__curModInSlots == null
          return
        for mod in *gun_mods__curModInSlots
          let eid = mod.value ?? INVALID_ENTITY_ID
          if eid == INVALID_ENTITY_ID
            continue

          query(eid) <| $ [es] (item__volume aka mod_item__volume : float)
            needVolume += mod_item__volume

    let chronogene = get_Eid(human_equipment__slots["chronogene_primary_1"]) ?? INVALID_ENTITY_ID
    query(chronogene) <| $ [es] (equipment_mods__curModInSlots : Object)
      for mod in equipment_mods__curModInSlots
        let currentEid = get_Eid(equipment_mods__curModInSlots[mod.key]) ?? INVALID_ENTITY_ID
        query(currentEid) <| $ [es] (item__volume : float)
          needVolume += item__volume

  //check backpack inventory
  query(backpack_eid) <| $ [es] (human_inventory__currentVolume : int)
    needVolumeFromInventories += human_inventory__currentVolume

  //check safepack inventory
  query(safepack_eid) <| $ [es] (human_inventory__currentVolume : int)
    needVolumeFromInventories += human_inventory__currentVolume

  //check load vest inventory
  query(hero_eid) <| $ [es] (human_inventory__currentVolume : int)
    needVolumeFromInventories += human_inventory__currentVolume

  //check equipment
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    for equipIt in human_equipment__slots
      if starts_with(equipIt.key, "chronogene")
        continue
      let equipmentEid = get_Eid(equipIt.value) ?? INVALID_ENTITY_ID
      if equipmentEid == INVALID_ENTITY_ID
        continue
      query(equipmentEid) <| $ [es] (item__volume : float)
        needVolume += item__volume

      query(equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
        for mod in equipment_mods__curModInSlots
          let currentEid = get_Eid(equipment_mods__curModInSlots[mod.key]) ?? INVALID_ENTITY_ID
          query(currentEid) <| $ [es] (item__volume : float)
            needVolume += item__volume

  return convert_volume_to_int(needVolume) + needVolumeFromInventories


def unequip_all(preset : Object; hero_eid : EntityId; stash_eid : EntityId; backpack_eid : EntityId; safepack_eid : EntityId)
  var unequippingCount = 0
  let frameNumber = int(get_dagor_frame_no())
  query(hero_eid) <| $ [es] (human_equipment__slots : Object; human_weap__gunEids : EidList; uniqueId aka hero_uniqueId : string)
    //move from weapon slots
    for i in range(length(human_weap__gunEids))
      let weapEid = human_weap__gunEids[i]
      query(weapEid) <| $ [es(REQUIRE_NOT=default_stub_item)] (slot_attach__weaponSlotIdx : int; gun_mods__curModInSlots : Object const?)
        if slot_attach__weaponSlotIdx == int(HUWeaponSlots.EWS_GRENADE)
          return

        if gun_mods__curModInSlots != null
          var keys : array<string>
          for mod in *gun_mods__curModInSlots
            push(keys, "{mod.key}")

          for mod in keys
            let eid = get_Eid((*gun_mods__curModInSlots)[mod]) ?? INVALID_ENTITY_ID
            addSubTemplate(eid, "player_preset_item_unequip_in_progress") <| $(var init)
              init |> set("player_preset__frameNumber", frameNumber)
            unequippingCount++

            unequip_weapon_mod_from_slot(mod, weapEid, hero_eid, stash_eid)
            report_item_move_transaction(eid, hero_uniqueId, "stash")

        addSubTemplate(weapEid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)

        report_item_move_transaction(weapEid, hero_uniqueId, "stash")
        unequip_weapon_from_slot(i, hero_eid, stash_eid)
        unequippingCount++

    //move armor plate and pockets
    let chronogene = get_Eid(human_equipment__slots["chronogene_primary_1"]) ?? INVALID_ENTITY_ID
    query(chronogene) <| $ [es] (equipment_mods__curModInSlots : Object)
      var keys : array<string>
      for mod in equipment_mods__curModInSlots
        //we need to clone string. unequip_equipment_mod_from_slot will delete the prev string
        push(keys, "{mod.key}")

      for mod in keys
        let eid = get_Eid(equipment_mods__curModInSlots[mod]) ?? INVALID_ENTITY_ID
        addSubTemplate(eid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)
        unequippingCount++

        report_item_move_transaction(eid, hero_uniqueId, "stash")
        unequip_equipment_mod_from_slot(eid, chronogene, hero_eid, stash_eid)

    //move from backpack
    query(backpack_eid) <| $ [es] (itemContainer : EidList)
      for itemEid in itemContainer
        addSubTemplate(itemEid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)
        unequippingCount++

        move_item_to_inventory_container(itemEid, stash_eid, hero_eid)
        report_item_move_transaction(itemEid, hero_uniqueId, "stash")

    //move from safepack
    query(safepack_eid) <| $ [es] (itemContainer : EidList)
      for itemEid in itemContainer
        addSubTemplate(itemEid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)
        unequippingCount++

        move_item_to_inventory_container(itemEid, stash_eid, hero_eid)
        report_item_move_transaction(itemEid, hero_uniqueId, "stash")

    //move from load vest
    query(hero_eid) <| $ [es] (itemContainer : EidList)
      for itemEid in itemContainer
        addSubTemplate(itemEid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)
        unequippingCount++
        report_item_move_transaction(itemEid, hero_uniqueId, "stash")
        move_item_to_inventory_container(itemEid, stash_eid, hero_eid)

    //move other equipment
    query(hero_eid) <| $ [es] (human_equipment__slots : Object; var human_inventory__maxVolumeInt : int&)
      for equipIt in human_equipment__slots
        let slotName = equipIt.key
        if starts_with(slotName, "chronogene") || starts_with(slotName, "passive_chronogenes_stash")
          continue

        let equipmentEid = get_Eid(equipIt.value) ?? INVALID_ENTITY_ID

        if equipmentEid == INVALID_ENTITY_ID
          continue

        query(equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object; item__inventoryExtension : float = 0.0)
          if (item__inventoryExtension > 0.0)
            human_inventory__maxVolumeInt -= convert_volume_to_int(item__inventoryExtension)

          var keys : array<string>
          for mod in equipment_mods__curModInSlots
            push(keys, "{mod.key}")

          for mod in keys
            let eid = get_Eid(equipment_mods__curModInSlots[mod]) ?? INVALID_ENTITY_ID
            addSubTemplate(eid, "player_preset_item_unequip_in_progress") <| $(var init)
              init |> set("player_preset__frameNumber", frameNumber)
            unequippingCount++

            report_item_move_transaction(eid, hero_uniqueId, "stash")
            unequip_equipment_mod_from_slot(eid, equipmentEid, hero_eid, stash_eid)

        addSubTemplate(equipmentEid, "player_preset_item_unequip_in_progress") <| $(var init)
          init |> set("player_preset__frameNumber", frameNumber)
        unequippingCount++
        report_item_move_transaction(equipmentEid, hero_uniqueId, "stash")
        unequip_equipment_from_slot(slotName, hero_eid, stash_eid)

  if unequippingCount != 0
    find_query() <| $ [es] (var player_on_base__playerPreset : Object&; var player_on_base__itemsToBeMoved : int&)
      player_on_base__itemsToBeMoved = unequippingCount
      player_on_base__playerPreset := preset
      return true
  else
    equip_player_preset(preset)


def get_weapon_score(item_template : string; attachments : Object&; weapon_eid : EntityId; banned_eids : array<EntityId>)
  var score = -1
  if has_value(banned_eids, weapon_eid)
    return score
  query(weapon_eid) <| $ [es(REQUIRE=item_weapon)] (item__proto aka weapon_item__proto : string; gun_mods__curModInSlots : Object const?)
    if item_template != weapon_item__proto
      return

    score = 0
    //weapon without mods (e.g. melee)
    if gun_mods__curModInSlots == null
      return

    for it in attachments
      let modEid = get_Eid(gun_mods__curModInSlots, it.key) ?? INVALID_ENTITY_ID
      let modValue = get_ecs_object(it.value)
      if (modValue == null)
        continue

      let wishMode = get_string(modValue, "itemTemplate", "")
      if modEid == INVALID_ENTITY_ID && empty(wishMode)
        score++
        continue
      query(modEid) <| $ [es] (item__proto aka mod_item__proto : string)
        if mod_item__proto == wishMode
          score++
  return score


def write_eid_and_score(itemEid : EntityId; score : int; bestPossible : int; var bestItem : EntityId&; var bestScore : int&)
  if score > bestScore
    bestScore = score
    bestItem = itemEid
    if score == bestPossible
      return true
  return false


def find_suitable_weapon_in_container(item_template : string; attachments : Object&; stash_eid : EntityId; banned_eids : array<EntityId>; var best_score : int&; var cur_best_item : EntityId&)
  let theBestPossibleScore = length(attachments)
  query(stash_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      if write_eid_and_score(itemEid, get_weapon_score(item_template, attachments, itemEid, banned_eids), theBestPossibleScore, cur_best_item, best_score)
        return


def find_suitable_weapon(item_template : string; attachments : Object&; stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId; banned_eids : array<EntityId>&)
  var bestItem = INVALID_ENTITY_ID
  var bestScore = -1
  let theBestPossibleScore = length(attachments)

  find_suitable_weapon_in_container(item_template, attachments, stash_eid, banned_eids, bestScore, bestItem)
  find_suitable_weapon_in_container(item_template, attachments, hero_eid, banned_eids, bestScore, bestItem)
  find_suitable_weapon_in_container(item_template, attachments, backpack_eid, banned_eids, bestScore, bestItem)
  find_suitable_weapon_in_container(item_template, attachments, safepack_eid, banned_eids, bestScore, bestItem)

  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    for weapEid in human_weap__gunEids
      if write_eid_and_score(weapEid, get_weapon_score(item_template, attachments, weapEid, banned_eids), theBestPossibleScore, bestItem, bestScore)
        return

  return bestItem


def install_mods_on_weapon(weapon_eid : EntityId; attachments : Object&; hero_eid : EntityId; stash_eid : EntityId; var banned_eids : array<EntityId>&)
  query(hero_eid) <| $ [es] (uniqueId aka hero_uniqueId : string)
    query(weapon_eid) <| $ [es] (gun_mods__curModInSlots : Object; uniqueId aka weapon_uniqueId : string)
      for attachIt in attachments
        let currentEid = get_Eid(gun_mods__curModInSlots, attachIt.key) ?? INVALID_ENTITY_ID

        let modValue = get_ecs_object(attachIt.value)
        if (modValue == null)
          continue

        let wishAttach = get_string(modValue, "itemTemplate", "")
        if currentEid == INVALID_ENTITY_ID && empty(wishAttach)
          continue

        query(currentEid) <| $ [es] (item__proto : string)
          if (item__proto == wishAttach)
            return

          unequip_weapon_mod_from_slot(attachIt.key, weapon_eid, hero_eid, stash_eid)
          report_item_move_transaction(currentEid, hero_uniqueId, "stash")

        var foundEid : EntityId = INVALID_ENTITY_ID
        var foundScore = 0
        query(stash_eid) <| $ [es] (itemContainer : EidList)
          for itemEid in itemContainer
            if has_value(banned_eids, itemEid)
              continue
            query(itemEid) <| $ [es] (item__proto : string; item__hp : float = 0.0; item__currentBoxedItemCount : int = 0; item_enriched : Tag const?)
              if (wishAttach != item__proto)
                return

              let score = get_common_item_score(item__hp, item__currentBoxedItemCount, item_enriched)
              if score > foundScore
                foundScore = score
                foundEid = itemEid

        if foundEid == INVALID_ENTITY_ID
          continue

        push(banned_eids, foundEid)
        equip_weapon_mod_to_slot(foundEid, attachIt.key, weapon_eid, hero_eid, stash_eid)
        report_item_move_transaction(foundEid, weapon_uniqueId, attachIt.key)


def collect_available_boxed_items_in_container(container_eid : EntityId; var collected_table : table<string; int>)
  query(container_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es(REQUIRE=boxedItem)] (item__currentBoxedItemCount : int)
        let templateName = (getEntityTemplateName(itemEid) |> split("+"))[0]
        let found = get(collected_table, templateName) <| $(var val)
          val += item__currentBoxedItemCount

        if !found
          collected_table.insert(templateName, item__currentBoxedItemCount)


def collect_available_boxed_items(stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId)
  var ret : table<string; int>

  collect_available_boxed_items_in_container(stash_eid, ret)
  collect_available_boxed_items_in_container(hero_eid, ret)
  collect_available_boxed_items_in_container(backpack_eid, ret)
  collect_available_boxed_items_in_container(safepack_eid, ret)

  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    let chronogene = get_Eid(human_equipment__slots["chronogene_primary_1"]) ?? INVALID_ENTITY_ID
    query(chronogene) <| $ [es] (equipment_mods__curModInSlots : Object)
      for equipmentModInSlot in equipment_mods__curModInSlots
        let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
        query(equipmentModEid) <| $ [es(REQUIRE=boxedItem)] (item__currentBoxedItemCount : int)
          let templateName = (getEntityTemplateName(equipmentModEid) |> split("+"))[0]
          let found = get(ret, templateName) <| $(var val)
            val += item__currentBoxedItemCount

          if !found
            ret.insert(templateName, item__currentBoxedItemCount)
  return <- ret


def get_common_item_score(item__hp : float; item__currentBoxedItemCount : int; item_enriched : Tag const?)
  let enrichedScore = item_enriched == null ? 1000 : 0
  let defaultScore = 1 //just for override default 0 points
  return defaultScore + enrichedScore + int(item__hp) + max(item__currentBoxedItemCount, 0)


def find_suitable_item_in_inventory(inventory_eid : EntityId; item_template : string; banned_eids : array<EntityId>;
                                    var best_eid : EntityId&; var best_score : int&)
  if empty(item_template)
    return

  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      if has_value(banned_eids, itemEid)
        continue
      query(itemEid) <| $ [es] (item__proto : string; item__hp : float = 0.0; item__currentBoxedItemCount : int = -1; item_enriched : Tag const?)
        if (item_template != item__proto || item__currentBoxedItemCount == 0)
          return

        let score = get_common_item_score(item__hp, item__currentBoxedItemCount, item_enriched)
        if score > best_score
          best_score = score
          best_eid = itemEid


def find_suitable_item(stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId; item_template : string; banned_eids : array<EntityId>)
  var foundEid : EntityId = INVALID_ENTITY_ID
  var foundScore = -1

  find_suitable_item_in_inventory(stash_eid, item_template, banned_eids, foundEid, foundScore)
  find_suitable_item_in_inventory(hero_eid, item_template, banned_eids, foundEid, foundScore)
  find_suitable_item_in_inventory(backpack_eid, item_template, banned_eids, foundEid, foundScore)
  find_suitable_item_in_inventory(safepack_eid, item_template, banned_eids, foundEid, foundScore)

  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    let chronogene = get_Eid(human_equipment__slots["chronogene_primary_1"]) ?? INVALID_ENTITY_ID
    query(chronogene) <| $ [es] (equipment_mods__curModInSlots : Object)
      for it in equipment_mods__curModInSlots
        let eid = get_Eid(it.value) ?? INVALID_ENTITY_ID
        if has_value(banned_eids, eid)
          continue
        query(eid) <| $ [es] (item__proto : string; item__hp : float = 0.0; item__currentBoxedItemCount : int = 0; item_enriched : Tag const?)
          if item__proto != item_template
            return

          let score = get_common_item_score(item__hp, item__currentBoxedItemCount, item_enriched)
          if score > foundScore
            foundScore = score
            foundEid = eid

  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    for slotIt in human_equipment__slots
      let eid = get_Eid(slotIt.value) ?? INVALID_ENTITY_ID
      if has_value(banned_eids, eid)
        continue
      query(eid) <| $ [es] (item__proto : string; item__hp : float = 0.0; item__currentBoxedItemCount : int = 0; item_enriched : Tag const?)
        if item__proto != item_template
          return

        let score = get_common_item_score(item__hp, item__currentBoxedItemCount, item_enriched)
        if score > foundScore
          foundScore = score
          foundEid = eid

  return foundEid


def check_armor(item_template : string; armorEid : EntityId; var current_best_hp : float&; var currentBestEid : EntityId&)
  var isBetter = false
  query(armorEid) <| $ [es] (eid : EntityId; item__proto : string; item__hp : float)
    if item__proto != item_template
      return

    if item__hp > current_best_hp
      current_best_hp = item__hp
      currentBestEid = eid
      isBetter = true

  return isBetter


def equip_armor_and_pockets(armorPreset : Object; hero_eid : EntityId; backpack_eid : EntityId; stash_eid : EntityId; safepack_eid : EntityId; var bannedList : array<EntityId>&)
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    let chronogene = get_Eid(human_equipment__slots["chronogene_primary_1"]) ?? INVALID_ENTITY_ID
    query(chronogene) <| $ [es] (@shared_comp equipment_mods__slots : Object; uniqueId aka chronogene_uniqueId : string)
      for mod in equipment_mods__slots
        let obj = get_ecs_object(armorPreset[mod.key])
        let wishTemplate = get_string(obj, "itemTemplate", "")

        if empty(wishTemplate)
          continue

        let currentEquipmentTemplate = getTemplateByName(get_string(mod.value, ""))
        let suitableTemplates = get_ecs_StringList(getTemplateComponent(*currentEquipmentTemplate, "slot_holder__availableItems"))
        let suits = suitableTemplates != null && has_value(*suitableTemplates, wishTemplate)
        if !suits
          continue

        var equipmentEid = INVALID_ENTITY_ID
        equipmentEid = find_suitable_item(stash_eid, hero_eid, backpack_eid, safepack_eid, wishTemplate, bannedList)

        if equipmentEid == INVALID_ENTITY_ID
          continue

        let isPocket = starts_with(mod.key, "equipment_mod_pocket_")

        if isPocket
          query(equipmentEid) <| $ [es] (item__currentBoxedItemCount : int = 1; boxedItem : Tag const?)
            if item__currentBoxedItemCount == 1 || boxedItem == null
              equip_equipment_mod_to_slot(equipmentEid, mod.key, chronogene, hero_eid, stash_eid)
              push(bannedList, equipmentEid)
            else
              split_item_to_equipment(equipmentEid, mod.key, chronogene, hero_eid, 1)
            report_item_move_to_pocket_transaction(equipmentEid, chronogene_uniqueId, mod.key)
        else
          push(bannedList, equipmentEid)

          equip_equipment_mod_to_slot(equipmentEid, mod.key, chronogene, hero_eid, stash_eid)
          report_item_move_transaction(equipmentEid, chronogene_uniqueId, mod.key)


def move_to_inventory(presetObj : Object; targetInventoryName : string; targetInventoryEid, stashInventoryEid, actorEid : EntityId; uniqueId : string; var bannedList : array<EntityId>&; var currentVolumeInt : int&)
  let itemTemplate = get_string(presetObj, "itemTemplate", "")
  let templ = getTemplateByName(itemTemplate)
  let isBoxedItem = templateHasComponent(*templ, "boxedItem")

  query(targetInventoryEid) <| $ [es] (human_inventory__maxVolumeInt : int)
    if isBoxedItem
      let ammoCount = get_int(presetObj, "ammoCount") ?? 0
      var foundEid = INVALID_ENTITY_ID
      var bestScore = 0
      find_suitable_item_in_inventory(stashInventoryEid, itemTemplate, bannedList, foundEid, bestScore)
      if foundEid == INVALID_ENTITY_ID
        return
      query(foundEid) <| $ [es] (item__currentBoxedItemCount : int; item__countPerStack : int; item__volumePerStack : float)
        if item__currentBoxedItemCount == -1
          return
        let emptyVolume = human_inventory__maxVolumeInt - currentVolumeInt
        //TODO: find or make function for line below. Seems like get_boxed_item_count_to_fit_inventory is closest to this logic
        //but we cannot count on current volume of inventory due to calculation at one frame
        let maxBoxedCount = int(float(emptyVolume) / float(convert_volume_to_int(item__volumePerStack)) * float(item__countPerStack))

        let split = min(ammoCount, item__currentBoxedItemCount, maxBoxedCount)
        if (split == 0)
          return

        currentVolumeInt += calc_stacked_item_volume(item__countPerStack, split, item__volumePerStack)

        if item__currentBoxedItemCount != ammoCount
          split_item_to_inventory_container(foundEid, targetInventoryEid, actorEid, split)
          report_item_split_transaction(foundEid, split, uniqueId, targetInventoryName)
        else
          move_item_to_inventory_container(foundEid, targetInventoryEid, actorEid)
          report_item_move_transaction(foundEid, uniqueId, targetInventoryName)
          push(bannedList, foundEid)
    else
      var transferCount = get_int(presetObj, "count") ?? 0
      while transferCount > 0
        var foundEid = INVALID_ENTITY_ID
        var bestScore = 0
        find_suitable_item_in_inventory(stashInventoryEid, itemTemplate, bannedList, foundEid, bestScore)
        if foundEid == INVALID_ENTITY_ID
          return

        query(foundEid) <| $ [es] (item__volume : float)
          let emptyVolume = human_inventory__maxVolumeInt - currentVolumeInt
          let itemVolumeInt = convert_volume_to_int(item__volume)
          if emptyVolume < itemVolumeInt
            return

          currentVolumeInt += itemVolumeInt
          move_item_to_inventory_container(foundEid, targetInventoryEid, actorEid)
          report_item_move_transaction(foundEid, uniqueId, targetInventoryName)
          push(bannedList, foundEid)
        transferCount--


def equip_player_preset(data)
  var human_inventory_eid = INVALID_ENTITY_ID
  var backpack_eid = INVALID_ENTITY_ID
  var stash_eid = INVALID_ENTITY_ID
  var safepack_eid = INVALID_ENTITY_ID

  find_query() <| $ [es] (eid : EntityId;
                          militant_extra_inventories__backpackEid : EntityId;
                          militant_extra_inventories__safepackEid : EntityId;
                          player_on_base_components__stashEid : EntityId)
    human_inventory_eid = eid
    stash_eid = player_on_base_components__stashEid
    backpack_eid = militant_extra_inventories__backpackEid
    safepack_eid = militant_extra_inventories__safepackEid
    return true

  let weapons = get_ecs_array(data, "weapons")
  let chronogenePrimary = get_ecs_object(data, "chronogene_primary_1")
  let inventories = get_ecs_object(data, "inventories")
  if (weapons == null || chronogenePrimary == null || inventories == null)
    logerr("[Hero preset] preset \"{get_string(data, "presetName", "")}\" must contain all fields. Weapons: {weapons}. Primary chronogene: {chronogenePrimary}. Inventories: {inventories}.")
    return

  //weapons
  var bannedList : array<EntityId>
  query(human_inventory_eid) <| $ [es] (uniqueId : string; var human_net_phys : HumanActor&)
    var isWeaponSet = false
    for i in range(length(*weapons))
      let templateName = get_string(weapons?[i] ?as Object, "itemTemplate", "")

      if empty(templateName)
        continue
      let attachments = get_ecs_object(weapons?[i] ?as Object, "attachments")
      var bestScore = -1
      var weaponEid = INVALID_ENTITY_ID
      find_suitable_weapon_in_container(templateName, *attachments, stash_eid, bannedList, bestScore, weaponEid)
      if weaponEid == INVALID_ENTITY_ID
        continue

      if !isWeaponSet
        isWeaponSet = true
        human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(i))

      push(bannedList, weaponEid)

      install_mods_on_weapon(weaponEid, *attachments, human_inventory_eid, stash_eid, bannedList)
      report_item_move_transaction(weaponEid, uniqueId, "{WEAPON_PREFIX}{i}")
      equip_weapon_to_slot(weaponEid, i, human_inventory_eid, stash_eid)

      if !isWeaponSet
        isWeaponSet = true
        human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_MELEE)

  //armor, pockets
  equip_armor_and_pockets(*chronogenePrimary, human_inventory_eid, backpack_eid, stash_eid, safepack_eid, bannedList)

  //equipment
  query(human_inventory_eid) <| $ [es] (human_equipment__slots : Object; uniqueId : string; var human_inventory__maxVolumeInt : int&)
    for equipIt in human_equipment__slots
      let slotName = equipIt.key
      if starts_with(slotName, "chronogene") || starts_with(slotName, "passive_chronogenes_stash")
        continue

      let obj = get_ecs_object(data, slotName)

      if obj == null
        continue

      let templateName = get_string(obj, "itemTemplate", "")
      var foundEid = INVALID_ENTITY_ID
      var bestScore = 0
      find_suitable_item_in_inventory(stash_eid, templateName, bannedList, foundEid, bestScore)

      query(foundEid) <| $ [es(REQUIRE_NOT=boxedItem)] ()
        push(bannedList, foundEid)

      if foundEid == INVALID_ENTITY_ID
        continue

      if slotName == "backpack"
        backpack_eid = foundEid
      if slotName == "safepack"
        safepack_eid = foundEid

      query(foundEid) <| $ [es] (uniqueId aka found_uniqueId : string; item__inventoryExtension : float = 0.0)
        if (item__inventoryExtension > 0.0)
          human_inventory__maxVolumeInt += convert_volume_to_int(item__inventoryExtension)

        let attachmentsObj = get_ecs_object(obj, "attachments")

        if (attachmentsObj == null)
          return

        for field in *attachmentsObj
          let innerSlot = get_ecs_object(field.value)
          if innerSlot == null
            continue

          let innerTemplateName = get_string(innerSlot, "itemTemplate", "")
          if (empty(innerTemplateName))
            continue

          var foundInnerEid = INVALID_ENTITY_ID
          var bestInnerScore = 0
          find_suitable_item_in_inventory(stash_eid, innerTemplateName, bannedList, foundInnerEid, bestInnerScore)

          let isPocket = starts_with(field.key, "equipment_mod_pocket_")

          if isPocket
            query(foundInnerEid) <| $ [es] (item__currentBoxedItemCount : int = -1; boxedItem : Tag const?)
              if item__currentBoxedItemCount == 1 || boxedItem == null
                equip_equipment_mod_to_slot(foundInnerEid, field.key, foundEid, human_inventory_eid, stash_eid)
                push(bannedList, foundInnerEid)
              else
                split_item_to_equipment(foundInnerEid, field.key, foundEid, human_inventory_eid, 1)
              report_item_move_to_pocket_transaction(foundInnerEid, found_uniqueId, field.key)
          else
            push(bannedList, foundInnerEid)

            equip_equipment_mod_to_slot(foundInnerEid, field.key, foundEid, human_inventory_eid, stash_eid)
            report_item_move_transaction(foundInnerEid, found_uniqueId, field.key)

      equip_equipment_to_slot(foundEid, slotName, human_inventory_eid)
      report_item_move_transaction(foundEid, uniqueId, "equipment_{slotName}")


  let myItems = inventories?["myItems"] ?as Object
  let myItemsArr = myItems?["items"] ?as Array
  let backpackItems = inventories?["backpack"] ?as Object
  let backpackItemsArr = backpackItems?["items"] ?as Array
  let safepackItems = inventories?["safepack"] ?as Object
  let safepackItemsArr = safepackItems?["items"] ?as Array

  //move to hero inventory
  if myItemsArr != null
    query(human_inventory_eid) <| $ [es] (uniqueId : string)
      var currentVolume = 0
      for itemIt in *myItemsArr
        let obj = get_ecs_object(itemIt)
        if obj == null
          continue

        move_to_inventory(*obj, "inventory", human_inventory_eid, stash_eid, human_inventory_eid, uniqueId, bannedList, currentVolume)

  //move to backpack
  if backpackItemsArr != null
    query(backpack_eid) <| $ [es] (uniqueId : string)
      var currentVolume = 0
      for itemIt in *backpackItemsArr
        let obj = get_ecs_object(itemIt)
        if obj == null
          continue

        move_to_inventory(*obj, "inventory", backpack_eid, stash_eid, human_inventory_eid, uniqueId, bannedList, currentVolume)

  // move to safepack
  if safepackItemsArr != null
    query(safepack_eid) <| $ [es] (uniqueId : string)
      var currentVolume = 0
      for itemIt in *safepackItemsArr
        let obj = get_ecs_object(itemIt)
        if obj == null
          continue

        move_to_inventory(*obj, "inventory", safepack_eid, stash_eid, human_inventory_eid, uniqueId, bannedList, currentVolume)


def load_player_preset(preset : Object)
  let weapons = get_ecs_array(preset, "weapons")
  let armors = get_ecs_object(preset, "chronogene_primary_1")
  if (weapons == null || armors == null)
    logerr("[Hero preset] preset must contain all fields")
    return

  var human_inventory_eid = INVALID_ENTITY_ID
  var stash_eid = INVALID_ENTITY_ID
  var backpack_eid = INVALID_ENTITY_ID
  var safepack_eid = INVALID_ENTITY_ID

  var currentVolume = 0
  var maxVolume = 0

  find_query() <| $ [es] (eid : EntityId;
                          militant_extra_inventories__backpackEid : EntityId;
                          player_on_base_components__stashEid : EntityId;
                          militant_extra_inventories__safepackEid : EntityId)
    human_inventory_eid = eid
    stash_eid = player_on_base_components__stashEid
    backpack_eid = militant_extra_inventories__backpackEid
    safepack_eid = militant_extra_inventories__safepackEid
    return true

  query(stash_eid) <| $ [es] (human_inventory__maxVolumeInt : int; human_inventory__currentVolume : int)
    currentVolume = human_inventory__currentVolume
    maxVolume = human_inventory__maxVolumeInt

  if human_inventory_eid == INVALID_ENTITY_ID
    logerr("[Hero presets] Cannot find hero")
    return

  let needVolume = get_preset_unequip_volume_int(human_inventory_eid, backpack_eid, safepack_eid)
  if needVolume > (maxVolume - currentVolume)
    logerr("[Hero presets] Not enough volume in stash. Needs {needVolume}, but stash has {maxVolume - currentVolume}")
    return

  if needVolume == 0
    equip_player_preset(preset)
  else
    //after unequipping we will call equip_player_preset, but with some delay
    unequip_all(preset, human_inventory_eid, stash_eid, backpack_eid, safepack_eid)
