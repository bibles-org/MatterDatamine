require ecs
require app
require net
require DagorInput
require game.events.events_active_matter
require game.events.input_events
require game.es.player_common
require game.es.client.drone_camera_common
require DngHelicopter


[es(on_appear, track=helicopter__enableAutopilot)]
def drone_enable_autopilot(evt : Event;
                           helicopter__enableAutopilot : bool;
                           var helicopter_net_phys : HelicopterActor&)
  helicopter_net_phys.phys.producedCT.autopilotKeepHeight = helicopter__enableAutopilot
  helicopter_net_phys.phys.producedCT.autopilotKeepPos = helicopter__enableAutopilot
  helicopter_net_phys.phys.producedCT.autopilotKeepYaw = helicopter__enableAutopilot


def switch_on_drone_action_set(droneIsActive : bool)
  let droneSetHandle = get_action_set_handle("Drone")
  if int(droneSetHandle) != int(BAD_ACTION_HANDLE)
    activate_action_set(droneSetHandle, droneIsActive)
  let humanControl = get_action_set_handle("Human")
  if int(humanControl) != int(BAD_ACTION_HANDLE)
    activate_action_set(humanControl, !droneIsActive)


[es(tag=input, REQUIRE=drone__local, on_appear, on_event=DroneEnterEvent)]
def turn_on_drone_action_set(evt : Event)
  switch_on_drone_action_set(true)


[es(tag=input, REQUIRE=drone__local, on_disappear, on_event=(DroneLeaveEvent, DroneForceLeaveEvent))]
def turn_off_drone_action_set(evt : Event)
  switch_on_drone_action_set(false)


[es(tag=input, REQUIRE=drone__local)]
def drone_input_mark_setup(evt : EventDaInputInit;
                           var drone_input__marked : int&)
  if evt.init
    drone_input__marked = int(get_action_handle("Drone.Mark", TYPEGRP_DIGITAL))
  else
    drone_input__marked = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear, REQUIRE=drone__local)]
def drone_input_mark_appear(evt : Event;
                            var drone_input__marked : int&)
  drone_input__marked = int(get_action_handle("Drone.Mark", TYPEGRP_DIGITAL))


[es(tag=input, on_disappear, REQUIRE=drone__local)]
def drone_input_mark_disappear(evt : Event;
                               var drone_input__marked : int&)
  drone_input__marked = int(BAD_ACTION_HANDLE)


[es(tag=input, REQUIRE=drone__local)]
def drone_input_common_setup(evt : EventDaInputInit;
                             var drone_input__leave : int&)
  if evt.init
    drone_input__leave = int(get_action_handle("Drone.Leave", TYPEGRP_DIGITAL))
  else
    drone_input__leave = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear, REQUIRE=drone__local)]
def drone_input_common_appear(evt : Event;
                              var drone_input__leave : int&)
  drone_input__leave = int(get_action_handle("Drone.Leave", TYPEGRP_DIGITAL))


[es(tag=input, on_disappear, REQUIRE=drone__local)]
def drone_input_common_disappear(evt : Event;
                                 var drone_input__leave : int&)
  drone_input__leave = int(BAD_ACTION_HANDLE)


[es(tag=input, REQUIRE=drone__local)]
def drone_input_drop_grenade_setup(evt : EventDaInputInit;
                                   var drone_input__dropGrenade : int&)
  if evt.init
    drone_input__dropGrenade = int(get_action_handle("Drone.DropGrenade", TYPEGRP_DIGITAL))
  else
    drone_input__dropGrenade = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear, REQUIRE=drone__local)]
def drone_input_drop_grenade_appear(evt : Event;
                                    var drone_input__dropGrenade : int&)
  drone_input__dropGrenade = int(get_action_handle("Drone.DropGrenade", TYPEGRP_DIGITAL))


[es(tag=input, on_disappear, REQUIRE=drone__local)]
def drone_input_drop_grenade_disappear(evt : Event;
                                       var drone_input__dropGrenade : int&)
  drone_input__dropGrenade = int(BAD_ACTION_HANDLE)


[es(tag=input, REQUIRE=drone__local)]
def camera_drone_triggers(evt : EventDaInputActionTriggered&;
                          eid aka drone_eid : EntityId;
                          drone_input__leave : int;
                          drone_input__dropGrenade : int = int(BAD_ACTION_HANDLE);
                          drone_input__marked : int = int(BAD_ACTION_HANDLE))
  if int(evt.action) == drone_input__leave
    send_net_event(drone_eid, DroneLeaveEvent())

  if int(evt.action) == drone_input__marked
    sendEvent(drone_eid, DroneMarkedCreate())

  if int(evt.action) == drone_input__dropGrenade
    send_net_event(drone_eid, DroneDropGrenade())


