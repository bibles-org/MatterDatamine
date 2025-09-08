require ecs
require ecs.common
require strings
require DngNet
require game.events.events
require game.events.events_active_matter
require game.events.vehicle_events
require game.es.vehicle.vehicle_seats_common
require DagorSystem
require game.utils.hero
require game.utils.team
require game.utils.net_utils
require DngActor
require DngHuman
require vehicle
require app
require replay


def detect_camera_type(owner, wishCamera, isInHatch)
  let isAlive = get_bool(owner, "isAlive") ?? true
  if !isAlive
    return int(VehicleCameraType.VEHICLE_CAMERA_DEAD)

  if wishCamera == int(VehicleCameraType.VEHICLE_CAMERA_COMMANDER) && !isInHatch
    return int(VehicleCameraType.VEHICLE_CAMERA_COMMANDER_COCKPIT)

  if wishCamera == int(VehicleCameraType.VEHICLE_CAMERA_GUNNER)
    if isInHatch
      return int(VehicleCameraType.VEHICLE_CAMERA_COMMANDER)

  return wishCamera


def recreate_vehicle(vehicle_eid : EntityId; phys_actor : BasePhysActor; mode : VehicleControlsState#)
  let heroComponents = "+{phys_actor.physTypeStr}_hero_components"
  let controlComponents = "+{phys_actor.physTypeStr}_control_components"
  var templName = getEntityTemplateName(vehicle_eid)
  templName = replace(templName, heroComponents, "")
  templName = replace(templName, controlComponents, "")
  templName = replace(templName, "+camera_control_components", "")
  if mode.canControlVehicleOrTurrets
    templName += heroComponents
  if mode.canControlVehicle
    templName += controlComponents
  if mode.canControlCamera
    templName += "+camera_control_components"
  reCreateEntityFrom(vehicle_eid, templName)

def stop_vehicle_control(var phys_actor : BasePhysActor&)
  phys_actor |> base_phys_actor_initRole()
  phys_actor |> base_phys_actor_resetAAS() // Don't try to process too old AAS when we control this vehicle again
  phys_actor |> base_phys_actor_reset()

def stop_vehicle_control_server(var phys_actor : BasePhysActor&)
  stop_vehicle_control(phys_actor)
  base_phys_actor_setRoleAndTickrateType(phys_actor, phys_actor.role, PhysTickRateType.LowFreq)


def determine_controls_for_player(var mode : VehicleControlsState#; current_owner_eid, curret_seat_eid, current_owner_player, seatEids, can_acquire_controls) : void
  if !(get_bool(current_owner_eid, "isAlive") ?? false)
    return

  var isCommander = false

  query(curret_seat_eid) <| $ [es(REQUIRE=commanderSeat)] ()
    isCommander = true

  for seatEid in seatEids
    query(seatEid) <| $ [es] (seat__ownerEid, seat__playerEid : EntityId; seat__availableControls : VehicleControlsState;
                              seat__availableHatchControls : VehicleControlsState const?; seats_hatch_nodes__openPos : float = 0.0)
      let isOwnedByPlayer = seat__playerEid == current_owner_player
      let isAlive = get_bool(seat__ownerEid, "isAlive") ?? false
      if isOwnedByPlayer && isAlive
        assume availableControls = seat__availableHatchControls != null && seats_hatch_nodes__openPos > 0.0 ? *seat__availableHatchControls : seat__availableControls
        if (can_acquire_controls & int(VehicleControlTypes.VEHICLE_CONTROLS_MOVEMENT)) != 0
          mode.canControlVehicle ||= availableControls.canControlVehicle
        if (can_acquire_controls & int(VehicleControlTypes.VEHICLE_CONTROLS_CAMERA)) != 0
          mode.canControlCamera = true

def find_owner_player_for_vehicle(vehicle_seats__seatEids : EidList) : EntityId
  var playerEid = INVALID_ENTITY_ID
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__playerEid : EntityId; seat__ownerControls : VehicleControlsState)
      if seat__ownerControls.canControlVehicle
        playerEid = seat__playerEid
  return playerEid

[es(tag=server, no_order)]
def vehicle_seats_update_controls(info : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  vehicle_seats__seatEids : EidList;
                                  vehicle_seats_can_acquire_controls : IntList const?;
                                  var vehicle__allAcquiredControls : VehicleControlsState&;
                                  var replication : NetObject?)
  using() <| $(var vehicleMode : VehicleControlsState#)
    for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid, seat__playerEid : EntityId;
                                seat__isPlayer : bool;
                                var seat__ownerControls : VehicleControlsState)
        if seat__ownerEid == INVALID_ENTITY_ID
          seat__ownerControls.turretsMask = uint(0)
          seat__ownerControls.canControlVehicle = false
          return
        let canAcquireControls = (vehicle_seats_can_acquire_controls != null
          ? (*vehicle_seats_can_acquire_controls)[seatNo]
          : int(VehicleControlTypes.VEHICLE_CONTROLS_MOVEMENT))

        using() <| $(var seatMode : VehicleControlsState#)
          if seat__isPlayer
            seatMode |> determine_controls_for_player(seat__ownerEid, seatEid, seat__playerEid, vehicle_seats__seatEids, canAcquireControls)
          vehicleMode.canControlVehicle ||= seatMode.canControlVehicle
          vehicleMode.turretsMask = uint(int(vehicleMode.turretsMask) | int(seatMode.turretsMask))
          seat__ownerControls := seatMode

    let playerEid = find_owner_player_for_vehicle(vehicle_seats__seatEids)
    let connid = get_int(playerEid, "connid") ?? INVALID_CONNECTION_ID
    let conn : IConnection? = (connid != INVALID_CONNECTION_ID) ? get_client_connection(connid) : null
    let isOwnerChanged : bool = (replication != null && vehicleMode.canControlVehicle &&
                                (playerEid != INVALID_ENTITY_ID) &&
                                conn != null && net_object_getControlledBy(*replication) != connection_getId(*conn))
    if vehicle__allAcquiredControls != vehicleMode || isOwnerChanged
      vehicle__allAcquiredControls := vehicleMode
      if replication == null
        return
      if playerEid != INVALID_ENTITY_ID && conn != null && vehicleMode.canControlVehicle
        if net_object_getControlledBy(*replication) == INVALID_CONNECTION_ID || isOwnerChanged
          net_object_setControlledBy(*replication, connection_getId(*conn))
      else
        net_object_setControlledBy(*replication, INVALID_CONNECTION_ID)
      let isOwner : bool = (playerEid != INVALID_ENTITY_ID && conn != null &&
                          net_object_getControlledBy(*replication) == connection_getId(*conn))
      var physActor : BasePhysActor? = get_phys_actor(eid)
      if physActor == null
        return
      if isOwner && vehicleMode.canControlVehicle
        *physActor |> base_phys_actor_setRoleAndTickrateType(NetRole.ROLE_REMOTELY_CONTROLLED_AUTHORITY, PhysTickRateType.Normal)
      if !vehicleMode.canControlVehicle || !vehicleMode.canControlVehicleOrTurrets
        stop_vehicle_control_server(*physActor)

[es(tag=gameClient, no_order)]
def vehicle_seats_apply_controls(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 vehicle_seats__seatEids : EidList;
                                 var vehicle__localControls : VehicleControlsState&;
                                 var replication : NetObject?)
  if is_replay_playing()
    return

  let hero = get_controlled_hero()

  using() <| $(var mode : VehicleControlsState#)
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__ownerControls : VehicleControlsState)
        if seat__ownerEid == hero
          mode = seat__ownerControls

    if vehicle__localControls != mode
      if replication != null
        if mode.canControlVehicle
          let sconn : IConnection const? = get_server_conn()
          if sconn != null
            net_object_setControlledBy(*replication, connection_getId(*sconn))
        else
          net_object_setControlledBy(*replication, INVALID_CONNECTION_ID)
      var physActor : BasePhysActor? = get_phys_actor(eid)
      if physActor == null
        return
      if mode.canControlVehicle
        let nr : NetRole = (is_server()
          ? NetRole.ROLE_LOCALLY_CONTROLLED_AUTHORITY
          : NetRole.ROLE_LOCALLY_CONTROLLED_SHADOW)
        *physActor |> base_phys_actor_setRoleAndTickrateType(nr, PhysTickRateType.Normal)
      if int(mode.turretsMask) != 0
        if !mode.canControlVehicle
          stop_vehicle_control(*physActor)
        if int(vehicle__localControls.turretsMask) == 0
          query(hero) <| $ [es] (human_net_phys : HumanActor)
            assume ct = human_net_phys.phys.producedCT
            sendEventImmediate(eid, CmdSetVehicleShootDir(dir = ct.wishShootDir))
      vehicle__localControls := mode
      if !mode.canControlVehicleOrTurrets
        stop_vehicle_control(*physActor)
      recreate_vehicle(eid, *physActor, mode)


[es(tag=gameClient, no_order, REQUIRE=heroVehicle)]
def vehicle_seats_apply_camera_type(info : ParallelUpdateFrameDelayed;
                                    cockpit__isHeroInCockpit : bool = false;
                                    vehicle_seats__seatEids : EidList;
                                    var vehicleCameraType : int&;
                                    var isTpsView : bool?)
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__isPlayer : bool; seat__cameraType : int; seat__isInHatch : bool)
      if !seat__isPlayer || !has(seat__ownerEid, "hero")
        return

      let cameraType = detect_camera_type(seat__ownerEid, seat__cameraType, !cockpit__isHeroInCockpit || seat__isInHatch)
      vehicleCameraType = cameraType

      var heroIsTpsView = false
      query(seat__ownerEid) <| $ [es] (isTpsView : bool; var vehicleCameraType : int&)
        vehicleCameraType = isTpsView ? int(VehicleCameraType.VEHICLE_CAMERA_NONE) : cameraType
        heroIsTpsView = isTpsView

      if isTpsView != null
        *isTpsView = heroIsTpsView

[es(tag=gameClient, on_event=EventComponentsDisappear, REQUIRE=heroVehicle)]
def vehicle_seats_reset_camera_type(evt : Event; var vehicleCameraType : int&)
  vehicleCameraType = int(VehicleCameraType.VEHICLE_CAMERA_NONE)
  let hero = get_controlled_hero()
  query(hero) <| $ [es] (var vehicleCameraType : int&)
    vehicleCameraType = int(VehicleCameraType.VEHICLE_CAMERA_NONE)


// triggers vehicle_seats_apply_controls to recalculate controls
[es(tag=gameClient, REQUIRE=helicopter)]
def vehicle_reset_local_controls(evt : EventResetLocalControls; var vehicle__localControls : VehicleControlsState&)
  vehicle__localControls := VehicleControlsState()
