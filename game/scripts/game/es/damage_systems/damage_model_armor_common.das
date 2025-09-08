module damage_model_armor_common shared
require ecs
require ecs.safe
require ecs.common
require DngDm
require DagorMath
require DagorSystem
require game.events.events_active_matter


def recalculate_protection_for_part(part_name : string;
                                    human_damage_model__armorMods : EidList;
                                    var human_damage_model__parts : Object)
  if part_name == ""
    return

  if part_name == "*"
    recalculate_protection_for_all_parts(human_damage_model__armorMods, human_damage_model__parts)
    return

  var part = human_damage_model__parts[part_name] ?as Object
  if part == null
    logerr("Unknown part: '{part_name}'")
    return

  var protectionList = (*part).protection ?as FloatList
  if protectionList != null
    *protectionList |> clear()

  for armorMod in human_damage_model__armorMods
    query(armorMod) <| $ [es] (dm_part_armor__partName : string;
                               dm_part_armor__protection : FloatList;
                               dm_part_armor__protectionMinHpKoef : float = 0.0;
                               item__hp : float = 1.0;
                               item__maxHp : float = 1.0)
      if dm_part_armor__partName != part_name && dm_part_armor__partName != "*"
        return

      let koef = cvt(ceil(item__hp), 0.0, item__maxHp, dm_part_armor__protectionMinHpKoef, 1.0)

      if protectionList == null
        *part |> set("protection", dm_part_armor__protection)
        protectionList = (*part).protection ?as FloatList
        for protDst in *protectionList
          protDst *= koef
      else
        if length(dm_part_armor__protection) > length(*protectionList)
          *protectionList |> resize(length(dm_part_armor__protection))
        for protSrc, protDst in dm_part_armor__protection, *protectionList
          // x% and y% - protections
          // common protection = 1 - (1 - x%) * (1 - y%) = x% + y% - x% * y%
          protDst = protSrc * koef + protDst - protSrc * koef * protDst


def recalculate_protection_for_all_parts(human_damage_model__armorMods : EidList;
                                         var human_damage_model__parts : Object)
  for part in human_damage_model__parts
    recalculate_protection_for_part(part.key, human_damage_model__armorMods, human_damage_model__parts)


def human_damage_model_set_armor_hp_in_percent(eid : EntityId; percent : float)
  query(eid) <| $ [es] (var human_damage_model__parts : Object; human_damage_model__armorMods : EidList)
    for armorEid in human_damage_model__armorMods
      query(armorEid) <| $ [es] (item__maxHp : float&; var item__hp : float&)
        item__hp = item__maxHp * percent
    recalculate_protection_for_all_parts(human_damage_model__armorMods, human_damage_model__parts)


def human_damage_model_destroy_all_armor(eid : EntityId)
  query(eid) <| $ [es] (var human_damage_model__parts : Object; human_damage_model__armorMods : EidList)
    for armorEid in human_damage_model__armorMods
      query(armorEid) <| $ [es(REQUIRE=item__hp)]
        sendEventImmediate(armorEid, CmdDamageItem(damage = 1e9, damageType = int(DamageType.DM_UNKNOWN)))
    recalculate_protection_for_all_parts(human_damage_model__armorMods, human_damage_model__parts)
