require ecs
require ecs.safe
require game.events.events_active_matter
require game.es.damage_systems.damage_model_armor_common


[es(tag=server, track=human_damage_model__armorMods)]
def human_damage_model_track_armor_mods(evt : Event;
                                        human_damage_model__armorMods : EidList;
                                        var human_damage_model__parts : Object)
  recalculate_protection_for_all_parts(human_damage_model__armorMods, human_damage_model__parts)


[es(tag=server)]
def damage_model_part_damage_blocked(evt : EventDamageModelPartDamageBlocked;
                                     human_damage_model__armorMods : EidList)
  if evt.blockedDamage <= 0.0
    return

  var damagedItems : array<EntityId>
  for armorItemEid in human_damage_model__armorMods
    query(armorItemEid) <| $ [es(REQUIRE=item__hp)] (dm_part_armor__partName : string)
      if dm_part_armor__partName == evt.partName
        damagedItems |> push(armorItemEid)

  if length(damagedItems) > 0
    let damagePerItem = evt.blockedDamage / float(length(damagedItems))
    for itemEid in damagedItems
      sendEvent(itemEid, CmdDamageItem(damageType = evt.damageType, damage = damagePerItem))