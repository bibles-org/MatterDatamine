require ecs
require ecs.safe
require DagorFiles
require strings
require Grid
require DagorMath
require DngNet
require DaWeapons
require CompressionUtils
require BitStream
require game.es.custom_region_common
require game.events.events_game
require game.events.events_active_matter
require game.events.inventory_events
require game.es.level_common
require game.es.stat_bq_common

let FILENAME = "player_actions_log"

def clear_old_log()
  return
  // df_open(FILENAME, DF_CREATE | DF_WRITE) <| $(outputFile)
  //   outputFile |> df_puts("")


def log_action(action : string)
  if !is_raid_mode()
    return
  find_query() <| $ [es] (is_local : bool; var player_actions_log : StringList)
    if is_local
      player_actions_log |> push(action)
      return true
    return false
  // df_open(FILENAME, DF_WRITE | DF_APPEND) <| $(outputFile)
  //   outputFile |> df_puts("{action}\n")


def get_region_name(pos : float3)
  var region_name : string = ""
  find_query() <| $ [es] (custom_region__name : string;
                          custom_region__points : Point2List;
                          custom_region__triangulationIdxs : IntList;
                          transform : float3x4)
    let bboxDiag = 0.5 * (transform[0] + transform[1] + transform[2])
    let bbox = BBox3(transform[3] - bboxDiag, transform[3] + bboxDiag)
    if is_point_inside_region(pos, custom_region__points, custom_region__triangulationIdxs, bbox)
      region_name := custom_region__name
      return true
    return false
  return region_name


def get_near_region_name(pos : float3; scale : float)
  var region_name : string = ""
  find_query() <| $ [es] (custom_region__name : string;
                          transform : float3x4)
    let bboxDiag = 0.5 * (transform[0] + transform[1] + transform[2]) * scale
    let bbox = BBox3(transform[3] - bboxDiag, transform[3] + bboxDiag)
    if bbox & pos
      region_name := custom_region__name
      return true
    return false
  return region_name


def log_action(action : string; pos : float3)
  let region_name = get_region_name(pos)
  let near_region_name = get_near_region_name(pos, 2f)
  if region_name != ""
    log_action("{action} in {region_name}")
  elif near_region_name != ""
    log_action("{action} near to {near_region_name}")
  else
    log_action("{action}")


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def log_action_spawn(evt : Event;
                     possessedByPlr : EntityId;
                     transform : float3x4)
  query(possessedByPlr) <| $ [es] (clientNetFlags : int)
    let isFirstSpawn = (clientNetFlags & int(ClientNetFlags CNF_SPAWNED_AT_LEAST_ONCE)) == 0
    if isFirstSpawn
      clear_old_log()
      find_query() <| $ [es] (level__raidName : string)
        log_action("hero spawned in level with raid name {level__raidName}", transform[3])
        return true


[es(tag=gameClient, track=player__spawnCount)]
def log_action_revive(evt : Event;
                      is_local : bool;
                      possessed : EntityId;
                      player__spawnCount : int)
  if is_local && player__spawnCount > 1
    var alive = false
    query(possessed) <| $ [es] (isAlive : bool; transform : float3x4)
      alive = isAlive
      if alive
        log_action("hero revived", transform[3])
    if !alive // hasn't replicated yet
      log_action("hero revived")


[es(tag=gameClient, REQUIRE=hero)]
def log_action_hit(evt : EventOnEntityHit;
                   eid : EntityId;
                   human_weap__currentGunEid : EntityId;
                   transform : float3x4)
  if evt.victim == eid
    var offenderType : string = ""
    var weapon : string = ""
    query(evt.offender) <| $ [es] (kill_tracking_tag : string;
                                   human_weap__currentGunEid = INVALID_ENTITY_ID)
      offenderType := kill_tracking_tag
      query(human_weap__currentGunEid) <| $ [es] (item__proto : string)
        weapon := item__proto
    if evt.offender == evt.victim
      log_action("hero was hitted by self", transform[3])
    elif offenderType != ""
      if weapon != ""
        log_action("hero was hitted by {offenderType} with {weapon}", transform[3])
      else
        log_action("hero was hitted by {offenderType}", transform[3])
    else
      log_action("hero was hitted", transform[3])
  elif evt.offender == eid
    var weapon : string = ""
    query(human_weap__currentGunEid) <| $ [es] (item__proto : string)
      weapon := item__proto
    query(evt.victim) <| $ [es] (kill_tracking_tag : string)
      if weapon != ""
        log_action("hero with {weapon} wounded {kill_tracking_tag}", transform[3])
      else
        log_action("hero wounded {kill_tracking_tag}", transform[3])