[es(tag=input, before=spectator_bhv_on_action_triggered_es)]
def spectator_drone_bhv_es(evt : EventDaInputActionTriggered;
                           spectator_input__prev : int;
                           spectator_input__next : int;
                           spectator__teamId : int;
                           spectator__target : EntityId;
                           spectator__nextChangeActivateAt : float)
  if get_sync_time() < spectator__nextChangeActivateAt
    return

  if int(evt.action) == spectator_input__next || int(evt.action) == spectator_input__prev
    let delta = int(evt.action) == spectator_input__next ? +1 : -1
    let nextTarget : EntityId = find_next_spec_target(spectator__teamId, spectator__target, delta)
    if nextTarget == spectator__target
      return
    query() <| $ [es(REQUIRE=drone__view)] (eid aka drone_eid : EntityId;
                                            drone__owner : EntityId;
                                            drone__prevCam : EntityId;
                                            var drone__attachedCam : EntityId&)
      destroy_drone_camera(drone_eid, drone__owner, drone__prevCam, drone__attachedCam)


[es(tag=input, after=human_input_es)]
def drone_deploying_input(evt : EventDaInputActionTerminated;
                          eid : EntityId;
                          human_input__droneDeploying : int;
                          human_input__startDroneDeploying : int;
                          human_input__cancelDroneDeploying : int;
                          input__enabled : bool;
                          drone_deploying__deploying : bool;
                          drone_deploying__previewEid : EntityId)
  if !input__enabled
    return
  let deploying = int(evt.action) == human_input__droneDeploying
  let startDeploying = int(evt.action) == human_input__startDroneDeploying
  let cancelDeploying = int(evt.action) == human_input__cancelDroneDeploying
  if !deploying && !cancelDeploying && !startDeploying
    return
  if startDeploying
    send_net_event(eid, CmdStartDroneDeploying())
  if !drone_deploying__deploying
    return
  if deploying
    query(drone_deploying__previewEid) <| $ [es] (transform : float3x4)
      send_net_event(eid, CmdDroneDeploy(pos = transform[3]))
  elif cancelDeploying
    send_net_event(eid, CmdCancelDroneDeploying())


def init(var human_input__droneDeploying : int&;
         var human_input__startDroneDeploying : int&;
         var human_input__cancelDroneDeploying : int&)
  human_input__droneDeploying = int(get_action_handle("Human.Shoot", TYPEGRP_DIGITAL))
  human_input__startDroneDeploying = int(get_action_handle("Human.Deploy", TYPEGRP_DIGITAL))
  human_input__cancelDroneDeploying = int(get_action_handle("Human.Aim1", TYPEGRP_DIGITAL))


def reset(var human_input__droneDeploying : int&;
          var human_input__startDroneDeploying : int&;
          var human_input__cancelDroneDeploying : int&)
  human_input__droneDeploying = int(BAD_ACTION_HANDLE)
  human_input__startDroneDeploying = int(BAD_ACTION_HANDLE)
  human_input__cancelDroneDeploying = int(BAD_ACTION_HANDLE)


[es(tag=input, REQUIRE=human_input)]
def drone_deploying_input_init_es(evt : EventDaInputInit;
                                  input__enabled : bool;
                                  var human_input__droneDeploying : int&;
                                  var human_input__startDroneDeploying : int&;
                                  var human_input__cancelDroneDeploying : int&)
  if !input__enabled
    return
  if evt.init
    init(human_input__droneDeploying, human_input__startDroneDeploying, human_input__cancelDroneDeploying)
  else
    reset(human_input__droneDeploying, human_input__startDroneDeploying, human_input__cancelDroneDeploying)


[es(tag=input, on_appear, REQUIRE=human_input)]
def drone_deploying_input_appear_es(evt : Event;
                                    var human_input__droneDeploying : int&;
                                    var human_input__startDroneDeploying : int&;
                                    var human_input__cancelDroneDeploying : int&)
  init(human_input__droneDeploying, human_input__startDroneDeploying, human_input__cancelDroneDeploying)


[es(tag=input, on_disappear, REQUIRE=human_input)]
def drone_deploying_input_destroyed_es(evt : Event;
                                       var human_input__droneDeploying : int&;
                                       var human_input__startDroneDeploying : int&;
                                       var human_input__cancelDroneDeploying : int&)
  reset(human_input__droneDeploying, human_input__startDroneDeploying, human_input__cancelDroneDeploying)


[es(tag=input, after=quick_use__objective_item_cursor_down_es, REQUIRE_NOT=deadEntity)]
def quick_use_drone_console_item_down_es(evt : EventDaInputActionTriggered;
                                         input__enabled : bool;
                                         eid aka human_eid : EntityId;
                                         quick_use_input__ObjectiveItem : int;
                                         quick_use__objective : string;
                                         human_use_object__selectedObject  : EntityId)
  if !input__enabled || human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  let action = int(evt.action)
  if action != quick_use_input__ObjectiveItem || !empty(quick_use__objective)
    return
  find_query() <| $[es(REQUIRE=isDrone)] (drone__owner : EntityId;
                                          drone__enableControl : bool;
                                          drone__remoteConsole : EntityId)
    if human_eid == drone__owner && drone__enableControl
      sendEvent(drone__remoteConsole, TryUseItem(userEid = human_eid))
      return true
    return false
