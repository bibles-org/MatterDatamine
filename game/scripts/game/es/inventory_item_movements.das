require ecs
require ecs.safe
require game.events.inventory_events
require math.base
require DngNet


[es(REQUIRE=item__id)]
def change_item_subtemplate_on_move_between_inventories(evt : EventOnMovingBetweenInventories;
                                                        eid : EntityId;
                                                        item__removeTemplatesInInventory : StringList const?;
                                                        item__recreateInInventory = "";
                                                        item__recreateOnGround = "";
                                                        item__recreateInWorldPhys = "")
  // was on ground
  if evt.oldInventoryEid == INVALID_ENTITY_ID && evt.newInventoryEid != INVALID_ENTITY_ID
    if !empty(item__recreateOnGround)
      eid |> removeSubTemplate(item__recreateOnGround)
    if !empty(item__recreateInWorldPhys)
      eid |> removeSubTemplate(item__recreateInWorldPhys)
    if item__removeTemplatesInInventory != null
      for templateName in *item__removeTemplatesInInventory
        eid |> removeSubTemplate(string(templateName))
    if !empty(item__recreateInInventory)
      eid |> addSubTemplate(item__recreateInInventory)
  // move on ground
  elif evt.newInventoryEid == INVALID_ENTITY_ID
    if !empty(item__recreateInInventory)
      eid |> removeSubTemplate(item__recreateInInventory)
    if !empty(item__recreateOnGround)
      eid |> addSubTemplate(item__recreateOnGround)


[es(REQUIRE=item__id)]
def change_item_subtemplates_on_drop_item(evt : EventOnDropItem;
                                          eid : EntityId;
                                          item__recreateInEquipment = "";
                                          item__recreateInEquipmentModSlot = "";
                                          item__recreateOnDelayedMove = "";
                                          item__recreateInGunModSlot = "";
                                          item__recreateInInventory = "";
                                          item__recreateOnGround = "";
                                          item__recreateInWorldPhys = "")
  if !empty(item__recreateInEquipment)
    eid |> removeSubTemplate(item__recreateInEquipment)
  if !empty(item__recreateInEquipmentModSlot)
    eid |> removeSubTemplate(item__recreateInEquipmentModSlot)
  if !empty(item__recreateOnDelayedMove)
    eid |> removeSubTemplate(item__recreateOnDelayedMove)
  if !empty(item__recreateInGunModSlot)
    eid |> removeSubTemplate(item__recreateInGunModSlot)

  if evt.newInventoryEid != INVALID_ENTITY_ID
    if !empty(item__recreateOnGround)
      eid |> removeSubTemplate(item__recreateOnGround)
    if !empty(item__recreateInWorldPhys)
      eid |> removeSubTemplate(item__recreateInWorldPhys)
    if !empty(item__recreateInInventory)
      eid |> addSubTemplate(item__recreateInInventory)
  else
    if !empty(item__recreateInInventory)
      eid |> removeSubTemplate(item__recreateInInventory)
    if !empty(item__recreateOnGround)
      eid |> addSubTemplate(item__recreateOnGround) <| $(var init)
        // transform is set from event, cause we need to set the very same transform on server and all of clients
        init |> set("transform", evt.transform)


