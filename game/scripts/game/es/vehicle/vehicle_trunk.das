require ecs


[es(tag=server, on_appear)]
def vehicle_trunk_controller_init(evt : Event;
                                  eid aka controller_eid : EntityId;
                                  vehicle_trunk_controller__trunkTemplate : string;
                                  var composit_holder__childrenEids : EidList)
  if vehicle_trunk_controller__trunkTemplate != ""
    let trunkEid = createEntity(vehicle_trunk_controller__trunkTemplate) <| $ [es] (var init : ComponentsInitializer)
      init |> set("transform_attached__entityEid", controller_eid)
    composit_holder__childrenEids |> push(trunkEid)