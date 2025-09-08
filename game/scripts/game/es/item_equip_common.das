module item_equip_common shared
require ecs
require strings
require ecs.safe
require rapidjson
require ecs.common
require DagorSystem
require DngHuman
require DagorDataBlock
require game.es.inventory_item_common
require game.es.inventory_weapon_common
require game.es.inventory_weapon_mod_common
require game.es.inventory_equipment_common
require game.es.inventory_equipment_mod_common
require game.es.objectives.objective_common
require game.events.events_active_matter
require game.events.events_game
require game.es.inventory_slots_common


let DEFAULT_BASE_VOLUME = 10.0 // value from human_inventory__maxVolume


// sync with dagor\active_matter\profileServer\structures\battle_results_structures.das
struct BattleResultItem
  itemId : int
  parentItemId : int
  slotName : string
  templateName : string
  charges : int
  isCorrupted : bool
  isReplica : bool
  isCreatedByZone : bool
  isFoundInRaid : bool
  ownerNickname : string
  killerNickname : string
  killedByWeapon : string
  deathReason : string


def read_int64_as_string(obj : Object; name : string)
  return int64(obj |> get_string(name, "0"))


def read_int64_as_string(obj : ChildComponent)
  return int64(obj |> get_string("0"))


def look_up_current_item_on_saving_list(current_hero_items : Array;
                                        item_eid : EntityId)
  let itemName = split_template(getEntityTemplateName(item_eid))[0]
  for item in current_hero_items
    let itemObj = get_ecs_object(item)
    if itemObj != null
      let savingItemName = (*itemObj).templateName ?? ""
      if itemName == savingItemName
        return true
  return false


def look_up_current_item_on_saving_list(result : array<BattleResultItem>;
                                        item_eid : EntityId)
  let itemName = split_template(getEntityTemplateName(item_eid))[0]
  for item in result
    if item.templateName == itemName
      return true
  return false


def push_item_to_saving_list(var current_hero_items : Array; item_eid, inventory_eid : EntityId; slot_name : string)
  if seize_item_for_objective_on_extraction(item_eid)
    let collectedByObjective = is_item_collected_for_some_objective(item_eid)
    print("[Saving Item] Item {item_eid}<{getEntityTemplateName(item_eid)}> was taken for objective {collectedByObjective}<{getEntityTemplateName(collectedByObjective)}>")
    return
  query(item_eid) <| $ [es(REQUIRE_NOT=notExtractable)] (item__extractionTemplateOverride : das_string const?;
                                                         item__overrideTemplateAfterFirstExtractionItem : Tag const?;
                                                         item__isFoundInRaid = true;
                                                         item__currentBoxedItemCount = 0;
                                                         gun__ammo = 0;
                                                         item__hp = 0.0;
                                                         item__amount = 0;
                                                         playerItemOwner = INVALID_ENTITY_ID;
                                                         cortical_vault_inactive__ownerNickname = "";
                                                         cortical_vault_inactive__killerNickname = "";
                                                         cortical_vault_inactive__killedByWeapon = "";
                                                         cortical_vault_inactive__deathReason = "";
                                                         gun_mods__curModInSlots : Object const?;
                                                         equipment_mods__curModInSlots : Object const?;
                                                         item_enriched, item_replica : Tag const?;
                                                         item_created_by_zone : Tag const?)
    if item__extractionTemplateOverride != null && empty(*item__extractionTemplateOverride)
      return // ignore extraction for items with empty override

    using() <| $(var object : Object)
      object |> set("itemId", item_eid)

      var canOverride = true
      if item__overrideTemplateAfterFirstExtractionItem != null
        canOverride = look_up_current_item_on_saving_list(current_hero_items, item_eid)
      if item__extractionTemplateOverride != null && canOverride
        object |> set("templateName", *item__extractionTemplateOverride)
      else
        let templateName = getEntityTemplateName(item_eid)
        object |> set("templateName", split_template(templateName)[0])

      object |> set("parentItemId", inventory_eid)
      object |> set("slotName", slot_name)
      object |> set("isCorrupted", item_enriched != null)
      object |> set("isReplica", item_replica != null)
      object |> set("isFoundInRaid", item__isFoundInRaid)
      object |> set("isCreatedByZone", item_created_by_zone != null)

      query(playerItemOwner) <| $ [es] (name : string)
        object |> set("ownerNickname", name)

      if cortical_vault_inactive__ownerNickname != ""
        object |> set("ownerNickname", cortical_vault_inactive__ownerNickname)
        object |> set("killerNickname", cortical_vault_inactive__killerNickname)
        object |> set("killedByWeapon", cortical_vault_inactive__killedByWeapon)
        object |> set("deathReason", cortical_vault_inactive__deathReason)

      var gunAmmo = gun__ammo
      if gun_mods__curModInSlots != null
        for gunModInSlot in *gun_mods__curModInSlots
          let gunModSlotName = gunModInSlot.key
          let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID
          query(gunModEid) <| $ [es] (var item__currentBoxedItemCount : int?)
            let prevCurrentBoxedItemCount = item__currentBoxedItemCount ?? 0
            if item__currentBoxedItemCount != null
              *item__currentBoxedItemCount = max(gun__ammo - 1, 0)
              gunAmmo = (gun__ammo > 0) ? 1 : 0

            push_item_to_saving_list(current_hero_items, gunModEid, item_eid, gunModSlotName)

            if item__currentBoxedItemCount != null
              *item__currentBoxedItemCount = prevCurrentBoxedItemCount

      elif equipment_mods__curModInSlots != null
        for equipmentModInSlot in *equipment_mods__curModInSlots
          let equipmentModSlotName = equipmentModInSlot.key
          let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
          push_item_to_saving_list(current_hero_items, equipmentModEid, item_eid, equipmentModSlotName)

      if item__currentBoxedItemCount > 0
        object |> set("charges", item__currentBoxedItemCount)
      elif gunAmmo > 0
        object |> set("charges", gunAmmo)
      elif item__hp > 0.0
        object |> set("charges", ceili(item__hp))
      elif item__amount > 0
        object |> set("charges", item__amount)

      current_hero_items |> push(object)