[es(tag=server)]
def change_item_subtemplates_on_drop_item_phys(evt : EventOnDropItemPhys;
                                               eid : EntityId;
                                               item__recreateInEquipment = "";
                                               item__recreateInEquipmentModSlot = "";
                                               item__recreateOnDelayedMove = "";
                                               item__recreateInGunModSlot = "";
                                               item__recreateInInventory = "";
                                               item__recreateOnGround = "";
                                               item__recreateInWorldPhys : string)
  var templateName = add_sub_template_name(eid, item__recreateInWorldPhys)
  templateName = remove_sub_template_name(templateName, item__recreateInEquipment)
  templateName = remove_sub_template_name(templateName, item__recreateInEquipmentModSlot)
  templateName = remove_sub_template_name(templateName, item__recreateOnDelayedMove)
  templateName = remove_sub_template_name(templateName, item__recreateInGunModSlot)
  templateName = remove_sub_template_name(templateName, item__recreateInInventory)
  templateName = remove_sub_template_name(templateName, item__recreateOnGround)

  let initNetPhys <- @ <| (reid : EntityId;
                            var cInit : ComponentsInitializer)
    let net__physId = get_int(reid, "net__physId")
    if net__physId != null
      set(cInit, "net__physId", *net__physId) // transfer just created physobj's physId to remote systems
  remote_recreate_entity_from(eid, templateName, initNetPhys) <| $(var init : ComponentsInitializer)
    init |> set("transform", evt.transform)


[es(REQUIRE=item__id)]
def change_item_subtemplates_on_unequip_to_inventory(evt : EventOnUnequipingToInventory;
                                                     eid : EntityId;
                                                     item__recreateInEquipmentModSlot = "";
                                                     item__recreateInGunModSlot = "";
                                                     item__recreateOnDelayedMove = "";
                                                     item__recreateInEquipment = "";
                                                     item__recreateInInventory = "")
  if !empty(item__recreateInEquipmentModSlot)
    eid |> removeSubTemplate(item__recreateInEquipmentModSlot)
  if !empty(item__recreateOnDelayedMove)
    eid |> removeSubTemplate(item__recreateOnDelayedMove)
  if !empty(item__recreateInGunModSlot)
    eid |> removeSubTemplate(item__recreateInGunModSlot)
  if !empty(item__recreateInEquipment)
    eid |> removeSubTemplate(item__recreateInEquipment)

  if !empty(item__recreateInInventory)
    eid |> addSubTemplate(item__recreateInInventory)


[es(REQUIRE=item__id)]
def change_equipment_mod_subtemplates_on_equip(evt : EventOnEquipingAsEquipmentMod;
                                               eid : EntityId;
                                               item__recreateOnDelayedMove = "";
                                               item__recreateInEquipmentModSlot = "";
                                               item__recreateInInventory = "";
                                               item__recreateOnGround = "";
                                               item__recreateInWorldPhys = "")
  if !empty(item__recreateOnGround)
    eid |> removeSubTemplate(item__recreateOnGround)
  if !empty(item__recreateInWorldPhys)
    eid |> removeSubTemplate(item__recreateInWorldPhys)
  if !empty(item__recreateInInventory)
    eid |> removeSubTemplate(item__recreateInInventory)
  if !empty(item__recreateOnDelayedMove)
    eid |> removeSubTemplate(item__recreateOnDelayedMove)

  if !empty(item__recreateInEquipmentModSlot)
    eid |> addSubTemplate(item__recreateInEquipmentModSlot) <| $(var init)
      init |> set("slot_attach__attachedTo", evt.equipmentEid)


[es(REQUIRE=item__id)]
def change_weapon_mod_subtemplates_on_equip(evt : EventOnEquipingAsWeaponMod;
                                            eid : EntityId;
                                            item__recreateInGunModSlot = "";
                                            item__recreateInInventory = "";
                                            item__recreateOnGround = "";
                                            item__recreateInWorldPhys = "")
  if !empty(item__recreateOnGround)
    eid |> removeSubTemplate(item__recreateOnGround)
  if !empty(item__recreateInWorldPhys)
    eid |> removeSubTemplate(item__recreateInWorldPhys)
  if !empty(item__recreateInInventory)
    eid |> removeSubTemplate(item__recreateInInventory)

  if !empty(item__recreateInGunModSlot)
    eid |> addSubTemplate(item__recreateInGunModSlot) <| $(var init)
      init |> set("slot_attach__attachedTo", evt.weaponEid)


