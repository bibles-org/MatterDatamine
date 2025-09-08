require ecs
require ecs.safe
require DagorSystem
require game.events.events
require game.es.entity_mods_common
require game.events.inventory_events


[es(on_appear)]
def entity_mod_effect_apply(evt : Event;
                            eid, game_effect__attachedTo : EntityId;
                            entity_mod_effects : Object)
  query(game_effect__attachedTo) <| $ [es] (var entity_mods : Object&)
    add_mod_effects_to_object(entity_mod_effects, "{eid}", entity_mods)
    sendEvent(game_effect__attachedTo, EventOnModsChanged())


[es(on_disappear)]
def entity_mod_effect_reset(evt : Event;
                            eid, game_effect__attachedTo : EntityId;
                            entity_mod_effects : Object)
  query(game_effect__attachedTo) <| $ [es] (var entity_mods : Object&)
    remove_mod_effects_from_object(entity_mod_effects, "{eid}", entity_mods)
    sendEvent(game_effect__attachedTo, EventOnModsChanged())


[es(on_appear)]
def entity_mod_equipment_effect_created(evt : Event;
                                        eid, slot_attach__attachedTo : EntityId;
                                        entity_mod_effects : Object)
  query(slot_attach__attachedTo) <| $ [es] (var entity_mods : Object&)
    add_mod_effects_to_object(entity_mod_effects, "{eid}", entity_mods)
  sendEvent(slot_attach__attachedTo, EventOnModsChanged())


[es]
def entity_mod_equipment_effect_apply(evt : EventOnEquipmentEquipped;
                                      eid : EntityId;
                                      var entity_mods : Object&)
  query(evt.equipmentEid) <| $ [es] (entity_mod_effects : Object)
    add_mod_effects_to_object(entity_mod_effects, "{evt.equipmentEid}", entity_mods)
  sendEvent(eid, EventOnModsChanged())


[es]
def entity_mod_equipment_effect_reset(evt : EventOnEquipmentUnequipped;
                                      eid : EntityId;
                                      var entity_mods : Object&)
  query(evt.equipmentEid) <| $ [es] (entity_mod_effects : Object)
    remove_mod_effects_from_object(entity_mod_effects, "{evt.equipmentEid}", entity_mods)
  sendEvent(eid, EventOnModsChanged())


[es(on_appear, track=item__humanOwnerEid)]
def entity_mod_inventory_effect_apply(evt : Event;
                                      eid, item__humanOwnerEid, item__containerOwnerEid : EntityId;
                                      entity_mod_effects : Object)
  if item__containerOwnerEid == INVALID_ENTITY_ID || item__containerOwnerEid |> has("stash_inventory__heroEid")
    return
  query(item__humanOwnerEid) <| $ [es] (var entity_mods : Object&)
    add_mod_effects_to_object(entity_mod_effects, "{eid}", entity_mods)
  sendEvent(item__humanOwnerEid, EventOnModsChanged())


[es(on_disappear)]
def entity_mod_inventory_effect_reset(evt : Event;
                                      eid, item__humanOwnerEid, item__lastContainerOwnerEid : EntityId;
                                      entity_mod_effects : Object)
  if item__lastContainerOwnerEid |> has("stash_inventory__heroEid")
    return
  query(item__humanOwnerEid) <| $ [es] (var entity_mods : Object&)
    remove_mod_effects_from_object(entity_mod_effects, "{eid}", entity_mods)
  sendEvent(item__humanOwnerEid, EventOnModsChanged())


[es(on_appear)]
def entity_mod_values_init(evt : Event; var entity_mod_values : Object&)
  for entityModValue in entity_mod_values
    var entityModValueObj = getRW_ecs_object(entityModValue.value)
    if entityModValueObj == null
      continue
    let defaultValue = entityModValueObj |> get_float("value")
    if defaultValue == null
      continue
    *entityModValueObj |> set("defaultValue", *defaultValue)


[es(on_event=EventOnModsChanged)]
def entity_mod_effect_calc(evt : Event;
                           eid : EntityId;
                           entity_mods : Object;
                           var entity_mod_values : Object&)
  for entityModValue in entity_mod_values
    var entityModValueObj = getRW_ecs_object(entityModValue.value)
    if entityModValueObj == null
      logerr("[ENTITY_MOD] eid <{eid}> entitty mod <{entityModValue.key}> not object!")
      continue
    let defaultValue = *entityModValueObj |> get_float("defaultValue")
    if defaultValue == null
      logerr("[ENTITY_MOD] eid <{eid}> entitty mod <{entityModValue.key}> has not defaultValue!")
      continue
    var value = *entityModValueObj |> getRW_float("value")
    if value == null
      logerr("[ENTITY_MOD] eid <{eid}> entitty mod <{entityModValue.key}> has not value!")
      continue
    *value = *defaultValue

    let entityMod = entity_mods[entityModValue.key] ?as Object
    if entityMod == null
      continue
    var calculatedValues <- fixed_array(0.0, 0.0, 1.0, 1.0)
    for entityModCalc in *entityMod
      let calcType = entityModCalc.key
      let entityModCalcValue = entityModCalc.value as Object
      if entityModCalcValue == null
        continue

      if calcType == "add"
        calculatedValues[0] = calc_change_add_attr(*entityModCalcValue)
      elif calcType == "add_diminishing"
        calculatedValues[1] = calc_diminishing_change_add_attr(*entityModCalcValue)
      elif calcType == "mult"
        calculatedValues[2] = calc_change_mult_attr(*entityModCalcValue)
      elif calcType == "mult_diminishing"
        calculatedValues[3] = calc_diminishing_change_mult_attr(*entityModCalcValue)
      else
        logerr("[ENTITY_MOD] eid <{eid}> unknown calcType <{calcType}> in mod <{entityModValue.key}>")
    *value = (*value + calculatedValues[0] + calculatedValues[1]) * calculatedValues[2] * calculatedValues[3]


//TODO: Rewrite to new mods system
[es]
def entity_mods_es(evt : EventOnModsChanged;
                   var entity_mods__reloadMult : float&;
                   var entity_mods__shotDeviationMult : float&;
                   entity_mods__reloadMultMods : Object;
                   entity_mods__shotDeviationMods : Object)
  entity_mods__reloadMult = calc_change_mult_attr(entity_mods__reloadMultMods)
  entity_mods__shotDeviationMult = calc_change_mult_attr(entity_mods__shotDeviationMods)
