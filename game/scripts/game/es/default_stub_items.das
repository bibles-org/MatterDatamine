require ecs
require ecs.safe
require HumanPhys
require game.es.inventory_weapon_common
require game.es.inventory_equipment_common
require game.events.events_active_matter
require game.events.inventory_events
require game.es.ecs_common
require DagorSystem


[es(tag=server, on_appear, REQUIRE=default_stub_item)]
def default_stub_item_init(evt : Event;
                           eid aka item_eid : EntityId;
                           item__humanOwnerEid : EntityId)
  sendEventImmediate(item__humanOwnerEid, EventHumanDefaultStubItemCreated(itemEid = item_eid))


// Melee
def update_default_stub_melee_controller_melee_item(actor_eid : EntityId;
                                                    human_weap__gunEids : EidList;
                                                    default_stub_melee_controller__meleeTemplate : string;
                                                    var default_stub_melee_controller__meleeItemEid : EntityId&)
  if default_stub_melee_controller__meleeItemEid != INVALID_ENTITY_ID
    let meleeSlot = human_weap__gunEids[int(HUWeaponSlots.EWS_MELEE)]
    if meleeSlot == default_stub_melee_controller__meleeItemEid
      unequip_weapon_from_slot(int(HUWeaponSlots.EWS_MELEE), actor_eid)
    destroyEntity(default_stub_melee_controller__meleeItemEid)

  if default_stub_melee_controller__meleeTemplate != ""
    var meleeItemTemplate = getTemplateByName(default_stub_melee_controller__meleeTemplate)
    if meleeItemTemplate == null
      meleeItemTemplate = buildTemplateByName(default_stub_melee_controller__meleeTemplate)

    if meleeItemTemplate == null
      logerr("[INVENTORY] Default stub melee template <{default_stub_melee_controller__meleeTemplate}> not found for {get_entity_info(actor_eid)}")
      return

    if getTemplateComponent(*meleeItemTemplate, "default_stub_item") == null
      logerr("[INVENTORY] Invalid stub equipment template <{meleeItemTemplate}> for {get_entity_info(actor_eid)} - there is no default_stub_item tag!")
      return

    let recreateInInventory = getTemplateComponent(*meleeItemTemplate, "item__recreateInInventory") ?? ""
    var itemTemplateName = default_stub_melee_controller__meleeTemplate
    if recreateInInventory != ""
      itemTemplateName = add_sub_template_name(itemTemplateName, recreateInInventory)
    default_stub_melee_controller__meleeItemEid = createEntity(itemTemplateName) <| $(var init : ComponentsInitializer)
      init |> set("item__humanOwnerEid", actor_eid)
    print("[INVENTORY] Default stub melee <{default_stub_melee_controller__meleeItemEid}> ({itemTemplateName}) created for {get_entity_info(actor_eid)}")


def update_default_stub_melee_controller_melee_slot(actor_eid : EntityId;
                                                    human_weap__gunEids : EidList;
                                                    default_stub_melee_controller__meleeItemEid : EntityId)
  let meleeSlot = human_weap__gunEids[int(HUWeaponSlots.EWS_MELEE)]
  if meleeSlot == INVALID_ENTITY_ID && default_stub_melee_controller__meleeItemEid != INVALID_ENTITY_ID
    equip_weapon_to_slot(default_stub_melee_controller__meleeItemEid, int(HUWeaponSlots.EWS_MELEE),
                         actor_eid)


[es(tag=server, on_disappear, REQUIRE=initial_loadout_creation, REQUIRE_NOT=deadEntity)]
def default_stub_melee_controller_on_initial_loadout_created(evt : Event;
                                                             eid aka actor_eid : EntityId;
                                                             human_weap__gunEids : EidList;
                                                             default_stub_melee_controller__meleeTemplate : string;
                                                             var default_stub_melee_controller__meleeItemEid : EntityId&)
  update_default_stub_melee_controller_melee_item(actor_eid, human_weap__gunEids,
                                                  default_stub_melee_controller__meleeTemplate,
                                                  default_stub_melee_controller__meleeItemEid)


