module dm_common shared
require ecs
require app
require dm
require DngDm


def deal_damage_to_body(eid : EntityId;
                        offender_eid : EntityId;
                        damage : float)
  query(eid) <| $ [es] (dm_phys_parts__bodyPartIds : IntList;
                        var damage_model : DamageModel)
    using() <| $(var hitData : HitData#)
      hitData.offender = offender_eid
      for partId in dm_phys_parts__bodyPartIds
        if get_part_hp(damage_model.dmData, PartId(uint(partId))) > 0.0
          deal_damage_to_part(damage_model, eid, partId, 0, int(DamageEffectsMask.DM_EFFECTS_MASK_ALL), damage, hitData)


def deal_damage_to_transmission(eid : EntityId;
                                offender_eid : EntityId;
                                damage : float)
  query(eid) <| $ [es] (dm_phys_parts__transmissionPartIds : IntList;
                        var damage_model : DamageModel)
    using() <| $(var hitData : HitData#)
      hitData.offender = offender_eid
      for partId in dm_phys_parts__transmissionPartIds
        if get_part_hp(damage_model.dmData, PartId(uint(partId))) > 0.0
          deal_damage_to_part(damage_model, eid, partId, 0, int(DamageEffectsMask.DM_EFFECTS_MASK_ALL), damage, hitData)


def deal_damage_to_engine(eid : EntityId;
                          offender_eid : EntityId;
                          damage : float)
  query(eid) <| $ [es] (dm_phys_parts__enginePartIds : IntList;
                        var damage_model : DamageModel)
    using() <| $(var hitData : HitData#)
      hitData.offender = offender_eid
      for partId in dm_phys_parts__enginePartIds
        if get_part_hp(damage_model.dmData, PartId(uint(partId))) > 0.0
          deal_damage_to_part(damage_model, eid, partId, 0, int(DamageEffectsMask.DM_EFFECTS_MASK_ALL), damage, hitData)