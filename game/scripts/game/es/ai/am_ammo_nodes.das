options always_export_initializer = true

require app
require ecs
require net
require ecs.common
require strings
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require game.events.events_active_matter
require game.es.boxed_ammo_reload_common
require game.es.inventory_weapon_mod_common
require game.events.events_game
require game.es.boxed_item_common
require game.es.human.human_reload_common
require debug.logerr_once


def find_any_magazine_that_can_be_loaded(inventories : EidList) : EntityId
  var wantHoders : array<tuple<eid : EntityId; templ : string>>
  var haveHoders : array<string>
  var res = INVALID_ENTITY_ID
  for inventory in inventories
    query(inventory) <| $ [es] (itemContainer : EidList)
      for item in itemContainer
        query(item) <| $ [es] (boxed_item__template : das_string const?;
                               item__currentBoxedItemCount : int;
                               item_holder__maxItemCount : int = 0;
                               item_holder__boxedItemTemplate : das_string const?)
          if item_holder__boxedItemTemplate != null && item__currentBoxedItemCount < item_holder__maxItemCount
            wantHoders |> push((item, string(*item_holder__boxedItemTemplate)))
          elif boxed_item__template != null && !has_value(haveHoders, string(*boxed_item__template))
            haveHoders |> push(string(*boxed_item__template))
      if length(wantHoders) > 0 && length(haveHoders) > 0
        for h1 in haveHoders
          for h2 in wantHoders
            if h2.templ == h1
              res = h2.eid
              return
  return res


[beh_node(name="hasMagazinesToLoad")]
class HasMagazinesToLoad : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (inventories_owner__inventoryEids : EidList)
      if find_any_magazine_that_can_be_loaded(inventories_owner__inventoryEids) != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="loadMagazine")]
class LoadMagazine : BehNodeAdapter //Either RUNNING or FAILED
  lastAttemptTime : float = -1.0
  attemptCooldown = 2.0

  def override update(dt : float) : EBehResult
    if get_sync_time() - lastAttemptTime < attemptCooldown
      return EBehResult.ER_RUNNING
    lastAttemptTime = get_sync_time()

    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (inventories_owner__inventoryEids : EidList;
                          human_inventory__entityToUse : EntityId;
                          human_weap__currentGunEid : EntityId)
      var isUsingWrongItem = false
      query(human_inventory__entityToUse) <| $ [es(REQUIRE_NOT=ammo_holder__templateName)] ()
        isUsingWrongItem = true
      if isUsingWrongItem
        return
      elif human_inventory__entityToUse != INVALID_ENTITY_ID
        res = EBehResult.ER_RUNNING
        return

      var installingMod = false
      query(human_weap__currentGunEid) <| $ [es] (weapon_mods__delayedMoveState : int)
        installingMod = weapon_mods__delayedMoveState > int(ModDelayedMoveState.WAIT)
      if installingMod
        return

      let magazineAndAmmoToLoad = find_any_magazine_that_can_be_loaded(inventories_owner__inventoryEids)
      if magazineAndAmmoToLoad != INVALID_ENTITY_ID
        send_net_event(eid, RequestLoadItemHolder(targetItemEid = magazineAndAmmoToLoad, containerEid = eid, searchOtherContainers = true))
        res = EBehResult.ER_RUNNING
      else
        res = EBehResult.ER_FAILED
    return res