[es(tag=server, on_appear, REQUIRE=update_default_stub_melee_on_appear, REQUIRE_NOT=deadEntity)]
def default_stub_melee_controller_force_update_on_appear(evt : Event;
                                                         eid aka actor_eid : EntityId;
                                                         human_weap__gunEids : EidList;
                                                         default_stub_melee_controller__meleeTemplate : string;
                                                         var default_stub_melee_controller__meleeItemEid : EntityId&)
  update_default_stub_melee_controller_melee_item(actor_eid, human_weap__gunEids,
                                                  default_stub_melee_controller__meleeTemplate,
                                                  default_stub_melee_controller__meleeItemEid)


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def default_stub_melee_controller_on_entity_died(evt : Event;
                                                 human_weap__gunEids : EidList;
                                                 var default_stub_melee_controller__meleeItemEid : EntityId&)
  let meleeSlot = human_weap__gunEids[int(HUWeaponSlots.EWS_MELEE)]
  if default_stub_melee_controller__meleeItemEid == meleeSlot && default_stub_melee_controller__meleeItemEid != INVALID_ENTITY_ID
    destroyEntity(default_stub_melee_controller__meleeItemEid)
    default_stub_melee_controller__meleeItemEid = INVALID_ENTITY_ID


[es(tag=server, REQUIRE_NOT=deadEntity)]
def default_stub_melee_controller_on_melee_item_created(evt : EventHumanDefaultStubItemCreated;
                                                        eid aka actor_eid : EntityId;
                                                        human_weap__gunEids : EidList;
                                                        default_stub_melee_controller__meleeItemEid : EntityId)
  if evt.itemEid == default_stub_melee_controller__meleeItemEid
    update_default_stub_melee_controller_melee_slot(actor_eid, human_weap__gunEids,
                                                    default_stub_melee_controller__meleeItemEid)


[es(tag=server, REQUIRE_NOT=deadEntity)]
def default_stub_melee_controller_track_guns(evt : EventOnWeaponChanged;
                                             eid aka actor_eid : EntityId;
                                             default_stub_melee_controller__meleeItemEid : EntityId)
  if (evt.slotId == int(HUWeaponSlots.EWS_MELEE) &&
      evt.newWeaponEid == INVALID_ENTITY_ID &&
      evt.oldWeaponEid != default_stub_melee_controller__meleeItemEid &&
      default_stub_melee_controller__meleeItemEid != INVALID_ENTITY_ID)
    equip_weapon_to_slot(default_stub_melee_controller__meleeItemEid, int(HUWeaponSlots.EWS_MELEE), actor_eid)


[es(tag=server)]
def equipment_with_default_stub_melee_equipped(evt : EquipmentApplyEffects;
                                               equipment__setDefaultStubMeleeTemplate : string)
  query(evt.actorEid) <| $ [es] (human_weap__gunEids : EidList;
                                 var default_stub_melee_controller__meleeTemplate : das_string;
                                 var default_stub_melee_controller__meleeItemEid : EntityId&)
    if default_stub_melee_controller__meleeTemplate == equipment__setDefaultStubMeleeTemplate
      return

    default_stub_melee_controller__meleeTemplate := equipment__setDefaultStubMeleeTemplate
    update_default_stub_melee_controller_melee_item(evt.actorEid, human_weap__gunEids,
                                                    equipment__setDefaultStubMeleeTemplate,
                                                    default_stub_melee_controller__meleeItemEid)


