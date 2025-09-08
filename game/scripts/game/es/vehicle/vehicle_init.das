require ecs
require math
require math.random
require dm
require DagorSystem


[es(tag=server, on_appear)]
def vehicle_state_randomizer_fuel(evt : Event;
                                  vehicle_state_randomizer__fuelRng : float2;
                                  vehicle__maxFuel : float;
                                  var vehicle__fuel : float&)
  let fuelRel = rnd_float(vehicle_state_randomizer__fuelRng)
  vehicle__fuel = fuelRel * vehicle__maxFuel


def setup_dm_part_hp(eid : EntityId;
                     part_id : int;
                     hp_rel : float;
                     var damage_model : DamageModel)
  let hpMax = get_max_hp(damage_model.dmData, part_id)
  let hp = get_part_hp(damage_model.dmData, PartId(uint(part_id)))
  let requiredHp = hp_rel * hpMax
  let damage = hp - requiredHp
  if damage > 0.0
    deal_damage_to_part(damage_model, eid, part_id, 0, 0, damage, HitData())


[es(tag=server, on_appear, after=vehicle_dm_parts_init)]
def vehicle_state_randomizer_dm(evt : Event;
                                eid : EntityId;
                                vehicle_state_randomizer__bodyHpRng : float2;
                                vehicle_state_randomizer__otherPartsHpDeltaRng : float2;
                                dm_phys_parts__bodyPartIds : IntList;
                                dm_phys_parts__enginePartIds : IntList;
                                dm_phys_parts__transmissionPartIds : IntList;
                                var damage_model : DamageModel)
  let bodyHpRel = rnd_float(vehicle_state_randomizer__bodyHpRng)
  for partId in dm_phys_parts__bodyPartIds
    setup_dm_part_hp(eid, partId, bodyHpRel, damage_model)

  for partId in dm_phys_parts__enginePartIds
    let hpRel = saturate(bodyHpRel + rnd_float(vehicle_state_randomizer__otherPartsHpDeltaRng))
    setup_dm_part_hp(eid, partId, hpRel, damage_model)

  for partId in dm_phys_parts__transmissionPartIds
    let hpRel = saturate(bodyHpRel + rnd_float(vehicle_state_randomizer__otherPartsHpDeltaRng))
    setup_dm_part_hp(eid, partId, hpRel, damage_model)



