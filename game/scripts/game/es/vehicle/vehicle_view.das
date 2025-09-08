require ecs
require vehicle
require math.base
require DagorMath
require GamePhys
require DngDm
require dm
require game.events.events_game
require DagorSystem

let
  MSEC_TO_KMH = 3.6f

[es(tag=gameClient, after=net_phys_update_es, REQUIRE=vehicleWithWatched)]
def vehicle_minimal_view(info : UpdateStageInfoAct;
                         vehicle_net_phys : VehiclePhysActor;
                         transform : float3x4;
                         vehicle__fuel : float;
                         var vehicle_view__gear : int&;
                         var vehicle_view__neutralGear : int&;
                         var vehicle_view__rpm : int&;
                         var vehicle_view__speed : int&;
                         var vehicle_view__cruiseControl : int&;
                         var vehicle_view__fuelPct : float&;
                         var vehicle_view__isHandBraking : bool&;
                         var vehicle_view__isAutomaticTransmission : bool&)
  assume phys = vehicle_net_phys.phys
  vehicle_view__gear = int(phys.currentState.currentGear)
  vehicle_view__neutralGear = int(phys.neutralGearIndex)

  let rpm = vehicle__fuel > 0.0 ? roundi(phys.engineRPM) : 0
  vehicle_view__rpm = rpm - rpm % 100

  let speed = dot(float3(phys.currentState.velocity), transform[0])
  vehicle_view__speed = roundi(speed * MSEC_TO_KMH)

  vehicle_view__cruiseControl = int(phys.currentState.cruiseControl)
  vehicle_view__fuelPct = safediv(getFuelMassCurrent(phys.mass), getFuelMassMax(phys.mass)) * 100f
  vehicle_view__isHandBraking = ground_control_state_getAxisValue(phys.appliedCT, EGroundControlAxis.GCA_HAND_BRAKE) > 0.5f
  vehicle_view__isAutomaticTransmission = phys.appliedCT.isTransmissionAuto


def calc_parts_min_hp_rel(damage_model : DamageModel;
                          part_ids : IntList)
  var minHpRel = 1.0
  for partId in part_ids
    let hp = get_part_hp(damage_model.dmData, PartId(uint(partId)))
    let maxHp = get_max_hp(damage_model.dmData, partId)
    if maxHp > 0.0
      minHpRel = min(minHpRel, hp / maxHp)
  return minHpRel


[es(tag=gameClient, on_appear, track=dm_state, REQUIRE=(dm_state, vehicleWithWatched), after=vehicle_dm_parts_init)]
def vehicle_dm_hp_view(evt : Event;
                       damage_model : DamageModel;
                       dm_phys_parts__bodyPartIds : IntList;
                       dm_phys_parts__enginePartIds : IntList;
                       dm_phys_parts__transmissionPartIds : IntList;
                       var vehicle_view__bodyHpRel : float&;
                       var vehicle_view__engineHpRel : float&;
                       var vehicle_view__transmissionHpRel : float&)
  vehicle_view__bodyHpRel = calc_parts_min_hp_rel(damage_model, dm_phys_parts__bodyPartIds)
  vehicle_view__engineHpRel = calc_parts_min_hp_rel(damage_model, dm_phys_parts__enginePartIds)
  vehicle_view__transmissionHpRel = calc_parts_min_hp_rel(damage_model, dm_phys_parts__transmissionPartIds)