// Equipment
def update_default_stub_equipment_controller_equipment_item(actor_eid : EntityId;
                                                            human_equipment__slots : Object;
                                                            slot_name : string;
                                                            default_stub_equipment_controller__equipmentTemplates : Object;
                                                            var default_stub_equipment_controller__equipmentItemEids : Object)
  let equipmentSlot = human_equipment__slots |> get_Eid(slot_name)
  if equipmentSlot == null
    return
  let equipmentItemEid = equipmentSlot ?? INVALID_ENTITY_ID

  let equipmentStubItemTemplate = default_stub_equipment_controller__equipmentTemplates |> get_string(slot_name, "")

  default_stub_equipment_controller__equipmentItemEids |> ensure_eid(slot_name, INVALID_ENTITY_ID) <| $(var equipment_stub_item_eid : EntityId&)

    if equipment_stub_item_eid != INVALID_ENTITY_ID
      if equipmentItemEid == equipment_stub_item_eid
        unequip_equipment_from_slot(slot_name, actor_eid)
      destroyEntity(equipment_stub_item_eid)

    if equipmentStubItemTemplate != ""
      var equipmentItemTemplate = getTemplateByName(equipmentStubItemTemplate)
      if equipmentItemTemplate == null
        equipmentItemTemplate = buildTemplateByName(equipmentStubItemTemplate)

      if equipmentItemTemplate == null
        logerr("[INVENTORY] Default stub equipment template <{equipmentItemTemplate}> not found for {get_entity_info(actor_eid)}")
        return

      if getTemplateComponent(*equipmentItemTemplate, "default_stub_item") == null
        logerr("[INVENTORY] Invalid stub equipment template <{equipmentItemTemplate}> for {get_entity_info(actor_eid)} - there is no default_stub_item tag!")
        return

      let recreateInInventory = getTemplateComponent(*equipmentItemTemplate, "item__recreateInInventory") ?? ""
      var itemTemplateName := equipmentStubItemTemplate
      if recreateInInventory != ""
        itemTemplateName = add_sub_template_name(itemTemplateName, recreateInInventory)
      equipment_stub_item_eid = createEntity(itemTemplateName) <| $(var init : ComponentsInitializer)
        init |> set("item__humanOwnerEid", actor_eid)
      print("[INVENTORY] Default stub equipment <{equipment_stub_item_eid}> ({itemTemplateName}) created for {get_entity_info(actor_eid)}")


def update_default_stub_equipment_controller_equipment_slot(actor_eid : EntityId;
                                                            human_equipment__slots : Object;
                                                            slot_name : string;
                                                            default_stub_equipment_controller__equipmentItemEids : Object)
  let equipmentSlot = human_equipment__slots |> get_Eid(slot_name)
  if equipmentSlot == null
    return
  let equipmentItemEid = equipmentSlot ?? INVALID_ENTITY_ID


  let equipmentStubItemEid = default_stub_equipment_controller__equipmentItemEids |> get_Eid(slot_name) ?? INVALID_ENTITY_ID

  if equipmentItemEid == INVALID_ENTITY_ID && equipmentStubItemEid != INVALID_ENTITY_ID
    equip_equipment_to_slot(equipmentStubItemEid, slot_name, actor_eid)


[es(tag=server, on_disappear, REQUIRE=initial_loadout_creation, REQUIRE_NOT=deadEntity)]
def default_stub_equipment_controller_on_initial_loadout_created(evt : Event;
                                                                 eid aka actor_eid : EntityId;
                                                                 human_equipment__slots : Object;
                                                                 default_stub_equipment_controller__equipmentTemplates : Object;
                                                                 var default_stub_equipment_controller__equipmentItemEids : Object)
  for slotData in human_equipment__slots
    update_default_stub_equipment_controller_equipment_item(actor_eid, human_equipment__slots,
                                                            slotData.key,
                                                            default_stub_equipment_controller__equipmentTemplates,
                                                            default_stub_equipment_controller__equipmentItemEids)


[es(tag=server, on_appear, REQUIRE=update_default_stub_melee_on_appear, REQUIRE_NOT=deadEntity)]
def default_stub_equipment_controller_force_update_on_appear(evt : Event;
                                                             eid aka actor_eid : EntityId;
                                                             human_equipment__slots : Object;
                                                             default_stub_equipment_controller__equipmentTemplates : Object;
                                                             var default_stub_equipment_controller__equipmentItemEids : Object)
  for slotData in human_equipment__slots
    update_default_stub_equipment_controller_equipment_item(actor_eid, human_equipment__slots,
                                                            slotData.key,
                                                            default_stub_equipment_controller__equipmentTemplates,
                                                            default_stub_equipment_controller__equipmentItemEids)


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def default_stub_equipment_controller_on_entity_died(evt : Event;
                                                     human_equipment__slots : Object;
                                                     var default_stub_equipment_controller__equipmentItemEids : Object)
  for slotData in human_equipment__slots

    let equipmentItemEid = slotData.value ?? INVALID_ENTITY_ID
    var equipmentStubItemEid = default_stub_equipment_controller__equipmentItemEids |> getRW_Eid(slotData.key)

    if equipmentStubItemEid != null && *equipmentStubItemEid == equipmentItemEid && *equipmentStubItemEid != INVALID_ENTITY_ID
      destroyEntity(*equipmentStubItemEid)
      *equipmentStubItemEid = INVALID_ENTITY_ID


