require ecs
require DagorSystem
require net
require app
require game.events.inventory_events
require game.es.ecs_common
require game.es.equipment_enums_common
require game.es.inventory_equipment_common


def send_equipment_apply_effects(actor_eid : EntityId;
                                 equipment_eid : EntityId)
  if is_entity_archetype_exists(equipment_eid) && is_entity_archetype_exists(actor_eid)
    sendEvent(equipment_eid, EquipmentApplyEffects(actorEid = actor_eid))
  else
    createEntity("equipment_effects_postponed") <| $(var init : ComponentsInitializer)
      init |> set("equipment_effects_postponed__actorEid", actor_eid)
      init |> set("equipment_effects_postponed__equipmentEid", equipment_eid)
      init |> set("equipment_effects_postponed__apply", true)


def send_equipment_revert_effects(actor_eid : EntityId;
                                  equipment_eid : EntityId)
  if is_entity_archetype_exists(equipment_eid) && is_entity_archetype_exists(actor_eid)
    sendEvent(equipment_eid, EquipmentRevertEffects(actorEid = actor_eid))
  else
    createEntity("equipment_effects_postponed") <| $(var init : ComponentsInitializer)
      init |> set("equipment_effects_postponed__actorEid", actor_eid)
      init |> set("equipment_effects_postponed__equipmentEid", equipment_eid)
      init |> set("equipment_effects_postponed__apply", false)


[es]
def equipment_apply_effects_on_equip(evt : EventOnEquipmentEquipped;
                                     eid aka actor_eid : EntityId)
  send_equipment_apply_effects(actor_eid, evt.equipmentEid)


[es(on_appear)]
def equipment_apply_effects_on_appear(evt : Event;
                                      eid aka item_eid : EntityId;
                                      equipable_item__curSlot : string;
                                      item__humanOwnerEid : EntityId)
  if item__humanOwnerEid != INVALID_ENTITY_ID && !empty(equipable_item__curSlot)
    send_equipment_apply_effects(item__humanOwnerEid, item_eid)


[es]
def equipment_revert_effects_on_unequip(evt : EventOnEquipmentUnequipped;
                                        eid aka actor_eid : EntityId)
  sendEvent(evt.equipmentEid, EquipmentRevertEffects(actorEid = actor_eid))
  send_equipment_revert_effects(actor_eid, evt.equipmentEid)


[es(on_disappear)]
def equipment_revert_effects_on_disappear(evt : Event;
                                          eid aka item_eid : EntityId;
                                          equipable_item__curSlot : string;
                                          item__humanOwnerEid : EntityId)
  if item__humanOwnerEid != INVALID_ENTITY_ID && !empty(equipable_item__curSlot)
    send_equipment_revert_effects(item__humanOwnerEid, item_eid)


// equipment_effect__addSubTemplate
[es]
def equipment_effect_append_template_on_equip(evt : EquipmentApplyEffects; equipment_effect__addSubTemplate : string)
  addSubTemplate(evt.actorEid, equipment_effect__addSubTemplate)

[es]
def equipment_effect_remove_template_on_unequip(evt : EquipmentRevertEffects; equipment_effect__addSubTemplate : string)
  removeSubTemplate(evt.actorEid, equipment_effect__addSubTemplate)


// equipment_effect__transferAmOnEquip
[es(tag=server, REQUIRE=equipment_effect__transferAmOnEquip)]
def equipment_effect_transfer_am_on_equip(evt : EquipmentApplyEffects; var am_storage__value aka item_am_storage__value : int&)
  query(evt.actorEid) <| $ [es] (var am_storage__value aka hero_am_storage__value : int&; am_storage__maxValue : int)
    let transferDelta = min(item_am_storage__value, am_storage__maxValue - hero_am_storage__value)
    hero_am_storage__value += transferDelta
    item_am_storage__value -= transferDelta


// equipment_effect__addAbilitiesFromTemplate
[es(tag=server)]
def equipment_effect_add_ability_on_equip(evt : EquipmentApplyEffects; equipment_effect__addAbilitiesFromTemplate : string)
  add_abilities_from_template(evt.actorEid, equipment_effect__addAbilitiesFromTemplate)


[es(tag=server)]
def equipment_effect_remove_ability_on_unequip(evt : EquipmentRevertEffects; equipment_effect__addAbilitiesFromTemplate : string)
  remove_abilities_from_template(evt.actorEid, equipment_effect__addAbilitiesFromTemplate)



def private for_each_ability_in_tempate(template_name : string; debug_hero_eid : EntityId; exec : block<(ability_name : string; ability_obj : Object) : void>)
  var templ = getTemplateByName(template_name)
  if templ == null
    templ = buildTemplateByName(template_name)
  if templ == null
    logerr("Can't iterate over abilities in template '{template_name}' to <{debug_hero_eid}>({getEntityTemplateName(debug_hero_eid)}). No such template.")
    return
  let abilityArray = get_ecs_array(getTemplateComponent(*templ, "hero_ability__abilities"))
  for item in *abilityArray
    let itemObj = get_ecs_object(item)
    let abilityName = get_string(itemObj, "name", "")
    invoke(exec, abilityName, *itemObj)