def push_item_to_saving_list(item_eid, inventory_eid : EntityId; slot_name : string; var result : array<BattleResultItem>)
  var itemToSave : BattleResultItem
  if seize_item_for_objective_on_extraction(item_eid)
    let collectedByObjective = is_item_collected_for_some_objective(item_eid)
    print("[Saving Item] Item {item_eid}<{getEntityTemplateName(item_eid)}> was taken for objective {collectedByObjective}<{getEntityTemplateName(collectedByObjective)}>")
    return
  query(item_eid) <| $ [es(REQUIRE_NOT=notExtractable)] (item__extractionTemplateOverride : das_string const?;
                                                         item__overrideTemplateAfterFirstExtractionItem : Tag const?;
                                                         item__isFoundInRaid = true;
                                                         item__currentBoxedItemCount = 0;
                                                         gun__ammo = 0;
                                                         item__hp = 0.0;
                                                         playerItemOwner = INVALID_ENTITY_ID;
                                                         cortical_vault_inactive__ownerNickname = "";
                                                         cortical_vault_inactive__killerNickname = "";
                                                         cortical_vault_inactive__killedByWeapon = "";
                                                         cortical_vault_inactive__deathReason = "";
                                                         gun_mods__curModInSlots : Object const?;
                                                         equipment_mods__curModInSlots : Object const?;
                                                         item_enriched, item_replica : Tag const?;
                                                         item_created_by_zone : Tag const?)
    if item__extractionTemplateOverride != null && empty(*item__extractionTemplateOverride)
      return // ignore extraction for items with empty override

    itemToSave.itemId = int(uint(item_eid))

    var canOverride = true
    if item__overrideTemplateAfterFirstExtractionItem != null
      canOverride = look_up_current_item_on_saving_list(result, item_eid)
    if item__extractionTemplateOverride != null && canOverride
      itemToSave.templateName = string(*item__extractionTemplateOverride)
    else
      let templateName = getEntityTemplateName(item_eid)
      itemToSave.templateName = split_template(templateName)[0]

    itemToSave.parentItemId = int(uint(inventory_eid))
    itemToSave.slotName = slot_name
    itemToSave.isCorrupted = item_enriched != null
    itemToSave.isReplica = item_replica != null
    itemToSave.isFoundInRaid = item__isFoundInRaid
    itemToSave.isCreatedByZone = item_created_by_zone != null

    query(playerItemOwner) <| $ [es] (name : string)
      itemToSave.ownerNickname = name

    if cortical_vault_inactive__ownerNickname != ""
      itemToSave.ownerNickname = cortical_vault_inactive__ownerNickname
      itemToSave.killerNickname = cortical_vault_inactive__killerNickname
      itemToSave.killedByWeapon = cortical_vault_inactive__killedByWeapon
      itemToSave.deathReason = cortical_vault_inactive__deathReason

    var gunAmmo = gun__ammo
    if gun_mods__curModInSlots != null
      for gunModInSlot in *gun_mods__curModInSlots
        let gunModSlotName = gunModInSlot.key
        let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID
        query(gunModEid) <| $ [es] (var item__currentBoxedItemCount : int?)
          let prevCurrentBoxedItemCount = item__currentBoxedItemCount ?? 0
          if item__currentBoxedItemCount != null
            *item__currentBoxedItemCount = max(gun__ammo - 1, 0)
            gunAmmo = (gun__ammo > 0) ? 1 : 0

          push_item_to_saving_list(gunModEid, item_eid, gunModSlotName, result)

          if item__currentBoxedItemCount != null
            *item__currentBoxedItemCount = prevCurrentBoxedItemCount

    elif equipment_mods__curModInSlots != null
      for equipmentModInSlot in *equipment_mods__curModInSlots
        let equipmentModSlotName = equipmentModInSlot.key
        let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
        push_item_to_saving_list(equipmentModEid, item_eid, equipmentModSlotName, result)

    if item__currentBoxedItemCount > 0
      itemToSave.charges = item__currentBoxedItemCount
    elif gunAmmo > 0
      itemToSave.charges = gunAmmo
    elif item__hp > 0.0
      itemToSave.charges = ceili(item__hp)

    result |> push(itemToSave)