[es(tag=gameClient, REQUIRE=hero)]
def log_action_recieved_damage(evt : EventDamageModelApplyDamage;
                               transform : float3x4)
  log_action("hero reiceved {evt.notBlockedDamage} damage", transform[3])
  if evt.totalDamage - evt.notBlockedDamage > 0f
    log_action("hero blocked {evt.totalDamage - evt.notBlockedDamage} damage", transform[3])


[es(tag=gameClient, REQUIRE=hero, track=human_damage_model__parts)]
def log_action_broke_smth(evt : Event;
                          human_damage_model__parts : Object)
  for partComp in human_damage_model__parts
    let part = partComp.value as Object
    if (part?.isInjured ?? false)
      log_action("hero has hardly injured {partComp.key}")


[es(tag=gameClient, REQUIRE=hero)]
def log_action_died(evt : EventEntityDied;
                    transform : float3x4)
  var offenderType : string = ""
  query(evt.offender) <| $ [es] (kill_tracking_tag : string)
    offenderType := kill_tracking_tag
  if evt.offender == evt.victim
    log_action("hero suiced", transform[3])
  elif offenderType != ""
    log_action("hero is killed by {offenderType}", transform[3])
  else
    log_action("hero died", transform[3])


[es(tag=gameClient)]
def log_action_extracted(evt : CmdExtractFromBattlefield; possessed : EntityId)
  query(possessed) <| $ [es(REQUIRE=hero)] (transform : float3x4)
    log_action("hero extracted", transform[3])

// inventory actions