def private add_abilities_from_template(hero_eid : EntityId; template_name : string)
  query(hero_eid) <| $ [es] (var hero_ability__abilities : Array)
    for_each_ability_in_tempate(template_name, hero_eid) <| $(ability_name : string; ability_obj : Object)
      var alreadyExists = false
      for heroAbility in hero_ability__abilities
        let heroAbilityObj = get_ecs_object(heroAbility)
        let heroAbilityName = get_string(heroAbilityObj, "name", "")
        if heroAbilityName == ability_name
          alreadyExists = true
          break
      if !alreadyExists
        hero_ability__abilities |> push(ability_obj)
        print("Added ability {ability_name} to <{hero_eid}>({getEntityTemplateName(hero_eid)})")


def private remove_abilities_from_template(hero_eid : EntityId; template_name : string)
  query(hero_eid) <| $ [es] (var hero_ability__abilities : Array)
    for_each_ability_in_tempate(template_name, hero_eid) <| $ [unused_argument(ability_obj)] (ability_name : string; ability_obj : Object)
      var iter = length(hero_ability__abilities)
      while iter-- > 0
        let heroAbilityObj = get_ecs_object(hero_ability__abilities[iter])
        let heroAbilityName = get_string(heroAbilityObj, "name", "")
        if heroAbilityName == ability_name
          print("Removed ability {ability_name} from <{hero_eid}>({getEntityTemplateName(hero_eid)})")
          erase(hero_ability__abilities, iter)
          break


// equipment_effect__blockEquipmentSlots
[es]
def equipment_apply_effect_block_equipment_slots(evt : EquipmentApplyEffects;
                                                 equipment_effect__blockEquipmentSlots : StringList)
  var actorProcessed = false
  query(evt.actorEid) <| $ [es] (var human_equipment__slotsFlags : Object&)
    actorProcessed = true
    for slot in equipment_effect__blockEquipmentSlots
      human_equipment__slotsFlags |> ensure_int(string(slot), 0) <| $(var flags : int&)
        flags |= int(EquipmentSlotFlags.REMOVED)

      if is_server()
        unequip_equipment_from_slot(string(slot), evt.actorEid)

  // Debugging bug with blocked equipment slots
  if !actorProcessed
    logerr("EquipmentApplyEffects: failed to process actor - {get_entity_info(evt.actorEid)}
doesEntityExist={doesEntityExist(evt.actorEid)}
isLoadingEntity={isLoadingEntity(evt.actorEid)}
is_entity_archetype_exists={is_entity_archetype_exists(evt.actorEid)}")


[es]
def equipment_revert_effect_block_equipment_slots(evt : EquipmentRevertEffects;
                                                  equipment_effect__blockEquipmentSlots : StringList)
  query(evt.actorEid) <| $ [es] (var human_equipment__slotsFlags : Object&)
    for slot in equipment_effect__blockEquipmentSlots
      human_equipment__slotsFlags |> ensure_int(string(slot), 0) <| $(var flags : int&)
        flags &= ~int(EquipmentSlotFlags.REMOVED)


[es(on_appear)]
def equipment_effects_postponed_init(evt : Event;
                                     equipment_effects_postponed__timeout : float = 60.0;
                                     var equipment_effects_postponed__timeoutAt : float&)
  equipment_effects_postponed__timeoutAt = get_sync_time() + equipment_effects_postponed__timeout


[es(no_order)]
def equipment_effects_postponed_update(act : UpdateStageInfoAct;
                                       eid : EntityId;
                                       equipment_effects_postponed__apply : bool;
                                       equipment_effects_postponed__actorEid : EntityId;
                                       equipment_effects_postponed__equipmentEid : EntityId;
                                       equipment_effects_postponed__timeoutAt : float)
  var destroy = false

  if (is_entity_archetype_exists(equipment_effects_postponed__actorEid) &&
      is_entity_archetype_exists(equipment_effects_postponed__equipmentEid))
    print("[EQUIPMENT POSTPONED EVENTS] Send event!
equipment_effects_postponed__apply={equipment_effects_postponed__apply}
equipment_effects_postponed__actorEid={get_entity_info(equipment_effects_postponed__actorEid)}
equipment_effects_postponed__equipmentEid={get_entity_info(equipment_effects_postponed__equipmentEid)}")
    destroy = true
    if equipment_effects_postponed__apply
      sendEvent(equipment_effects_postponed__equipmentEid, EquipmentApplyEffects(actorEid = equipment_effects_postponed__actorEid))
    else
      sendEvent(equipment_effects_postponed__equipmentEid, EquipmentRevertEffects(actorEid = equipment_effects_postponed__actorEid))
  elif act.curTime >= equipment_effects_postponed__timeoutAt
    logwarn("[EQUIPMENT POSTPONED EVENTS] Postponed event timeout!
equipment_effects_postponed__apply={equipment_effects_postponed__apply}
equipment_effects_postponed__actorEid={get_entity_info(equipment_effects_postponed__actorEid)}
equipment_effects_postponed__equipmentEid={get_entity_info(equipment_effects_postponed__equipmentEid)}")
    destroy = true

  if destroy
    destroyEntity(eid)


// equipment_effect__serverAffectTemplate
[es(tag=server)]
def equipment_effect_add_affect_on_equip(evt : EquipmentApplyEffects;
                                         equipment_effect__serverAffectTemplate : string;
                                         var equipment_effect__serverAffectEid : EntityId&)
  equipment_effect__serverAffectEid = createEntity(equipment_effect__serverAffectTemplate) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", evt.actorEid)


[es(tag=server)]
def equipment_effect_remove_affect_on_unequip(evt : EquipmentRevertEffects;
                                              equipment_effect__serverAffectEid : EntityId)
  destroyEntity(equipment_effect__serverAffectEid)