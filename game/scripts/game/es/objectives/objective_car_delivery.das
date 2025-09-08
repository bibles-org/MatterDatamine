require ecs
require math.base
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.events.events_active_matter


[es(tag=server, on_appear)]
def create_quest_car(evt : Event;
                     transform : float3x4;
                     car_delivery_target__carTemplate : string;
                     var car_delivery_target__carEid : EntityId&)
  car_delivery_target__carEid = createEntity(car_delivery_target__carTemplate) <| $(init)
    set(init, "transform", transform)


[es(tag=server, no_order, REQUIRE=objectiveCarDelivery, REQUIRE_NOT=disableObjectiveUpdate)]
def objective_car_delivery_act(info : ParallelUpdateFrameDelayed;
                               eid aka objective_eid : EntityId;
                               objective__playerEid : EntityId;
                               objective__staticTargetsList : EidList)
  query(objective__playerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es(REQUIRE_NOT=deadEntity)] (isInVehicle : bool;
                                                        vehicle__lastEid : EntityId)
      if !isInVehicle || vehicle__lastEid == INVALID_ENTITY_ID
        return
      // check if current vehicle is quest vehicle
      var isQuestVehicle = false
      for targetEid in objective__staticTargetsList
        query(targetEid) <| $ [es] (car_delivery_target__carEid : EntityId)
          isQuestVehicle = car_delivery_target__carEid == vehicle__lastEid
        if isQuestVehicle
          break
      if !isQuestVehicle
        return

      query(vehicle__lastEid) <| $ [es] (transform aka vehicle_transform : float3x4)
        // check if current vehicle is in zone
        var isInTargetZone = false
        for targetEid in objective__staticTargetsList
          query(targetEid) <| $ [es(REQUIRE=carDeliveryPointTarget)] ()
            isInTargetZone = is_point_in_objective_target_geometry(vehicle_transform[3], targetEid)
          if isInTargetZone
            do_progress_for_objective(objective_eid)
            return