def save_weapons(var current_hero_items : Array; weapon_eids : EidList)
  for i in iter_range(weapon_eids)
    query(weapon_eids[i]) <| $ [es(REQUIRE_NOT=notExtractable)] (gun__ammo : int = 0;
                                                                 item__extractionTemplateOverride : das_string const?;
                                                                 item__isFoundInRaid = true;
                                                                 gun_boxed_ammo_reload__reloadState : int const?;
                                                                 gun__boxedAmmoHolderTemplate : string = "";
                                                                 gun_mods__curModInSlots : Object const?;
                                                                 item_enriched, item_replica : Tag const?;
                                                                 item_created_by_zone : Tag const?)
      if item__extractionTemplateOverride != null && empty(*item__extractionTemplateOverride)
        return // ignore extraction for items with empty override

      using() <| $(var object : Object)
        object |> set("itemId", weapon_eids[i])

        if item__extractionTemplateOverride != null
          object |> set("templateName", *item__extractionTemplateOverride)
        else
          let templateName = getEntityTemplateName(weapon_eids[i])
          object |> set("templateName", split_template(templateName)[0])

        object |> set("parentItemId", 0l)
        object |> set("slotName", "{weapon_slots_prefix}{i}")
        object |> set("isCorrupted", item_enriched != null)
        object |> set("isReplica", item_replica != null)
        object |> set("isFoundInRaid", item__isFoundInRaid)
        object |> set("isCreatedByZone", item_created_by_zone != null)

        if gun_boxed_ammo_reload__reloadState != null
          object |> set("charges", gun__ammo)
        else
          object |> set("charges", (gun__ammo > 0 && gun__boxedAmmoHolderTemplate != "") ? 1 : 0)

        current_hero_items |> push(object)

      if gun_mods__curModInSlots != null
        for gunModInSlot in *gun_mods__curModInSlots
          let gunModSlotName = gunModInSlot.key
          let gunModEid = get_Eid(gunModInSlot.value) ?? INVALID_ENTITY_ID

          query(gunModEid) <| $ [es] (var item__currentBoxedItemCount : int?)
            let prevCurrentBoxedItemCount = item__currentBoxedItemCount ?? 0
            if item__currentBoxedItemCount != null
              *item__currentBoxedItemCount = gun__boxedAmmoHolderTemplate != "" ? max(gun__ammo - 1, 0) : gun__ammo

            push_item_to_saving_list(current_hero_items, gunModEid, weapon_eids[i], gunModSlotName)

            if item__currentBoxedItemCount != null
              *item__currentBoxedItemCount = prevCurrentBoxedItemCount


