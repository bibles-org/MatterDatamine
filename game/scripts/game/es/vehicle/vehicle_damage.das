require ecs
require ecs.safe
require dm
require DngDm
require vehicle
require DagorSystem
require game.events.events_active_matter


[es(tag=server, REQUIRE=(vehicle, damage_model), on_appear)]
def add_non_burnable_on_vehicle_created(evt : Event; eid : EntityId)
  addSubTemplate(eid, "non_burnable")


[es(tag=server, on_appear, after=dm_phys_parts_es)]
def vehicle_dm_parts_init(evt : Event;
                          eid : EntityId;
                          damage_model : DamageModel;
                          dm_phys_parts__body : Array;
                          var dm_phys_parts__bodyPartIds : IntList)
  dm_phys_parts__bodyPartIds |> clear()
  for partName in dm_phys_parts__body
    let partIdx = damage_model |> find_part_id_by_name(partName ?? "")
    if partIdx < 0
      logerr("{eid}<{getEntityTemplateName(eid)}>: undefined dm part name: {partName}")
    else
      dm_phys_parts__bodyPartIds |> push(partIdx)


[es(after=vehicle_phys_damage_updater_es)]
def vehicle_phys_damage_updater_body_es(evt : ParallelUpdateFrameDelayed;
                                        dm_phys_parts__bodyPartIds : IntList;
                                        dm_state : UInt16List;
                                        var vehicle_net_phys : VehiclePhysActor)
  if length(dm_phys_parts__bodyPartIds) > 0
    let partId = dm_phys_parts__bodyPartIds[0]
    if partId < length(dm_state)
      let bodyHp = int(dm_state[partId])
      if bodyHp <= 0
        vehicle_net_phys.phys |> vehicle_phys_setEngineReadyness(0.0)
