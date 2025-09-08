require DngNet
require DngHuman
require game.es.inventory_common
require game.es.inventory_item_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.revive_common
require game.es.inventory
require ecs.ecs_quirrel
require game.utils.hero
require game.events.events_active_matter
require game.events.events_game
require game.es.ecs_common
require game.es.inventory_weapon_mod_common
require DagorSystem
require game.es.entity_mods_common
require game.es.human.human_use_object_common
require game.es.player_presets_common
require game.es.interrupt_item_use_common


[quirrel_bind(module_name="das.inventory")]
def is_item_useful_for_weapon(to_whom, item_eid : EntityId)
  return inventory_checks_common::is_item_useful_for_weapon(to_whom, item_eid)


[quirrel_bind(module_name="das.inventory")]
def can_pickup_item(item_eid, to_whom : EntityId)
  return inventory_checks_common::is_can_pickup_item(to_whom, item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_pickup_blocked(item_eid : EntityId)
  return !empty(inventory_checks_common::get_item_pickup_block_reason(item_eid, get_controlled_hero()))


[quirrel_bind(module_name="das.inventory")]
def is_hero_can_use_item(item_eid : EntityId)
  return inventory_checks_common::is_hero_can_use_item(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_use_blocked(item_eid : EntityId)
  return inventory_checks_common::is_item_use_blocked(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_inventory_move_blocked(item_eid : EntityId)
  return inventory_checks_common::is_item_inventory_move_blocked(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_can_move_item_to_backpack(item_eid : EntityId)
  return inventory_checks_common::is_can_move_item_to_backpack(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_can_move_item_to_safepack(item_eid : EntityId)
  return inventory_checks_common::is_can_move_item_to_safepack(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_can_move_to_safepack_with_overflow(safepack_eid, item_eid : EntityId)
  return inventory_checks_common::is_can_move_to_safepack_with_overflow(safepack_eid, item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_can_move_item_to_ground(item_eid : EntityId)
  return inventory_checks_common::is_can_move_item_to_ground(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_can_move_item_to_item_container(item_eid : EntityId)
  return inventory_checks_common::is_can_move_item_to_item_container(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_inventory_in_use(inventory_eid : EntityId)
  return inventory_checks_common::is_inventory_in_use(inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def unequip_weapon_from_slot(slot_name : string; to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveWeaponToInventory(slotId = int(HUWeaponSlots(slot_name)), toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def unequip_all_weapon_mods(weapon : EntityId; hero : EntityId; wish_to_inventory_eid : EntityId)
  inventory_weapon_mod_common::unequip_all_weapon_mods(weapon, hero, wish_to_inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def move_item_from_ground_to_inventory(item_eid, to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveItemFromGroundToInventory(itemEid = item_eid, toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def move_item_from_inventory_to_inventory(item_eid, to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveItemFromInventoryToInventory(itemEid = item_eid, toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def split_item_from_ground_to_inventory(item_eid, to_inventory_eid : EntityId; send_full_stack : bool)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    var hasInfo = false
    query(item_eid) <| $ [es] (item__countPerStack : int; item__currentBoxedItemCount : int)
      hasInfo = true
      var wishCount = send_full_stack ? item__currentBoxedItemCount : min(item__currentBoxedItemCount, item__countPerStack)
      wishCount = get_boxed_item_count_to_fit_inventory(to_inventory_eid, item_eid, wishCount)
      if wishCount == 0
        logerr("[INVENTORY] Wish to split zero ammo of {get_entity_info(item_eid)} from ground to {get_entity_info(to_inventory_eid)} ;; ammoCount = {item__currentBoxedItemCount} ; countPerStack = {item__countPerStack}")
        return
      send_net_event(eid, CmdSplitItemToInventory(itemEid = item_eid, toInventoryEid = to_inventory_eid, count = wishCount))
    if !hasInfo
      logerr("[INVENTORY] Can't split item {get_entity_info(item_eid)} from inventory to ground because it's not stackable")


[quirrel_bind(module_name="das.inventory")]
def move_equipped_item_to_inventory(slot_name : string; to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveEquipmentToInventory(slotName = slot_name, toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def move_equipped_item_to_ground(slot_name : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveEquipmentToInventory(slotName = slot_name, toInventoryEid = INVALID_ENTITY_ID))


[quirrel_bind(module_name="das.inventory")]
def move_item_from_inventory_to_slot(item_eid, from_inventory_eid : EntityId; slot_name : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdEquipEquipmentFromInventory(
      itemEid = item_eid, fromInventoryEid = from_inventory_eid, slotName = slot_name))


[quirrel_bind(module_name="das.inventory")]
def move_item_from_ground_to_slot(item_eid : EntityId; slot_name : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdEquipEquipmentFromGround(itemEid = item_eid, slotName = slot_name))


[quirrel_bind(module_name="das.inventory")]
def install_equipment_mod_to_slot(item_mod_eid, from_inventory_eid : EntityId; slot_name : string; equipment_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    if item_mod_eid |> has("boxedItem")
      send_net_event(eid, CmdSplitItemToEquipmentModSlot(
        itemEid = item_mod_eid, equipmentEid = equipment_eid, fromInventoryEid = from_inventory_eid, slotName = slot_name))
    else
      send_net_event(eid, CmdEquipEquipmentModFromInventory(
        itemEid = item_mod_eid, equipmentEid = equipment_eid, fromInventoryEid = from_inventory_eid, slotName = slot_name))


[quirrel_bind(module_name="das.inventory")]
def move_equipped_equipment_mod_to_inventory(equipment_eid : EntityId; slot_name : string; to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveEquipmentModToInventory(
      equipmentEid = equipment_eid, slotName = slot_name, toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def move_equipped_weapon_mod_to_inventory(weapon_slot_name, weapon_mod_slot_name : string; to_inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdMoveWeaponModToInventory(
      slotId = int(HUWeaponSlots(weapon_slot_name)), slotName = weapon_mod_slot_name, toInventoryEid = to_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def install_weapon_mod_to_slot(weapon_mod_eid, from_inventory_eid : EntityId; slot_name : string; weap_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdEquipWeaponModFromInventory(
      itemEid = weapon_mod_eid, weaponEid = weap_eid, fromInventoryEid = from_inventory_eid, slotName = slot_name))


[quirrel_bind(module_name="das.inventory")]
def move_weapon_from_inventory_to_slot(weapon_eid, from_inventory_eid : EntityId; slot_name : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdEquipWeaponFromInventory(itemEid = weapon_eid, slotId = int(HUWeaponSlots(slot_name)), fromInventoryEid = from_inventory_eid))


[quirrel_bind(module_name="das.inventory")]
def pickup_item(item_eid : EntityId)
  human_use_object_common::human_pickup_item(get_controlled_hero(), item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_fast_equip_item_on_pickup_possible(item_eid : EntityId)
  return inventory_checks_common::is_fast_equip_item_possible(get_controlled_hero(), item_eid)


[quirrel_bind(module_name="das.inventory")]
def choose_best_equipment_slot_for_item(item_eid : EntityId)
  var bestSlot = ""
  query(item_eid) <| $ [es] (item__equipmentSlots : StringList)
    if length(item__equipmentSlots) != 0
      bestSlot = inventory_common::choose_best_equipment_slot_for_item(get_controlled_hero(), item_eid, item__equipmentSlots)
  return bestSlot


[quirrel_bind(module_name="das.inventory")]
def is_equip_to_slot_cause_inventory_overflow(item_eid : EntityId; to_slot : string; drop_prev_to_cont : EntityId)
  return inventory_common::is_equip_to_slot_cause_inventory_overflow(get_controlled_hero(), item_eid, to_slot, drop_prev_to_cont)


[quirrel_bind(module_name="das.inventory")]
def is_equip_to_slot_cause_from_pocket_drop(item_eid : EntityId; to_slot : string; drop_prev_to_cont : EntityId)
  return inventory_common::is_equip_to_slot_cause_from_pocket_drop(get_controlled_hero(), item_eid, to_slot, drop_prev_to_cont)


[quirrel_bind(module_name="das.inventory")]
def is_autoequip_cause_inventory_overflow(item_eid : EntityId)
  return inventory_common::is_autoequip_cause_inventory_overflow(get_controlled_hero(), item_eid)


[quirrel_bind(module_name="das.inventory")]
def move_stack_to_inventory(item_eids : array<EntityId>; inventory_eid : EntityId; count : int)
  return inventory_common::move_stack_to_inventory(item_eids, inventory_eid, count)


[quirrel_bind(module_name="das.inventory")]
def drop_item_from_inventory(item_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdDropItemFromInventory(itemEid = item_eid))


[quirrel_bind(module_name="das.inventory")]
def is_inventory_have_free_volume(inventory_eid : EntityId; item_volume : float)
  return inventory_checks_common::is_inventory_have_free_volume(inventory_eid, item_volume)


[quirrel_bind(module_name="das.inventory")]
def is_inventory_have_free_volume_for_boxed_item_eid(inventory_eid : EntityId; box_eid : EntityId)
  return get_boxed_item_count_to_fit_inventory(inventory_eid, box_eid, 1) > 0


[quirrel_bind(module_name="das.inventory")]
def is_inventory_have_free_volume_for_boxed_item_template(inventory_eid : EntityId; box_template : string)
  // if 1 element of boxed item can fit, so we can move at least 1 of it in this container
  return get_boxed_item_count_to_fit_inventory(inventory_eid, box_template, 1) > 0


[quirrel_bind(module_name="das.inventory")]
def is_inventory_read_only(inventory_eid : EntityId)
  return inventory_checks_common::is_inventory_read_only(inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def is_hero_have_free_inventory_volume(item_eid : EntityId)
  var res = false
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId)
    res = inventory_checks_common::is_can_pickup_item_in_inventory(eid, item_eid)
  return res


[quirrel_bind(module_name="das.inventory")]
def is_hero_have_free_slot_for_item(item_eid : EntityId)
  var result = false
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid : EntityId)
    result = is_can_pickup_item_in_weapon_slots(eid, item_eid) || is_can_pickup_item_in_equipment_slots(eid, item_eid)
  return result


[quirrel_bind(module_name="das.inventory")]
def get_inventory_for_item_by_volume(hero_eid, item_eid : EntityId)
  return inventory_checks_common::get_inventory_for_item_by_volume(hero_eid, item_eid)


[quirrel_bind(module_name="das.inventory")]
def swap_weapons_in_slots(from_slot_name, to_slot_name : string)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId; human_weap__gunEids : EidList)
    let fromSlot = int(HUWeaponSlots(from_slot_name))
    let toSlot = int(HUWeaponSlots(to_slot_name))
    let fromWeaponEid = human_weap__gunEids[fromSlot]
    send_net_event(eid, CmdEquipWeaponFromInventory(itemEid = fromWeaponEid, slotId = toSlot, fromInventoryEid = INVALID_ENTITY_ID))


[quirrel_bind(module_name="das.inventory")]
def is_quest_item(item_eid : EntityId)
  return inventory_checks_common::is_quest_item(item_eid)


[quirrel_bind(module_name="das.inventory")]
def is_quest_item_for_player(item_eid, player_eid : EntityId)
  return inventory_checks_common::is_quest_item_for_player(item_eid, player_eid)


[quirrel_bind(module_name="das.inventory")]
def is_quest_item_for_player_by_hero(item_eid, hero_eid : EntityId)
  return inventory_checks_common::is_quest_item_for_player_by_hero(item_eid, hero_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_hidden_for_player(item_eid, player_eid : EntityId)
  return inventory_checks_common::is_item_hidden_for_player(item_eid, player_eid)


[quirrel_bind(module_name="das.inventory")]
def is_item_hidden_for_player_by_hero(item_eid, hero_eid : EntityId)
  return inventory_checks_common::is_item_hidden_for_player_by_hero(item_eid, hero_eid)

[quirrel_bind(module_name="das.inventory")]
def is_quest_item_for_other_player(item_eid, player_eid : EntityId)
  return inventory_checks_common::is_quest_item_for_other_player(item_eid, player_eid)


[quirrel_bind(module_name="das.inventory")]
def is_quest_item_for_other_player_by_hero(item_eid, hero_eid : EntityId)
  return inventory_checks_common::is_quest_item_for_other_player_by_hero(item_eid, hero_eid)


[quirrel_bind(module_name="das.inventory")]
def get_current_move_mod_for_weapon(weapon_eid : EntityId)
  return inventory_checks_common::get_current_move_mod_for_weapon(weapon_eid)


[quirrel_bind(module_name="das.inventory")]
def is_move_mod_from_weapon(item_eid : EntityId)
  return inventory_checks_common::is_move_mod_from_weapon(item_eid)


[quirrel_bind(module_name="das.inventory")]
def get_current_revive_price(player_eid : EntityId)
  return revive_common::get_current_revive_price(player_eid)


[quirrel_bind(module_name="das.inventory")]
def get_equipment_slot_for_item(hero_eid, item_eid : EntityId)
  return inventory_checks_common::get_equipment_slot_for_item(hero_eid, item_eid)


[quirrel_bind(module_name="das.inventory")]
def get_equipped_item_for_installing_mod(hero_eid, mod_eid : EntityId)
  return inventory_checks_common::get_free_slot_for_mod(hero_eid, mod_eid)


[quirrel_bind(module_name="das.inventory")]
def get_slot_and_equipment_for_mod(var result : Object&; hero_eid, mod_eid : EntityId)
  inventory_checks_common::get_slot_and_equipment_for_mod(result, hero_eid, mod_eid)


[quirrel_bind(module_name="das.inventory")]
def get_weapon_slot_for_item(hero_eid, weap_id : EntityId)
  return inventory_checks_common::get_weapon_slot_for_item(hero_eid, weap_id)


[quirrel_bind(module_name="das.inventory")]
def is_weapon_slot_available_for_equip(slot_name : string)
  var res = false
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    res = inventory_checks_common::is_weapon_slot_available_for_equip(eid, int(HUWeaponSlots(slot_name)))
  return res


[quirrel_bind(module_name="das.inventory")]
def is_on_equip_weapon_prev_can_fit(weapon_eid : EntityId; slot_name : string; from_inventory_eid : EntityId)
  var res = false
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    res = inventory_checks_common::is_on_equip_weapon_prev_can_fit(weapon_eid, int(HUWeaponSlots(slot_name)), eid, from_inventory_eid)
  return res


[quirrel_bind(module_name="das.inventory")]
def is_on_equip_weapon_mod_prev_can_fit(weapon_mod_eid : EntityId; slot_name : string; weap_eid : EntityId; from_inventory_eid : EntityId)
  return inventory_checks_common::is_on_equip_weapon_mod_prev_can_fit(weapon_mod_eid, slot_name, weap_eid, from_inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def is_on_equip_equipment_prev_can_fit(item_eid : EntityId; slot_name : string; from_inventory_eid : EntityId)
  var res = false
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    res = inventory_checks_common::is_on_equip_equipment_prev_can_fit(item_eid, slot_name, eid, from_inventory_eid)
  return res


[quirrel_bind(module_name="das.inventory")]
def is_on_equip_equipment_mod_prev_can_fit(item_mod_eid : EntityId; slot_name : string; equipment_eid : EntityId; from_inventory_eid : EntityId)
  return inventory_checks_common::is_on_equip_equipment_mod_prev_can_fit(item_mod_eid, slot_name, equipment_eid, from_inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def notify_equip_in_occupied_slot_failed(inventory_eid : EntityId)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    inventory_item_common::notify_equip_in_occupied_slot_failed(eid, inventory_eid)


[quirrel_bind(module_name="das.inventory")]
def find_items_in_inventory_by_template_name(templateName : string; containerEid : EntityId)
  return <- inventory_item_common::find_items_in_inventory_by_template_name(templateName, containerEid)


[quirrel_bind(module_name="das.inventory")]
def convert_volume_to_int(volume : float)
  return inventory_checks_common::convert_volume_to_int(volume)


[quirrel_bind(module_name="das.inventory")]
def calc_stacked_item_volume(stack_size, count : int; stack_volume : float)
  return inventory_checks_common::calc_stacked_item_volume(stack_size, count, stack_volume)


[quirrel_bind(module_name="das.inventory")]
def ceil_volume(volume : float)
  return ceil(volume * 10.f) / 10.f


[quirrel_bind(module_name="das.inventory")]
def calc_diminishing_change_mult_attr(map : Object)
  return entity_mods_common::calc_diminishing_change_mult_attr(map)


[quirrel_bind(module_name="das.inventory")]
def calc_change_mult_attr(map : Object)
  return entity_mods_common::calc_change_mult_attr(map)


[quirrel_bind(module_name="das.inventory")]
def calc_change_add_attr(map : Object)
  return entity_mods_common::calc_change_add_attr(map)


[quirrel_bind(module_name="das.inventory")]
def calc_diminishing_change_add_attr(map : Object)
  return entity_mods_common::calc_diminishing_change_add_attr(map)


[quirrel_bind(module_name="das.inventory")]
def load_player_preset(map : Object)
  player_presets_common::load_player_preset(map)


[quirrel_bind(module_name="das.inventory")]
def get_preset_unequip_volume_int(hero_eid, backpack_eid, safepack_eid : EntityId)
  return player_presets_common::get_preset_unequip_volume_int(hero_eid, backpack_eid, safepack_eid)


[quirrel_bind(module_name="das.inventory")]
def find_suitable_item(stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId; item_template : string; banned_eids : array<EntityId>)
  return player_presets_common::find_suitable_item(stash_eid, hero_eid, backpack_eid, safepack_eid, item_template, banned_eids)


[quirrel_bind(module_name="das.inventory")]
def find_suitable_weapon(item_template : string; attachments : Object&; stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId; banned_eids : array<EntityId>&)
  return player_presets_common::find_suitable_weapon(item_template, attachments, stash_eid, hero_eid, backpack_eid, safepack_eid, banned_eids)


[quirrel_bind(module_name="das.inventory")]
def collect_available_boxed_items(stash_eid, hero_eid, backpack_eid, safepack_eid : EntityId)
  return player_presets_common::collect_available_boxed_items(stash_eid, hero_eid, backpack_eid, safepack_eid)


[quirrel_bind(module_name="das.inventory")]
def check_item_can_be_used(human_eid, item_eid : EntityId)
  return interrupt_item_use_common::check_item_can_be_used(human_eid, item_eid) == CanUseItemResponse.Approved