def save_equipments(var current_hero_items : Array;
                    equipment_slots : Object;
                    human_equipment__ignoreSlotsOnExtraction : StringList)
  for eqipmentInSlot in equipment_slots
    let equipmentEid = get_Eid(eqipmentInSlot.value) ?? INVALID_ENTITY_ID
    let slotName = eqipmentInSlot.key

    if human_equipment__ignoreSlotsOnExtraction |> find_index(slotName) >= 0
      continue

    query(equipmentEid) <| $ [es] (item__extractionTemplateOverride : das_string const?;
                                   item__isFoundInRaid = true;
                                   item__hp = 0.0;
                                   equipment_mods__curModInSlots : Object const?;
                                   item_enriched, item_replica : Tag const?;
                                   item_created_by_zone : Tag const?)
      using() <| $(var object : Object)
        object |> set("itemId", equipmentEid)

        if item__extractionTemplateOverride != null
          object |> set("templateName", *item__extractionTemplateOverride)
        else
          let templateName = getEntityTemplateName(equipmentEid)
          object |> set("templateName", split_template(templateName)[0])

        object |> set("parentItemId", 0l)
        object |> set("slotName", "{equipment_slots_prefix}{slotName}")
        object |> set("isCorrupted", item_enriched != null)
        object |> set("isReplica", item_replica != null)
        object |> set("isFoundInRaid", item__isFoundInRaid)
        object |> set("isCreatedByZone", item_created_by_zone != null)

        if item__hp > 0.0
          object |> set("charges", ceili(item__hp))

        current_hero_items |> push(object)

        if equipment_mods__curModInSlots != null
          for equipmentModInSlot in *equipment_mods__curModInSlots
            let equipmentModSlotName = equipmentModInSlot.key
            let equipmentModEid = get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID
            push_item_to_saving_list(current_hero_items, equipmentModEid, equipmentEid, equipmentModSlotName)


def save_inventory(var current_hero_items : Array; inventory_eid : EntityId)
  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      save_inventory(current_hero_items, itemEid)
      let parentEid = inventory_eid |> has("possessedByPlr") ? INVALID_ENTITY_ID : inventory_eid
      push_item_to_saving_list(current_hero_items, itemEid, parentEid, "inventory")


def save_inventory(inventory_eid : EntityId; var result : array<BattleResultItem>)
  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      save_inventory(itemEid, result)
      let parentEid = inventory_eid |> has("possessedByPlr") ? INVALID_ENTITY_ID : inventory_eid
      push_item_to_saving_list(itemEid, parentEid, "inventory", result)


def save_player_items(var current_hero_items : Array;
                      human_weap__gunEids : EidList;
                      inventories : EidList;
                      human_equipment__slots : Object;
                      human_equipment__ignoreSlotsOnExtraction : StringList)
  print("[Raid Profile] save_player_items")
  if current_hero_items |> length() > 0
    current_hero_items |> clear()

  for inventoryEid in inventories
    save_inventory(current_hero_items, inventoryEid)
  save_equipments(current_hero_items, human_equipment__slots, human_equipment__ignoreSlotsOnExtraction)
  save_weapons(current_hero_items, human_weap__gunEids)


def save_player_items(var current_hero_items : Array;
                      hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList;
                             inventories_owner__inventoryEids : EidList;
                             human_equipment__slots : Object)
    using() <| $(var empty_string_list : StringList)
      save_player_items(current_hero_items, human_weap__gunEids, inventories_owner__inventoryEids,
                        human_equipment__slots, empty_string_list)