def get_inventory_name(hero_eid, inventory_eid : EntityId)
  var res_name = ""
  query(inventory_eid) <| $ [es] (inventory__name : string;
                                  inventory__humanOwnerEid : EntityId;
                                  openable_ri__closed : string = "";
                                  item__proto : string = "";
                                  itemContainer__name : string = "")
    if inventory__humanOwnerEid == hero_eid
      res_name := inventory__name
    elif openable_ri__closed != ""
      res_name := openable_ri__closed
    elif item__proto != ""
      res_name := "outer {item__proto}"
    else
      res_name := itemContainer__name
  return res_name


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_pickup_item(evt : EventOnItemPickup;
                           eid : EntityId;
                           transform : float3x4)
  query(evt.itemEid) <| $ [es] (item__proto : string)
    log_action("hero picked up {item__proto} to {get_inventory_name(eid, evt.toInventoryEid)}", transform[3])


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_drop_item(evt : EventOnItemDrop; eid : EntityId)
  query(evt.itemEid) <| $ [es] (item__proto : string)
    log_action("hero dropped {item__proto} from {get_inventory_name(eid, evt.fromInventoryEid)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_move_to_inventory_item(evt : EventOnItemMovedBetweenInventory;
                                      eid : EntityId)
  query(evt.itemEid) <| $ [es] (item__proto : string)
    log_action("hero moved {item__proto} from {get_inventory_name(eid, evt.oldInventoryEid)} to {get_inventory_name(eid, evt.newInventoryEid)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_equip_equipment(evt : EventOnEquipmentEquipped)
  query(evt.equipmentEid) <| $ [es] (item__proto : string)
    log_action("hero equipped {item__proto} in slot {evt.slotName}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_unequip_equipment(evt : EventOnEquipmentUnequipped; eid : EntityId)
  query(evt.equipmentEid) <| $ [es] (item__proto : string)
    if evt.toInventoryEid == INVALID_ENTITY_ID
      log_action("hero dropped equipment {item__proto} from slot {evt.slotName}")
    else
      log_action("hero unequipped equipment {item__proto} from slot {evt.slotName} to {get_inventory_name(eid, evt.toInventoryEid)}")

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_equip_equipment_mod(evt : EventOnEquipmentModEquippedToEquipment)
  query(evt.equipmentModEid) <| $ [es] (item__proto aka m_item__proto : string)
    query(evt.equipmentEid) <| $ [es] (item__proto aka e_item__proto : string)
      log_action("hero equipped {m_item__proto} to {e_item__proto} in slot {evt.slotName}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_unequip_equipment_mod(evt : EventOnEquipmentModUnequippedFromEquipment; eid : EntityId)
  query(evt.equipmentModEid) <| $ [es] (item__proto aka m_item__proto : string)
    query(evt.equipmentEid) <| $ [es] (item__proto aka e_item__proto : string)
      if evt.toInventoryEid == INVALID_ENTITY_ID
        log_action("hero dropped equipment_mod {m_item__proto} from equipment {e_item__proto} from slot {evt.slotName}")
      else
        log_action("hero unequipped equipment_mod {m_item__proto} from equipment {e_item__proto} from slot {evt.slotName} to {get_inventory_name(eid, evt.toInventoryEid)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_swap_equipment_mods(evt : EventOnEquipmentModSwap)
  query(evt.firstEquipmentModEid) <| $ [es] (item__proto aka m1_item__proto : string)
    query(evt.firstEquipmentEid) <| $ [es] (item__proto aka e1_item__proto : string)
      query(evt.secondEquipmentModEid) <| $ [es] (item__proto aka m2_item__proto : string)
        query(evt.secondEquipmentEid) <| $ [es] (item__proto aka e2_item__proto : string)
          log_action("hero swapped {m1_item__proto} from {e1_item__proto} in slot {evt.firstSlotName} with {m2_item__proto} from {e2_item__proto} in slot {evt.secondSlotName}")


def get_weapon_slot_name(slot : int)
  if slot == 0
    return "primary"
  elif slot == 1
    return "secondary"
  elif slot == 2
    return "pistol"
  elif slot == 3
    return "melee"
  return "unknown"


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_equip_weapon(evt : EventOnWeaponEquipped)
  query(evt.weaponEid) <| $ [es] (item__proto : string)
    log_action("hero equipped {item__proto} in slot {get_weapon_slot_name(evt.slotId)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_unequip_weapon(evt : EventOnWeaponUnequipped; eid : EntityId)
  query(evt.weaponEid) <| $ [es] (item__proto : string)
    if evt.toInventoryEid == INVALID_ENTITY_ID
      log_action("hero dropped weapon {item__proto} from slot {get_weapon_slot_name(evt.slotId)}")
    else
      log_action("hero unequipped weapon {item__proto} from slot {get_weapon_slot_name(evt.slotId)} to {get_inventory_name(eid, evt.toInventoryEid)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_swap_weapons(evt : EventOnWeaponSwap)
  query(evt.firstWeaponEid) <| $ [es] (item__proto aka w1_item__proto : string)
    query(evt.secondWeaponEid) <| $ [es] (item__proto aka w2_item__proto : string)
      log_action("hero swapped {w1_item__proto} from slot {get_weapon_slot_name(evt.firstSlotId)} with {w2_item__proto} from slot {get_weapon_slot_name(evt.secondSlotId)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_equip_weapon_mod(evt : EventOnWeaponModEquipped)
  query(evt.weaponModEid) <| $ [es] (item__proto aka m_item__proto : string)
    query(evt.weaponEid) <| $ [es] (item__proto aka w_item__proto : string)
      log_action("hero equipped {m_item__proto} to {w_item__proto} in slot {evt.slotName}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_unequip_weapon_mod(evt : EventOnWeaponModUnequipped; eid : EntityId)
  query(evt.weaponModEid) <| $ [es] (item__proto aka m_item__proto : string;
                                     gunAttachable__slotName : string)
    query(evt.weaponEid) <| $ [es] (item__proto aka w_item__proto : string)
      if evt.toInventoryEid == INVALID_ENTITY_ID
        log_action("hero dropped weapon mod {m_item__proto} from weapon {w_item__proto} from slot {gunAttachable__slotName}")
      else
        log_action("hero unequipped weapon mod {m_item__proto} from weapon {w_item__proto} from slot {gunAttachable__slotName} to {get_inventory_name(eid, evt.toInventoryEid)}")


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def log_action_try_pickup_item(evt : CmdItemPickup;
                               transform : float3x4)
  query(evt.item) <| $ [es] (item__proto : string)
    log_action("hero try to pick up {item__proto}", transform[3])


[es(tag=gameClient, REQUIRE=(watchedPlayerItem, boxedItem), on_appear, track=item__currentBoxedItemCount)]
def log_action_boxed_item_count(evt : Event;
                                item__humanOwnerEid : EntityId;
                                item__containerOwnerEid : EntityId;
                                item__currentBoxedItemCount : int;
                                boxed_item__template : string)
  if !has(item__humanOwnerEid, "hero") || has(item__humanOwnerEid, "deadEntity")
    return
  let inventoryName = get_inventory_name(item__humanOwnerEid, item__containerOwnerEid)
  if inventoryName != "" // it could be pockets
    log_action("hero has {item__currentBoxedItemCount} of {boxed_item__template} in {inventoryName}")

// item usage

def get_part_name_by_id(human_damage_model__parts : Object;
                        part_id : int)
  for part, idx in human_damage_model__parts, iter_range(human_damage_model__parts)
    if idx == part_id
      return part.key
  return ""


[es(tag=gameClient, on_appear, REQUIRE=healing_effect__effectVisualStrength)]
def log_action_heal(evt : Event;
                    game_effect__attachedTo : EntityId;
                    healing_effect__healAmount : float = 0f;
                    healing_effect__bodypartIdx : int = 0;
                    healing_effect__healByTickAmount : float = 0f;
                    healing_effect__healTicksCount : int = 0;
                    healing_of_time_effect : Tag const?)
  if !has(game_effect__attachedTo, "hero")
    return
  query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (human_damage_model__parts : Object; transform : float3x4)
    if healing_of_time_effect != null
      log_action("hero used healing injector to heal {float(healing_effect__healTicksCount) * healing_effect__healByTickAmount} hp", transform[3])
    else
      log_action("hero used healing ampoule to heal {healing_effect__healAmount} hp of {get_part_name_by_id(human_damage_model__parts, healing_effect__bodypartIdx)}", transform[3])


[es(tag=gameClient, on_appear, REQUIRE=cortical_vault_revive__traceParams)]
def log_action_revive_teammate(evt : Event;
                               game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (game_effect__attachedTo : EntityId)
    query(game_effect__attachedTo) <| $ [es(REQUIRE=hero)] (transform : float3x4)
      log_action("hero revived teammate", transform[3])


[es(tag=gameObject, REQUIRE=hero)]
def log_action_item_holder_loading(evt : NotifyItemHolderLoadingEnd)
  query(evt.holderEid) <| $ [es] (item__proto : string;
                                  item_holder__boxedItemTemplate : string)
    if evt.wishToLoad
      log_action("hero loaded {evt.count} {item_holder__boxedItemTemplate} in {item__proto} holder")
    else
      log_action("hero unloaded {evt.count} {item_holder__boxedItemTemplate} from {item__proto} holder")

// make contract

[es(tag=gameClient, track=objective__isCompleted)]
def log_action_contract_completed(evt : Event;
                                  objective__name : string;
                                  objective__playerEid : EntityId;
                                  objective__isCompleted : bool)
  query(objective__playerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es(REQUIRE=hero)] (transform : float3x4)
      if objective__isCompleted
        log_action("contract {objective__name} completed", transform[3])
      else
        log_action("contract {objective__name} fallback progress")


// recognition

[es(tag=gameClient, REQUIRE=hero)]
def log_action_item_recognized(evt : CmdMarkItemRecognized)
  query(evt.itemEid) <| $ [es] (item__proto : string)
    log_action("hero recognized {item__proto}")


[es(tag=gameClient, REQUIRE=hero, track=external_inventory_interactor__inventoryEid)]
def log_action_container_open(evt : Event; eid, possessedByPlr : EntityId;
                              external_inventory_interactor__inventoryEid : EntityId;
                              transform : float3x4)
  query(external_inventory_interactor__inventoryEid) <| $ [es] (itemContainer : EidList)
    var unrecognizedCount = 0
    for item in itemContainer
      query(item) <| $ [es] (item__recognizedByPlayers : EidList)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          unrecognizedCount += 1
    log_action("hero opened container {get_inventory_name(eid, external_inventory_interactor__inventoryEid)} with {length(itemContainer)} items", transform[3])
    log_action("there is {unrecognizedCount} unrecognized items in container")


[es(tag=gameClient, REQUIRE=hero, track=militant_extra_inventories__backpackEid)]
def log_action_backpack_found(evt : Event; eid, possessedByPlr : EntityId;
                              militant_extra_inventories__backpackEid : EntityId;
                              transform : float3x4)
  query(militant_extra_inventories__backpackEid) <| $ [es] (itemContainer : EidList)
    var unrecognizedCount = 0
    for item in itemContainer
      query(item) <| $ [es] (item__recognizedByPlayers : EidList)
        if !has_value(item__recognizedByPlayers, possessedByPlr)
          unrecognizedCount += 1
    if unrecognizedCount > 0
      log_action("hero found backpack {get_inventory_name(eid, militant_extra_inventories__backpackEid)} with {length(itemContainer)} items", transform[3])
      log_action("there is {unrecognizedCount} unrecognized items in backpack")

// shooting

[es(tag=gameClient, REQUIRE_NOT=hero)]
def log_action_killed(evt : EventEntityDied;
                      kill_tracking_tag : string)
  query(evt.offender) <| $ [es(REQUIRE=hero)] (transform : float3x4)
    log_action("hero killed {kill_tracking_tag}", transform[3])


def find_shootable_object(from, dir : float3; len : float; ignore_human, ignore_vehicle : EntityId)
  var targetEid = INVALID_ENTITY_ID
  var rad = 5f
  var dist = len
  find_entity_in_grid(ecs_hash("traceable_spheres"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  find_entity_in_grid(ecs_hash("am_cores"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  find_entity_in_grid(ecs_hash("humans"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    if eid == ignore_human
      return false
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  find_entity_in_grid(ecs_hash("creatures"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  find_entity_in_grid(ecs_hash("vehicles"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    if eid == ignore_vehicle
      return false
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  find_entity_in_grid(ecs_hash("interactable"), from, dir, dist, rad, GridEntCheck BOUNDING) <| $(eid : EntityId; pos : float3)
    targetEid = eid
    dist = dot(pos - from, dir)
    rad = length((pos - from) - dot(pos - from, dir) * dir)
    return true
  return targetEid


[es(tag=gameClient, on_appear)]
def log_action_shoot(evt : Event;
                     ownerEid : EntityId;
                     gunEid : EntityId;
                     launch_desc : LaunchDesc)
  query(gunEid) <| $ [es] (gun__length : float = 0.65)
    let shootPos = launch_desc.tm[3]
    let shootDir = normalize(launch_desc.vel)
    let startPos = shootPos - shootDir * gun__length
    query(ownerEid) <| $ [es(REQUIRE=hero)] (transform : float3x4;
                                             human_anim__vehicleSelected : EntityId)
      let shootedEid = find_shootable_object(startPos, shootDir, gun__length, ownerEid, human_anim__vehicleSelected)
      query(shootedEid) <| $ [es] (kill_tracking_tag : string)
        log_action("hero try to shoot in {kill_tracking_tag}", transform[3])


[es(tag=gameClient, REQUIRE=hero)]
def log_action_reload_boxed(evt : NotifyGunBoxedAmmoLoadingEnd;
                            transform : float3x4)
  query(evt.gunEid) <| $ [es] (item__proto : string)
    log_action("hero reloaded {evt.count} ammo to {item__proto}", transform[3])


[es(tag=gameClient, REQUIRE=hero, after=log_action_equip_weapon_mod)]
def log_action_reload_magazine(evt : EventOnWeaponModEquipped;
                               transform : float3x4)
  query(evt.weaponModEid) <| $ [es] (item__currentBoxedItemCount : int)
    query(evt.weaponEid) <| $ [es] (item__proto : string;
                                    gun__ammo : int)
      let ammoCount = item__currentBoxedItemCount + gun__ammo
      log_action("hero reloaded {item__proto} with magazine. Current ammo {ammoCount}", transform[3])

// movement

[es(tag=gameClient)]
def log_action_trans_portal_used(evt : EventTransPortalTeleport;
                                 possessed : EntityId)
  query(possessed) <| $ [es(REQUIRE=hero)]
    let region_name = get_region_name(evt.from)
    let near_region_name = get_near_region_name(evt.from, 2f)
    if region_name != ""
      log_action("hero teleported from {region_name}", evt.to)
    elif near_region_name != ""
      log_action("hero teleported from place near to {near_region_name}", evt.to)
    else
      log_action("hero teleported", evt.to)


[es(tag=gameClient, no_order)]
def log_action_enter_region(info : UpdateStageInfoAct;
                            possessed : EntityId;
                            player_move_track__checkInterval : float;
                            var player_move_track__nextCheckAt : float&;
                            var player_move_track__lastRegion : das_string&)
  query(possessed) <| $ [es(REQUIRE=hero)] (transform : float3x4)
    if (player_move_track__nextCheckAt > info.curTime)
      return

    player_move_track__nextCheckAt = info.curTime + player_move_track__checkInterval
    let region_name = get_region_name(transform[3])
    if string(player_move_track__lastRegion) != region_name
      if string(player_move_track__lastRegion) != ""
        log_action("hero leaved {player_move_track__lastRegion}")
      if region_name != ""
        log_action("hero entered {region_name}")
      player_move_track__lastRegion := region_name


[es(tag=gameClient, on_appear, REQUIRE=(hero, mindcontrolled_monster))]
def log_action_become_monster(evt : Event;
                              transform : float3x4;
                              kill_tracking_tag : string)
  log_action("hero became monster {kill_tracking_tag}", transform[3])


[es(tag=gameClient, track=map_object_marker__isActive)]
def log_action_encounter_visit(evt : Event;
                               map_object_marker__isActive : bool;
                               monster_gen__type : string;
                               transform : float3x4)
  if !map_object_marker__isActive
    log_action("hero visited encounter with {monster_gen__type} monsters", transform[3])

// anomalies

def get_anomaly_name(anomaly_eid : EntityId)
  if anomaly_eid |> has("frog_trap")
    return "frog anomaly"
  if anomaly_eid |> has("flower_trap")
    return "flowerman trap"
  if anomaly_eid |> has("teleport_trap")
    return "teleport anomaly"
  return "unknown anomaly"


[es(tag=gameClient, REQUIRE=hero)]
def log_action_anomly_triggered(evt : EventTrapTriggerNotify)
  log_action("hero stepped in {get_anomaly_name(evt.trapEid)}")


[es(tag=gameClient)]
def log_action_stone_throwed_in_anomaly(evt : EventTrapTriggerNotify;
                                        throwing_stone_owner : EntityId)
  if has(throwing_stone_owner, "hero")
    log_action("hero throwed stone in {get_anomaly_name(evt.trapEid)}")

// am

[es(tag=gameClient)]
def log_action_pickup_am(evt : EventChangeActiveMatterBalanceHint;
                         possessed : EntityId)
  query(possessed) <| $ [es(REQUIRE=hero)] (transform : float3x4)
    if evt.change > 0
      log_action("hero recieved {evt.change} AM", transform[3])
    else
      log_action("hero spent {abs(evt.change)} AM", transform[3])


// send to bq

[es(tag=gameClient)]
def send_log_action_to_bq(evt : EventPlayerFinishedRaid;
                          // userid : uint64;
                          player_actions_log : StringList;
                          is_local : bool)
  if !is_raid_mode()
    return

  if is_local
    // compress
    var compressedData : array<uint8>
    compress_data("gzip", compressedData) <| $(var bs : BitStream)
      for action in player_actions_log
        for c in string(action)
          bs |> Write(uint8(c))
        bs |> Write(uint8('\n'))
    df_open(FILENAME, DF_CREATE | DF_WRITE) <| $(outputFile)
      outputFile |> df_write(compressedData)


    // check
    // df_open(FILENAME, DF_READ) <| $(outputFile)
    //   let dataSize = df_length(outputFile)
    //   df_read(outputFile, dataSize) <| $(data)
    //     decompress_data(data) <| $(bs : BitStream)
    //       let str_len = int(GetNumberOfUnreadBits(bs)) / 8
    //       let decompressed_str = build_string() <| $(var writer)
    //         for _ in range(str_len)
    //           var c : uint8
    //           bs |> Read(c)
    //           write_char(writer, int(c))
    //       error("decompressedData: {decompressed_str}")

    // send
    // CHANGES TO THIS SCHEME SHOULD BE REFLECTED IN BQ TABLE (ask devops if you don't know what it means)
    // send_event_bq_with_header("player_action_log") <| $(var jw : JsonWriter)
    //   add_user_id(jw, userid)
    //   jw_key_value(jw, "session_id", get_session_id())
    //   jw_key_value(jw, "action_log", compressedData)
    // clear_old_log()