[es(REQUIRE=item__id)]
def change_mod_subtemplates_on_delayed_move_start(evt : EventOnStartDelayedModMove;
                                                  eid : EntityId;
                                                  item__recreateOnDelayedMove = "")
  if !empty(item__recreateOnDelayedMove)
    eid |> addSubTemplate(item__recreateOnDelayedMove) <| $(var init)
      init |> set("weapon_mod_move__weaponEid", evt.modParentEid)
      init |> set("weapon_mod_move__inventoryEid", evt.inventoryEid)


[es(REQUIRE=item__id)]
def change_mod_subtemplates_on_delayed_move_end(evt : EventOnEndDelayedModMove;
                                                eid : EntityId;
                                                item__recreateOnDelayedMove = "")
  if !empty(item__recreateOnDelayedMove)
    eid |> removeSubTemplate(item__recreateOnDelayedMove)


[es(REQUIRE=item__id)]
def change_equipment_subtemplates_on_equip(evt : EventOnEquipingAsEquipment;
                                           eid : EntityId;
                                           item__recreateInInventory = "";
                                           item__recreateInEquipment = "";
                                           item__recreateOnGround = "";
                                           item__recreateInWorldPhys = "")
  if !empty(item__recreateOnGround)
    eid |> removeSubTemplate(item__recreateOnGround)
  if !empty(item__recreateInWorldPhys)
    eid |> removeSubTemplate(item__recreateInWorldPhys)
  if !empty(item__recreateInInventory)
    eid |> removeSubTemplate(item__recreateInInventory)

  if !empty(item__recreateInEquipment)
    eid |> addSubTemplate(item__recreateInEquipment) <| $(var init)
      init |> set("slot_attach__attachedTo", evt.heroEid)


[es(REQUIRE=item__id)]
def change_weapon_subtemplates_on_equip(evt : EventOnEquipingAsWeapon;
                                        eid : EntityId;
                                        gun_attach__mainSlotId : int;
                                        gun_attach__holsterSlotsIds : IntList;
                                        item__recreateInInventory = "";
                                        item__recreateInEquipment = "";
                                        item__recreateOnGround = "";
                                        item__recreateInWorldPhys = "")
  if !empty(item__recreateOnGround)
    eid |> removeSubTemplate(item__recreateOnGround)
  if !empty(item__recreateInWorldPhys)
    eid |> removeSubTemplate(item__recreateInWorldPhys)
  if !empty(item__recreateInInventory)
    eid |> removeSubTemplate(item__recreateInInventory)

  if !empty(item__recreateInEquipment)
    eid |> addSubTemplate(item__recreateInEquipment) <| $(var init)
      init |> set("gun__owner", evt.heroEid)
      init |> set("slot_attach__attachedTo", evt.heroEid)
      var isCurrentSlot = false
      query(evt.heroEid) <| $ [es] (human_weap__curGunSlot : int;
                                    attachable_suit_controller__holsterAttachedAnimchars : StringList;
                                    attachable_suit_controller__attachedAnimcharEids : Object)
        isCurrentSlot = human_weap__curGunSlot == evt.slotId

        // TODO: Move to common function (use in human_gun_attach_es)
        // Holster slot on the suit animchar
        if evt.slotId >= length(attachable_suit_controller__holsterAttachedAnimchars)
          return

        assume holsterAnimcharName = attachable_suit_controller__holsterAttachedAnimchars[evt.slotId]
        if holsterAnimcharName == ""
          return

        let attachedAnimcharEid = attachable_suit_controller__attachedAnimcharEids[string(holsterAnimcharName)] ?? INVALID_ENTITY_ID
        if attachedAnimcharEid != INVALID_ENTITY_ID
          init |> set("slot_attach__attachedTo", attachedAnimcharEid)

      if evt.slotId >= 0 && evt.slotId < length(gun_attach__holsterSlotsIds)
        init |> set("slot_attach__slotId", isCurrentSlot ? gun_attach__mainSlotId : gun_attach__holsterSlotsIds[evt.slotId])