def hero_clean_all_equipment_and_gun_slots(hero : EntityId)
  query() <| $ [es(REQUIRE=watchedPlayerItem, REQUIRE_NOT=grenade_thrower, REQUIRE_NOT=default_stub_item)] (eid : EntityId)
    destroyEntity(eid)
  query(hero) <| $ [es] (var human_net_phys : HumanActor;
                         var human_weap__gunEids : EidList&;
                         var inventories_owner__inventoryEids : EidList&;
                         var human_equipment__slots : Object&;
                         var itemContainer : EidList&;
                         var player_on_base_components__stashEid : EntityId?)
    itemContainer |> clear()
    for i in iter_range(human_weap__gunEids)
      if human_weap__gunEids[i] |> has("grenade_thrower")
        continue // leave player grenade thrower
      if human_weap__gunEids[i] |> has("default_stub_item")
        continue // leave player default stub itemss
      human_weap__gunEids[i] = INVALID_ENTITY_ID

    human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots.EWS_UNARMED
    human_net_phys.phys.currentState.weapEquipState.nextSlot = HUWeaponSlots.EWS_UNARMED
    human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots.EWS_UNARMED)

    let inventoryEidsSize = length(inventories_owner__inventoryEids)
    for i in iter_range(inventories_owner__inventoryEids)
      let reverseIdx = inventoryEidsSize - 1 - i
      let inventoryEid = inventories_owner__inventoryEids[reverseIdx]
      let isHeroContainer = inventoryEid == hero
      if !isHeroContainer
        destroyEntity(inventoryEid)
        inventories_owner__inventoryEids |> erase(reverseIdx)
    query() <| $ [es(REQUIRE=passive_chronogenes_stash)] (eid : EntityId)
      destroyEntity(eid)
    for it in human_equipment__slots
      var itemEid = getRW_Eid(it.value)
      *itemEid = INVALID_ENTITY_ID
    if player_on_base_components__stashEid != null
      destroyEntity(*player_on_base_components__stashEid)
      *player_on_base_components__stashEid = INVALID_ENTITY_ID


