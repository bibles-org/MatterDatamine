require ecs
require ecs.safe
require DagorSystem

[es(tag=server, on_appear)]
def init_seat_component(evt : Event; seat__id : int; seat__vehicleEid : EntityId; var seat__component : int&)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = vehicle_seats__seats[seat__id] as Object
    if seat == null
      return

    let componentName = get_string(*seat, "seatComponent", "")
    if componentName == ""
      logerr("seatComponent is not set for {seat__vehicleEid} ({getEntityTemplateName(seat__vehicleEid)})")
      return

    seat__component = int(ecs_hash(componentName))