[beh_node(name="reloadGun")]
class ReloadGun : BehNodeAdapter
  ammoEidParam : int

  def override loadFromBlk(var data : DataBlock) : void
    ammoEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "ammoEid"), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var ammoEid = EntityId(uint(owner.blackBoard |> datablock_getInt(ammoEidParam)))
    let eid = beh_tree_eid(owner)

    query(eid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun__magazineReload)] (weapon_mods__delayedMoveState : int)
        if weapon_mods__delayedMoveState == int(ModDelayedMoveState.NONE) && ammoEid != INVALID_ENTITY_ID
          // start reloading
          query(ammoEid) <| $ [es] (item__containerOwnerEid : EntityId)
            start_equip_weapon_mod_to_slot(ammoEid, "magazine", human_weap__currentGunEid, eid, item__containerOwnerEid)
          ammoEid = INVALID_ENTITY_ID
          owner.blackBoard |> set(ammoEidParam, int(uint(INVALID_ENTITY_ID)))
          res = EBehResult.ER_RUNNING
        elif weapon_mods__delayedMoveState != int(ModDelayedMoveState.NONE)
          // reloading in progress
          res = EBehResult.ER_RUNNING
        else
          // reload is finished
          res = EBehResult.ER_SUCCESS
      query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun__boxedAmmoReload)] (gun_boxed_ammo_reload__reloadState : int)
        if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.NONE) && ammoEid != INVALID_ENTITY_ID
          // start reloading
          start_load_boxed_ammo_to_gun(ammoEid, human_weap__currentGunEid, eid)
          res = EBehResult.ER_RUNNING
          ammoEid = INVALID_ENTITY_ID
          owner.blackBoard |> set(ammoEidParam, int(uint(INVALID_ENTITY_ID)))
        elif gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
          // reloading in progress
          res = EBehResult.ER_RUNNING
        else
          // reload is finished
          res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="hasAmmoInGun")]
class hasAmmoInGun : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (gun__ammo : int)
        if gun__ammo > 0
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findAmmoForGun")]
class FindAmmoForGun : BehNodeAdapter
  ammoEidParam : int

  def override loadFromBlk(var data : DataBlock) : void
    ammoEidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "ammoEid"), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var ammoEid = INVALID_ENTITY_ID

    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (human_weap__currentGunEid : EntityId; inventories_owner__inventoryEids : EidList)
      // gun with boxed ammo
      query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun__boxedAmmoReload)] (gun__ammoHolders : StringList;
                                                                                gun__ammo : int;
                                                                                gun__maxAmmo : int)
        let hasPlaceForAmmo = gun__ammo < gun__maxAmmo
        if !hasPlaceForAmmo
          return
        var maxCount = 0
        for inventory in inventories_owner__inventoryEids
          query(inventory) <| $ [es] (itemContainer : EidList)
            let ammoInInventory = find_boxed_item_to_draw_from(gun__ammoHolders, itemContainer)
            query(ammoInInventory) <| $ [es] (item__currentBoxedItemCount : int)
              if item__currentBoxedItemCount > maxCount
                maxCount = item__currentBoxedItemCount
                ammoEid = ammoInInventory
                res = EBehResult.ER_SUCCESS

      if res == EBehResult.ER_SUCCESS
        return

      // gun with magazines
      query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun__magazineReload)] (@shared_comp gun_mods__slots : Object;
                                                                               gun__ammo : int)
        var curMagazineAmmo = max(gun__ammo - 1, 0) // bullet in barred doesn't count
        get_gun_available_magazines(gun_mods__slots) <| $ [es] (magazines : StringList)
          for inventory in inventories_owner__inventoryEids
            query(inventory) <| $ [es] (itemContainer : EidList)
              let bestMagazineForGun = find_magazine_for_gun(magazines, itemContainer)
              query(bestMagazineForGun) <| $ [es] (item__currentBoxedItemCount : int)
                if item__currentBoxedItemCount > curMagazineAmmo
                  curMagazineAmmo = item__currentBoxedItemCount
                  ammoEid = bestMagazineForGun
                  res = EBehResult.ER_SUCCESS

    owner.blackBoard |> set(ammoEidParam, int(uint(ammoEid)))
    return res


[beh_node(name="isInstallingWeaponMod")]
class IsInstallingWeaponMod : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(eid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (weapon_mods__delayedMoveState : int)
        if weapon_mods__delayedMoveState > int(ModDelayedMoveState.WAIT)
          res = EBehResult.ER_SUCCESS
    return res