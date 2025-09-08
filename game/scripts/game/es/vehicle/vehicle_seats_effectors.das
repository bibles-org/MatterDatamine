require ecs
require ecs.safe
require ecs.common
require game.events.events
require game.events.events_active_matter
require AnimV20
require vehicle
require game.events.vehicle_events
require DagorSystem
require GeomNodeTree
require EffectorData

[es(tag=render, on_appear)]
def boat_anim_init_es(evt : Event;
                      animchar : AnimcharBaseComponent;
                      @shared_comp vehicle_seats__seats : Array;
                      var vehicle_seats__effectors : Array)
  if vehicle_seats__seats.empty
    return
  for seat in vehicle_seats__seats
    // get object seat
    let seatObj = seat as Object
    if seatObj == null
      return

    push_to_array(vehicle_seats__effectors) <| $(var obj : Object)
      let effectors = (*seatObj).effectors ?as Object
      if effectors == null
        return
      for field in *effectors
        let nodeValue = field.value ?? ""
        if nodeValue == ""
          logerr("can't find node for {field.key}")
          continue
        let index = geomtree_findNodeIndex(*animchar.nodeTree, nodeValue)
        if index < 0
          logerr("can't find node index for {field.key} equal {nodeValue}")
          continue
        set(obj, field.key, index)


[es(tag=render, before=before_animchar_update_sync, after=human_anim_es)]
def human_vehicle_effectors(info : ParallelUpdateFrameDelayed;
                            animchar : AnimcharBaseComponent;
                            vehicle_seats__effectors : Array;
                            vehicle_seats__seatEids : EidList;
                            transform : float3x4)
  if vehicle_seats__effectors.empty
    return
  let vehicleTm = transform
  var vehicleRootTm : float3x4
  geomtree_getNodeWtmRelScalar(*animchar.nodeTree, 0, vehicleRootTm)
  for seatOwnerNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    query(ownerEid) <| $ [es] (var animchar_effectors__effectorsState : Object; transform : float3x4; isInVehicle : bool)
      if !isInVehicle // seat__ownerEid can replicate late
        return
      let effectors = vehicle_seats__effectors[seatOwnerNo] as Object
      if effectors == null
        return
      for field in *effectors
        let effectorName = field.key
        let effectorIndex = *get_int(*effectors, effectorName)
        var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effectorName)

        if effector == null
          return

        let vehicleWofs = geomtree_calc_optimal_wofs(vehicleTm[3])
        let d_wofs = vehicleWofs - geomtree_calc_optimal_wofs(transform[3])

        var vehicleLocalWtm = vehicleTm
        vehicleLocalWtm[3] = vehicleTm[3] - vehicleWofs
        geomtree_getNodeWtmRelScalar(*animchar.nodeTree, effectorIndex, effector.wtm)
        effector.wtm = vehicleLocalWtm * (inverse(vehicleRootTm) * effector.wtm)
        effector.position = effector.wtm[3] + d_wofs
        effector.weight = 1.f
        effector.wtm[3] = effector.position

[es(tag=render, track=seat__ownerEid)]
def clear_effectors_on_seat_change(evt : Event; seat__ownerEid : EntityId)
  query(seat__ownerEid) <| $ [es] (var animchar_effectors__effectorsState : Object)
    for effName in animchar_effectors__effectorsState
      var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effName.key)
      if effector != null
        effector.weight = 0f

[es(tag=render, track=isInVehicle, REQUIRE=isInVehicle)]
def clear_effectors_on_vehicle_exit(evt : Event; var animchar_effectors__effectorsState : Object)
  for effName in animchar_effectors__effectorsState
    var effector = getNullableRW_EffectorData(animchar_effectors__effectorsState, effName.key)
    if effector != null
      effector.weight = 0f
