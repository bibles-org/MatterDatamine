require ecs
require game.events.vehicle_events
require game.events.events
require game.events.events_game
require dm
require DngNet
require DngActor
require DngHelicopter


[es(tag=server, REQUIRE=(vehicle, damage_model), REQUIRE_NOT=repairable__repairRequired, on_appear)]
def add_repairable_subtemplate_on_vehicle_created(evt : Event; eid : EntityId)
  addSubTemplate(eid, "repairable_vehicle")


[es(tag=server, REQUIRE=vehicle, REQUIRE_NOT=broken_vehicle, after=damage_model_es)]
def check_is_repair_required(evt : EventOnPartDamaged;
                             eid : EntityId;
                             damage_model : DamageModel;
                             helicopter : Tag const?;
                             var fire_damage__isBurn : bool&;
                             var repairable__repairRequired : bool&)
  repairable__repairRequired = false
  for i in range(get_damage_part_props_count(damage_model.dmData))
    let hpRel = rel_hp_fixed_to_float(get_damage_part_props(damage_model.dmData, i).relHpFixed)
    if hpRel <= 0.5
      repairable__repairRequired = true
      if !(eid |> has("isTank")) && helicopter == null
        fire_damage__isBurn = false

    if hpRel <= 0.0
      addSubTemplate(eid, "broken_vehicle")
      break


[es(tag=server, REQUIRE=brokenVehicle, after=need_repair_check_on_part_damaged_es)]
def need_repair_check_on_exploded(evt : EventOnPartDamaged; isExploded : bool; var repairable__repairRequired : bool&)
  if isExploded
    repairable__repairRequired = false


[es(tag=server, REQUIRE=brokenVehicle, REQUIRE_NOT=(isTank, helicopter), after=damage_model_es)]
def turn_off_burn_after_damage(evt : EventOnPartDamaged; var fire_damage__isBurn : bool&)
  fire_damage__isBurn = false


[es(tag=server, REQUIRE=broken_vehicle, REQUIRE_NOT=helicopter, after=repair_external_es)]
def remove_broken_car_effects_after_repair(evt : EventOnRepaired; eid : EntityId)
  removeSubTemplate(eid, "broken_vehicle")