def check_item_attached_to_parent(item_eid : EntityId; hero_eid, parent_eid, stash_eid : EntityId; slot_name : string) : bool

  var res = false
  if slot_name |> starts_with(inventory_slots_prefix)
    query(parent_eid) <| $ [es] (itemContainer : EidList&)
      res = itemContainer |> has_value(item_eid)
  elif slot_name |> starts_with(stash_slots_prefix)
    query(stash_eid) <| $ [es] (itemContainer : EidList&)
      res = itemContainer |> has_value(item_eid)
  elif slot_name |> starts_with(equipment_mod_slots_prefix)
    query(parent_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
      let modEid = equipment_mods__curModInSlots[slot_name] ?? INVALID_ENTITY_ID
      res = modEid == item_eid
  elif slot_name |> starts_with(equipment_slots_prefix)
    query(hero_eid) <| $ [es] (human_equipment__slots : Object)
      let equipmentSlotName = slot_name |> slice(length(equipment_slots_prefix))
      let equipmentEid = human_equipment__slots[equipmentSlotName] ?? INVALID_ENTITY_ID
      res = equipmentEid == item_eid
  elif slot_name |> starts_with(weapon_slots_prefix)
    query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
      let slotWeapIdx = to_int(slot_name |> slice(length(weapon_slots_prefix)))
      let weaponEid = human_weap__gunEids[slotWeapIdx]
      res = weaponEid == item_eid
  else
    query(parent_eid) <| $ [es] (gun_mods__curModInSlots : Object)
      let modEid = gun_mods__curModInSlots[slot_name] ?? INVALID_ENTITY_ID
      res = modEid == item_eid
  return res


def parse_item_id(scheme : Object;
                  field_name : string;
                  var out_item_id : string&)
  if !scheme |> has(field_name)
    return false

  let itemIdProbablyString = get_ecs_string(scheme, field_name)
  if itemIdProbablyString != null
    out_item_id := *itemIdProbablyString
    return true

  let itemIdProbablyEid = get_Eid(scheme, field_name)
  if itemIdProbablyEid != null
    out_item_id := string(uint(*itemIdProbablyEid))
    return true

  let itemIdProbablyInt64 = get_int64(scheme, field_name)
  if itemIdProbablyInt64 != null
    out_item_id := string(*itemIdProbablyInt64)
    return true

  logerr("unsupported item id type!
field_name={field_name}
scheme={scheme}")
  return false


def load_item(item_scheme : Object;
              equipment_manager_eid : EntityId;
              var initial_loadout_creation__itemsMap : Object&;
              player_on_base_components__stashEid : EntityId)
  var itemId : string
  if !parse_item_id(item_scheme, "itemId", itemId)
    logerr("[Item Equipment] Can't create item with empty itemId.
item_scheme={item_scheme}")
    return false
  var itemTemplateName = get_string(item_scheme, "templateName", "")
  if empty(itemTemplateName)
    logerr("[Item Equipment] Can't create item with empty template name.
item_scheme={item_scheme}")
    return false
  itemTemplateName = add_sub_template_name(itemTemplateName, "initial_loadout_item")
  var parentItemId : string
  if !parse_item_id(item_scheme, "parentItemId", parentItemId)
    logerr("[Item Equipment] Can't create item with empty parentItemId.
item_scheme={item_scheme}")
    return false
  let itemSlotName = get_string(item_scheme, "slotName", "")
  var itemCharges = get_int(item_scheme, "charges") ?? 0
  let isCorrupted = get_bool(item_scheme, "isCorrupted") ?? false
  let isReplica = get_bool(item_scheme, "isReplica") ?? false
  let ownerNickname = get_string(item_scheme, "ownerNickname", "")
  let killerNickname = get_string(item_scheme, "killerNickname", "")
  let killedByWeapon = get_string(item_scheme, "killedByWeapon", "")
  let deathReason = get_string(item_scheme, "deathReason", "")

  let parentEid = initial_loadout_creation__itemsMap[parentItemId] ?? INVALID_ENTITY_ID
  var itemEid = initial_loadout_creation__itemsMap[itemId] ?? INVALID_ENTITY_ID
  if itemEid != INVALID_ENTITY_ID
    return true // already created

  var templ = getTemplateByName(itemTemplateName)
  if templ == null
    templ = buildTemplateByName(itemTemplateName)
  if templ == null
    logerr("[Item Equipment] Item template is invalid - {itemTemplateName}!")
    return false

  var maxItemCount = -1
  let itemHolderMaxItemCount = getTemplateComponent(*templ, "item_holder__maxItemCount") ?? -1
  if itemHolderMaxItemCount > 0
    maxItemCount = itemHolderMaxItemCount
  else
    let itemMaxHp = getTemplateComponent(*templ, "item__maxHp") ?? 0.0
    if itemMaxHp > 0.0
      maxItemCount = int(itemMaxHp)
    maxItemCount = getTemplateComponent(*templ, "item__maxAmount") ?? maxItemCount

  if maxItemCount > 0 && itemCharges > maxItemCount
    logerr("[Item Equipment] Charges value {itemCharges} is greater than item_holder__maxItemCount {maxItemCount} for
item_scheme={item_scheme}!")
    itemCharges = maxItemCount

  if parentEid != INVALID_ENTITY_ID
    // we can create
    itemEid = create_item_in_slot(itemTemplateName, parentEid, player_on_base_components__stashEid,
                                  equipment_manager_eid, itemSlotName) <| $(var init)
      init |> set("initial_loadout_item__managerEid", equipment_manager_eid)
      init |> set("initial_loadout_item__slotName", itemSlotName)
      init |> set("initial_loadout_item__parentEid", parentEid)
      init |> set("item__humanOwnerEid", equipment_manager_eid)
      init |> set("item__currentBoxedItemCount", itemCharges)
      init |> set("gun__ammo", itemCharges)
      init |> set("item__hp", float(itemCharges))
      init |> set("item__amount", itemCharges)
      init |> set("gun__serverAmmo", itemCharges)
      init |> set("uniqueId", itemId)
      init |> set("item__wantToBeCorrupted", isCorrupted)
      init |> set("item__wantToBeReplica", isReplica)
      init |> set("cortical_vault_inactive__ownerNickname", ownerNickname)
      init |> set("cortical_vault_inactive__killerNickname", killerNickname)
      init |> set("cortical_vault_inactive__killedByWeapon", killedByWeapon)
      init |> set("cortical_vault_inactive__deathReason", deathReason)
      using() <| $(var ammoKnown : EidList&)
        ammoKnown |> push(equipment_manager_eid)
        init |> set("ammo_holder__ammoCountKnown", ammoKnown)
  if itemEid != INVALID_ENTITY_ID
    initial_loadout_creation__itemsMap |> set(itemId, itemEid)
    return true

  return false


def ensure_items_has_suit(items : Array) : bool
  var result = false
  for item in items
    let slotName = (item as Object)?.slotName ?? ""
    if slotName == "equipment_chronogene_primary_1"
      let templateName = (item as Object)?.templateName ?? ""
      let suitTemplate = getOrBuildTemplateByName(templateName)
      if suitTemplate != null
        let slotAttachSlotName = getTemplateComponent(*suitTemplate, "slot_attach__slotName") ?? ""
        result = slotAttachSlotName == "suit"
      break
  return result


def get_suit_type(items : Array) : int
  var suitType = 0 // SuitType MALE
  for item in items
    let slotName = (item as Object)?.slotName ?? ""
    if slotName == "equipment_chronogene_primary_1"
      let templateName = (item as Object)?.templateName ?? ""
      let suitTemplate = getOrBuildTemplateByName(templateName)
      if suitTemplate != null
        suitType = getTemplateComponent(*suitTemplate, "suit__suitType") ?? 0
      break
  return suitType


def load_items(hero_items : Array; hero_eid : EntityId; map_current_hero_items : bool = true)
  let heroItemId : int64 = 0l
  let totalItems = length(hero_items)
  if totalItems > 0
    addSubTemplate(hero_eid, "initial_loadout_creation") <| $(var init)
      init |> set("initial_loadout_creation__totalItems", totalItems)
      init |> set("initial_loadout_creation__items", hero_items)
      init |> set("initial_loadout_creation__currentWaitTime", 0.0)
      dgs_get_settings() |> datablock_get_block("debug") <| $(blk)
        if blk |> datablock_getBool("disableLoadoutTimeChecks", false)
          init |> set("initial_loadout_creation__totalWaitTime", 999999.0) // for tests like TSAN
      using() <| $(var map : Object)
        map |> set("{heroItemId}", hero_eid)
        if map_current_hero_items
          query() <| $ [es] (uniqueId : string; item__humanOwnerEid, eid : EntityId)
            if item__humanOwnerEid == hero_eid
              map |> set(uniqueId, eid)
        init |> set("initial_loadout_creation__itemsMap", map)


def create_item_in_slot(item_template : string; parent_eid, stash_eid, hero_eid : EntityId; slot_name : string;
                        init_block : block<(var init_obj : ComponentsInitializer) : void>)
  if slot_name |> starts_with(inventory_slots_prefix)
    return create_item_in_inventory_container(item_template, parent_eid, init_block)
  elif slot_name |> starts_with(stash_slots_prefix)
    return create_item_in_inventory_container(item_template, stash_eid, init_block)
  elif slot_name |> starts_with(equipment_mod_slots_prefix)
    return create_mod_in_equipment(item_template, slot_name, parent_eid, hero_eid, true, init_block)
  elif slot_name |> starts_with(equipment_slots_prefix)
    let equipmentSlotName = slot_name |> slice(length(equipment_slots_prefix))
    return create_item_in_equipment(item_template, equipmentSlotName, hero_eid, init_block)
  elif slot_name |> starts_with(weapon_slots_prefix)
    let slotWeapIdx = to_int(slot_name |> slice(length(weapon_slots_prefix)))
    return create_weapon_in_slot(item_template, slotWeapIdx, hero_eid, init_block)
  else
    return create_mod_in_weapon(item_template, slot_name, parent_eid, hero_eid, init_block)


def parse_item_from_jwt(loadoutItem : JsonValue; var initialHeroItems : Array&) : bool
  let itemId = loadoutItem |> json_get_or("itemId", "")
  let templateName = loadoutItem |> json_get_or("templateName", "")
  let parentItemId = loadoutItem |> json_get_or("parentItemId", "")
  let slotName = loadoutItem |> json_get_or("slotName", "")
  let ownerNickName = loadoutItem |> json_get_or("ownerNickname", "")
  let killerNickname = loadoutItem |> json_get_or("killerNickname", "")
  let killedByWeapon = loadoutItem |> json_get_or("killedByWeapon", "")
  let deathReason = loadoutItem |> json_get_or("deathReason", "")
  if empty(itemId) || empty(templateName) || empty(parentItemId) || empty(slotName)
    print("[Apply Initial Items] Fail parse item: itemId <{itemId}> templateName <{templateName}> parentItemId <{parentItemId}> slotName <{slotName}>")
    return false
  using() <| $(var itemObject : Object)
    itemObject |> set("itemId", itemId)
    itemObject |> set("templateName", templateName)
    itemObject |> set("isCorrupted", loadoutItem |> json_get_or("isCorrupted", false))
    itemObject |> set("isReplica", loadoutItem |> json_get_or("isReplica", false))
    itemObject |> set("charges", loadoutItem |> json_get_or("charges", 0))
    itemObject |> set("parentItemId", parentItemId)
    itemObject |> set("slotName", slotName)
    itemObject |> set("ownerNickname", ownerNickName)
    itemObject |> set("killerNickname", killerNickname)
    itemObject |> set("killedByWeapon", killedByWeapon)
    itemObject |> set("deathReason", deathReason)
    initialHeroItems |> push(itemObject)
  return true
