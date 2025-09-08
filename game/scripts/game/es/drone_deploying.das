require ecs
require ecs.safe
require net
require math.base
require DagorMath
require Dacoll
require game.events.events_active_matter
require AnimV20
require GeomNodeTree
require game.es.inventory_common
require game.es.inventory_equipment_common
require DngHuman
require game.es.use_query_params_common


def get_device_slot_item_id(human_equipment__slots : Object)
  return human_equipment__slots["device1"] ?? INVALID_ENTITY_ID


[es(tag=gameClient, track=(drone_deploying__deploying, drone_deploying__operating))]
def track_preview_drone_client(evt : Event;
                               eid : EntityId;
                               drone_deploying__deploying : bool;
                               drone_deploying__operating : bool;
                               var drone_deploying__previewEid : EntityId&;
                               var isShootingAllowed : bool&;
                               human_equipment__slots : Object)
  if drone_deploying__deploying
    // query for hero tag is here because when deleting preview after death the player does not have hero component anymore
    query(eid) <| $ [es(REQUIRE=hero)] ()
      let droneEid = get_device_slot_item_id(human_equipment__slots)
      query(droneEid) <| $ [es] (drone__previewTemplate : string)
        drone_deploying__previewEid = createEntity(drone__previewTemplate)
  elif drone_deploying__previewEid != INVALID_ENTITY_ID
    destroyEntity(drone_deploying__previewEid)
    drone_deploying__previewEid = INVALID_ENTITY_ID
  isShootingAllowed = !(drone_deploying__deploying || drone_deploying__operating)


[es(tag=server, track=(drone_deploying__deploying, drone_deploying__operating))]
def track_preview_drone_server(evt : Event;
                               drone_deploying__deploying : bool;
                               drone_deploying__operating : bool;
                               var isShootingAllowed : bool&)
  isShootingAllowed = !(drone_deploying__deploying || drone_deploying__operating)


[es(tag=gameClient, track=(isAlive, isDowned, isInVehicle))]
def stop_drone_deploying(evt : Event;
                         eid : EntityId;
                         drone_deploying__deploying : bool;
                         isAlive : bool;
                         isDowned : bool;
                         isInVehicle : bool)
  if drone_deploying__deploying && (!isAlive || isDowned || isInVehicle)
    send_net_event(eid, CmdCancelDroneDeploying())


[es(tag=gameClient, no_order)]
def update_drone_preview_pos(info : ParallelUpdateFrameDelayed;
                             eid : EntityId;
                             drone_deploying__previewEid : EntityId;
                             drone_deploying__interactionRadius : float)
  query(drone_deploying__previewEid) <| $ [es] (var transform aka drone_preview_transform : float3x4&)
    let params = get_use_query_params(eid)
    var dirT = drone_deploying__interactionRadius
    var norm : float3
    var dronePos = params.pos + params.dir * dirT
    if traceray_normalized(params.pos, params.dir, dirT, norm)
      dronePos = params.pos + params.dir * (dirT - 0.2)
    drone_preview_transform[3] = dronePos


[es(tag=server)]
def cmd_cancel_deploy_drone(evt : CmdCancelDroneDeploying;
                            var drone_deploying__deploying : bool&)
  drone_deploying__deploying = false


[es(tag=server)]
def cmd_start_deploying_drone(evt : CmdStartDroneDeploying;
                              isDowned : bool;
                              isAlive : bool;
                              isInVehicle : bool;
                              eid aka owner_eid : EntityId;
                              var drone_deploying__deploying : bool&)
  query(owner_eid) <| $ [es] (human_equipment__slots : Object)
    let itemEid = get_device_slot_item_id(human_equipment__slots)
    query(itemEid) <| $ [es(REQUIRE=drone__template)] ()
      drone_deploying__deploying = !isDowned && isAlive && !isInVehicle


[es(tag=server)]
def cmd_deploy_drone(evt : CmdDroneDeploy;
                     eid aka owner_eid : EntityId;
                     drone_deploying__interactionRadius : float;
                     human_net_phys : HumanActor;
                     human_equipment__slots : Object;
                     var drone_deploying__operating : bool&;
                     var drone_deploying__deploying : bool&)
  if !drone_deploying__deploying
    return
  var dronePos = evt.pos
  let params = get_use_query_params(owner_eid)
  if distance_sq(dronePos, params.pos) > square(drone_deploying__interactionRadius)
    var dirT = drone_deploying__interactionRadius
    var norm : float3
    let look_dir = normalize(dronePos - params.pos)
    dronePos = params.pos + look_dir * dirT
    if traceray_normalized(params.pos, look_dir, dirT, norm)
      dronePos = params.pos + look_dir * (dirT - 0.2)

  var tm = IDENT_TM
  let dir = normalize(human_net_phys.phys.appliedCT.wishLookDir * float3(1., 0., 1.))
  make_tm(dir_to_quat(dir), dronePos, tm)

  let itemEid = get_device_slot_item_id(human_equipment__slots)
  query(itemEid) <| $ [es] (drone__template : string)
    unequip_equipment_from_slot("device1", owner_eid)
    destroyEntity(itemEid)
    createEntity(drone__template) <| $(var init)
      set(init, "drone__owner", owner_eid)
      set(init, "transform", tm)
    drone_deploying__operating = true

  drone_deploying__deploying = false