[es(tag=server, REQUIRE_NOT=deadEntity)]
def default_stub_equipment_controller_on_equipment_item_created(evt : EventHumanDefaultStubItemCreated;
                                                                eid aka actor_eid : EntityId;
                                                                human_equipment__slots : Object;
                                                                default_stub_equipment_controller__equipmentItemEids : Object)
  for equipmentStubItemData in default_stub_equipment_controller__equipmentItemEids
    if evt.itemEid == equipmentStubItemData.value ?? INVALID_ENTITY_ID
      update_default_stub_equipment_controller_equipment_slot(actor_eid, human_equipment__slots,
                                                              equipmentStubItemData.key,
                                                              default_stub_equipment_controller__equipmentItemEids)
      break


[es(tag=server, REQUIRE_NOT=deadEntity)]
def default_stub_equipment_controller_track_equipment(evt : EventOnEquipmentChanged;
                                                      eid aka actor_eid : EntityId;
                                                      default_stub_equipment_controller__equipmentItemEids : Object)
  let equipmentStubItemEid = default_stub_equipment_controller__equipmentItemEids |> get_Eid(evt.slotName) ?? INVALID_ENTITY_ID
  if equipmentStubItemEid == INVALID_ENTITY_ID
    return

  if (evt.newEquipmentEid == INVALID_ENTITY_ID &&
      evt.oldEquipmentEid != equipmentStubItemEid)
    equip_equipment_to_slot(equipmentStubItemEid, evt.slotName, actor_eid)


[es(tag=server)]
def equipment_with_default_stub_equipment_equipped(evt : EquipmentApplyEffects;
                                                   equipment__setDefaultStubEquipmentTemplates : Object)
  query(evt.actorEid) <| $ [es] (human_equipment__slots : Object;
                                 var default_stub_equipment_controller__equipmentTemplates : Object;
                                 var default_stub_equipment_controller__equipmentItemEids : Object)
    for defaultStubEquipmentTemplate in equipment__setDefaultStubEquipmentTemplates
      let slotName = defaultStubEquipmentTemplate.key

      default_stub_equipment_controller__equipmentTemplates |> ensure_string(slotName, "") <| $(var equipment_stub_item_template : das_string&)

        let newDefaultStubEquipmentTemplate = defaultStubEquipmentTemplate.value ?? ""
        if equipment_stub_item_template == newDefaultStubEquipmentTemplate
          return

        equipment_stub_item_template := newDefaultStubEquipmentTemplate
        update_default_stub_equipment_controller_equipment_item(evt.actorEid, human_equipment__slots,
                                                                slotName,
                                                                default_stub_equipment_controller__equipmentTemplates,
                                                                default_stub_equipment_controller__equipmentItemEids)


[es(tag=server)]
def equipment_with_default_stub_equipment_unequipped(evt : EquipmentRevertEffects;
                                                     equipment__setDefaultStubEquipmentTemplates : Object)
  query(evt.actorEid) <| $ [es] (human_equipment__slots : Object;
                                 var default_stub_equipment_controller__equipmentTemplates : Object;
                                 var default_stub_equipment_controller__equipmentItemEids : Object)
    for defaultStubEquipmentTemplate in equipment__setDefaultStubEquipmentTemplates
      let slotName = defaultStubEquipmentTemplate.key

      default_stub_equipment_controller__equipmentTemplates |> ensure_string(slotName, "") <| $(var equipment_stub_item_template : das_string&)

        let oldDefaultStubEquipmentTemplate = defaultStubEquipmentTemplate.value ?? ""
        if equipment_stub_item_template != oldDefaultStubEquipmentTemplate
          return

        equipment_stub_item_template := ""
        update_default_stub_equipment_controller_equipment_item(evt.actorEid, human_equipment__slots,
                                                                slotName,
                                                                default_stub_equipment_controller__equipmentTemplates,
                                                                default_stub_equipment_controller__equipmentItemEids)