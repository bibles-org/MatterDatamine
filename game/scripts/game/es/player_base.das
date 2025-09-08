require ecs
require ecs.safe
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
require DaWeaponProps


[es(tag=gameClient)]
def create_base_extraction_effect(evt : CmdStartMenuExtractionSequence;
                                  eid : EntityId;
                                  player_on_base_components__baseExtractionEffectTemplate : string)
  createEntity(player_on_base_components__baseExtractionEffectTemplate) <| $(init)
    set(init, "game_effect__attachedTo", eid)


[es(tag=gameClient, on_appear)]
def create_on_base_effect(evt : Event;
                          eid : EntityId;
                          player_on_base_components__onBaseDisableGameEffectTemplate : string;
                          var player_on_base_components__onBaseDisableGameEffect : EntityId&)
  player_on_base_components__onBaseDisableGameEffect = createEntity(player_on_base_components__onBaseDisableGameEffectTemplate) <| $(init)
    set(init, "game_effect__attachedTo", eid)


[es(tag=gameClient, on_disappear)]
def destroy_on_base_effect(evt : Event;
                           var player_on_base_components__onBaseDisableGameEffect : EntityId&)
  destroyEntity(player_on_base_components__onBaseDisableGameEffect)
  player_on_base_components__onBaseDisableGameEffect = INVALID_ENTITY_ID


[es(tag=gameClient, REQUIRE=hero, no_order)]
def show_shooting_forbid_message(act : UpdateStageInfoAct; isShootingAllowed : bool; isMeleeAllowed : bool; human_net_phys : HumanActor)
  if is_player_base()
    if !isShootingAllowed && is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
      create_status_tip("status_tip_no_base_shoot")
    elif !isMeleeAllowed && is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_MELEE)
      create_status_tip("status_tip_no_base_shoot")


[es(tag=server, REQUIRE=player_base)]
def player_base_on_recreate_possessed_request(evt : CmdRecreatePossessedRequest)
  query(evt.playerEid) <| $ [es] (possessed : EntityId;
                                  team : int)
    var tm : float3x4
    query(possessed) <| $ [es] (transform : float3x4)
      tm = transform

    destroyEntity(possessed)

    using() <| $(var params : Object)
      params |> set("transform", tm)
      params |> set("createEntityExtraTemplate", "recreated_possessed")
      params |> set("team", team)
      spawn_soldier(team, evt.playerEid, params)


def refill_item_holder(item_eid : EntityId; inventories : EntityId[3]; stash_eid : EntityId)
  // item_holder
  query(item_eid) <| $ [es] (var item__currentBoxedItemCount : int&;
                             item__containerOwnerEid : EntityId;
                             item_holder__maxItemCount : int;
                             item_holder__boxedItemTemplate : string)
    if item__currentBoxedItemCount < item_holder__maxItemCount
      if item__containerOwnerEid == stash_eid // in stash
        let boxEid = find_boxed_item_to_draw_from(item_holder__boxedItemTemplate, item__containerOwnerEid)
        if boxEid == INVALID_ENTITY_ID
          return
        let wishToDraw = item_holder__maxItemCount - item__currentBoxedItemCount
        var notDrownCount = wishToDraw
        var boxedId : string
        query(boxEid) <| $ [es] (uniqueId : string)
          boxedId = uniqueId
        draw_boxed_item_from(boxEid, item__currentBoxedItemCount, notDrownCount)
        report_item_ammo_loading_transaction(boxedId, item_eid, wishToDraw - notDrownCount)
        return
      for inventoryEid in inventories
        let boxEid = find_boxed_item_to_draw_from(item_holder__boxedItemTemplate, inventoryEid)
        if boxEid == INVALID_ENTITY_ID
          continue
        let wishToDraw = item_holder__maxItemCount - item__currentBoxedItemCount
        var notDrownCount = wishToDraw
        var boxedId : string
        query(boxEid) <| $ [es] (uniqueId : string)
          boxedId = uniqueId
        draw_boxed_item_from(boxEid, item__currentBoxedItemCount, notDrownCount)
        report_item_ammo_loading_transaction(boxedId, item_eid, wishToDraw - notDrownCount)
        if item__currentBoxedItemCount == item_holder__maxItemCount
          break


