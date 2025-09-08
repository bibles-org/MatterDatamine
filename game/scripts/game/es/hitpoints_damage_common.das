module hitpoints_damage_common shared

require ecs
require DngDm
require danetlibs.dm.dm_events
require game.es.entity_mods_common


def calculate_modified_damage_delta(evt : CmdApplyDamage;
                                    base_damage_multiplier : float;
                                    entity_mod_values : Object const?)
  var deltaHp = evt.deltaHp
  deltaHp *= base_damage_multiplier

  if entity_mod_values != null
    deltaHp *= get_mod_value("hitpointsDmgMult", *entity_mod_values, 1.0)

    if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
      deltaHp *= get_mod_value("hitpointsMeleeDmgMult", *entity_mod_values, 1.0)
  return deltaHp