def refill_gun(item_eid : EntityId; hero_eid : EntityId; inventories : EntityId[3]; stash_eid : EntityId)
  // rifle gun
  query(item_eid) <| $ [es(REQUIRE=gun__boxedAmmoReload)] (var gun__ammo : int&;
                                                           var shell_props aka gun_shell_props : ShellPropIds&;
                                                           var gun__curShellId : ShellPropIds&;
                                                           gun__shell_prop_ids : GunShellPropIds;
                                                           gun__maxAmmo : int;
                                                           gun__boxedAmmoHolderTemplate : string;
                                                           slot_attach__weaponSlotIdx : int)
    if slot_attach__weaponSlotIdx == -1
      return
    if gun__ammo < gun__maxAmmo
      for inventoryEid in inventories
        let boxEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, inventoryEid)
        if boxEid == INVALID_ENTITY_ID
          continue
        var boxedId : string
        gun_shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
        query(boxEid) <| $ [es] (shell_props aka item_shell_props : ShellPropIds)
          gun_shell_props = item_shell_props
        query(boxEid) <| $ [es] (uniqueId : string)
          boxedId = uniqueId
        gun__curShellId = gun_shell_props

        let wishToDraw = gun__maxAmmo - gun__ammo
        var notDrownCount = wishToDraw
        draw_boxed_item_from(boxEid, gun__ammo, notDrownCount)
        report_item_ammo_loading_transaction(boxedId, item_eid, wishToDraw - notDrownCount)
        if gun__ammo == gun__maxAmmo
          break

  // gun with magazine
  query(item_eid) <| $ [es(REQUIRE=gun__magazineReload)] (@shared_comp gun_mods__slots : Object;
                                                          gun_mods__curModInSlots : Object;
                                                          var gun__ammo : int&;
                                                          gun__shell_prop_ids : GunShellPropIds;
                                                          var shell_props aka gun_shell_props : ShellPropIds&;
                                                          var gun__curShellId : ShellPropIds&;
                                                          uniqueId aka item_uniqueId : string;
                                                          gun__boxedAmmoHolderTemplate : string = "";
                                                          slot_attach__weaponSlotIdx : int)
    if slot_attach__weaponSlotIdx == -1
      return
    let hasMagazineSlot = get_gun_available_magazines(gun_mods__slots) <| $ [unused_argument(magazines)] (magazines) {}
    if !hasMagazineSlot
      return
    // fill one ammo
    if gun__boxedAmmoHolderTemplate != "" && gun__ammo < 1
      for inventoryEid in inventories
        let boxEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, inventoryEid)
        if boxEid == INVALID_ENTITY_ID
          continue
        var boxedId : string
        gun_shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
        query(boxEid) <| $ [es] (shell_props aka item_shell_props : ShellPropIds)
          gun_shell_props = item_shell_props
        query(boxEid) <| $ [es] (uniqueId : string)
          boxedId = uniqueId
        gun__curShellId = gun_shell_props

        var wishToDraw = 1
        draw_boxed_item_from(boxEid, gun__ammo, wishToDraw)
        report_item_ammo_loading_transaction(boxedId, item_eid, 1)
        break
    let magazineEid = get_Eid(gun_mods__curModInSlots["magazine"]) ?? INVALID_ENTITY_ID
    if magazineEid == INVALID_ENTITY_ID
      // then equip magazine
      get_gun_available_magazines(gun_mods__slots) <| $ [es] (magazines : StringList)
        var bestMagazineEid = INVALID_ENTITY_ID
        var bestAmmoCount = -1
        for inventoryEid in inventories
          let magazineForGun = find_magazine_for_gun(magazines, inventoryEid)
          query(magazineForGun) <| $ [es] (item__currentBoxedItemCount : int)
            if item__currentBoxedItemCount > bestAmmoCount
              bestMagazineEid = magazineForGun
              bestAmmoCount = item__currentBoxedItemCount
        if bestMagazineEid != INVALID_ENTITY_ID
          refill_item_holder(bestMagazineEid, inventories, stash_eid)
          equip_weapon_mod_to_slot(bestMagazineEid, "magazine", item_eid, hero_eid)
          report_item_move_transaction(bestMagazineEid, item_uniqueId, "magazine")
    else
      query(magazineEid) <| $ [es] (item_holder__maxItemCount : int)
        let maxAmmo = item_holder__maxItemCount + 1
        if gun__ammo < maxAmmo && gun__boxedAmmoHolderTemplate != ""
          for inventoryEid in inventories
            let boxEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, inventoryEid)
            if boxEid == INVALID_ENTITY_ID
              continue
            var boxedId : string
            query(boxEid) <| $ [es] (uniqueId : string)
              boxedId = uniqueId

            let wishToDraw = maxAmmo - gun__ammo
            var notDrownCount = wishToDraw
            draw_boxed_item_from(boxEid, gun__ammo, notDrownCount)
            report_item_ammo_loading_transaction(boxedId, magazineEid, wishToDraw - notDrownCount)
            if gun__ammo == maxAmmo
              break


[es(tag=server, REQUIRE=player_on_base_components__stashEid)]
def reload_and_top_up_all_items(evt : RequestFillAllItems;
                                eid : EntityId;
                                human_weap__gunEids : EidList;
                                militant_extra_inventories__backpackEid : EntityId = INVALID_ENTITY_ID;
                                player_on_base_components__stashEid : EntityId = INVALID_ENTITY_ID)
  // refill priority weapons, pouches, inventory, backpack
  let inventoriesToRefillOrder <- fixed_array<EntityId>(eid, militant_extra_inventories__backpackEid)
  // draw priority stash, backpack, inventory
  let inventoriesToDrawFromPriority <- fixed_array<EntityId>(player_on_base_components__stashEid, militant_extra_inventories__backpackEid, eid)

  for weaponEid in human_weap__gunEids
    refill_gun(weaponEid, eid, inventoriesToDrawFromPriority, player_on_base_components__stashEid)

  foreach_pocket_slot(eid) <| $ [unused_argument(equipment, modIdx)] (modIdx : int;
                                                                      equipment : tuple<slot : string; eid : EntityId>;
                                                                      mod : tuple<slot : string; eid : EntityId>)
    refill_item_holder(mod.eid, inventoriesToDrawFromPriority, player_on_base_components__stashEid)

  for inventoryEid in inventoriesToRefillOrder
    query(inventoryEid) <| $ [es] (var itemContainer : EidList)
      for itemEid in itemContainer
        refill_item_holder(itemEid, inventoriesToDrawFromPriority, player_on_base_components__stashEid)
