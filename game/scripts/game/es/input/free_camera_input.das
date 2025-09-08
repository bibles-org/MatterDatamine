require ecs
require DagorInput
require game.events.input_events
require game.events.events
require game.events.events_active_matter
require danetlibs.renderer.includes.render_events


def private init_actions(var free_camera_input__moveXZ : uint16&;
                         var free_camera_input__rotate : uint16&;
                         var free_camera_input__moveY : uint16&;
                         var free_camera_input__zoomIn : uint16&;
                         var free_camera_input__zoomOut : uint16&;
                         var free_camera_input__turbo : uint16&;
                         var free_camera_input__speedUp : uint16&;
                         var free_camera_input__speedDown : uint16&;
                         var free_camera_input__speedReset : uint16&;
                         var free_camera_input__bank : uint16&;
                         var free_camera_input__toggleDir : uint16&;
                         var free_camera_input__resetRoll : uint16&;
                         var free_camera_input__dash : uint16&)
  free_camera_input__moveXZ = get_action_handle("Camera.Move", TYPEGRP_STICK)
  free_camera_input__rotate = get_action_handle("Camera.Rotate", TYPEGRP_STICK)
  free_camera_input__moveY = get_action_handle("Camera.ShiftY", TYPEGRP_AXIS)
  free_camera_input__turbo = get_action_handle("Camera.Turbo", TYPEGRP_AXIS)
  free_camera_input__zoomIn = get_action_handle("Camera.ZoomIn", TYPEGRP_DIGITAL)
  free_camera_input__zoomOut = get_action_handle("Camera.ZoomOut", TYPEGRP_DIGITAL)
  free_camera_input__speedUp = get_action_handle("Camera.SpeedUp", TYPEGRP_DIGITAL)
  free_camera_input__speedDown = get_action_handle("Camera.SpeedDown", TYPEGRP_DIGITAL)
  free_camera_input__speedReset = get_action_handle("Camera.SpeedReset", TYPEGRP_DIGITAL)
  free_camera_input__bank = get_action_handle("Camera.Bank", TYPEGRP_AXIS)
  free_camera_input__toggleDir = get_action_handle("Camera.ToggleDir", TYPEGRP_DIGITAL)
  free_camera_input__resetRoll = get_action_handle("Camera.ResetRoll", TYPEGRP_DIGITAL)
  free_camera_input__dash = get_action_handle("Camera.Dash", TYPEGRP_DIGITAL)


def private reset_actions(var free_camera_input__moveXZ : uint16&;
                          var free_camera_input__rotate : uint16&;
                          var free_camera_input__moveY : uint16&;
                          var free_camera_input__zoomIn : uint16&;
                          var free_camera_input__zoomOut : uint16&;
                          var free_camera_input__turbo : uint16&;
                          var free_camera_input__speedUp : uint16&;
                          var free_camera_input__speedDown : uint16&;
                          var free_camera_input__speedReset : uint16&;
                          var free_camera_input__bank : uint16&;
                          var free_camera_input__toggleDir : uint16&;
                          var free_camera_input__resetRoll : uint16&;
                          var free_camera_input__dash : uint16&)
  free_camera_input__moveXZ = BAD_ACTION_HANDLE
  free_camera_input__rotate = BAD_ACTION_HANDLE
  free_camera_input__moveY = BAD_ACTION_HANDLE
  free_camera_input__zoomIn = BAD_ACTION_HANDLE
  free_camera_input__zoomOut = BAD_ACTION_HANDLE
  free_camera_input__turbo = BAD_ACTION_HANDLE
  free_camera_input__speedUp = BAD_ACTION_HANDLE
  free_camera_input__speedDown = BAD_ACTION_HANDLE
  free_camera_input__speedReset = BAD_ACTION_HANDLE
  free_camera_input__bank = BAD_ACTION_HANDLE
  free_camera_input__toggleDir = BAD_ACTION_HANDLE
  free_camera_input__resetRoll = BAD_ACTION_HANDLE
  free_camera_input__dash = BAD_ACTION_HANDLE


[es(tag=input)]
def free_camera_input_init_es(evt : EventDaInputInit;
                              var free_camera_input__moveXZ : uint16&;
                              var free_camera_input__rotate : uint16&;
                              var free_camera_input__moveY : uint16&;
                              var free_camera_input__zoomIn : uint16&;
                              var free_camera_input__zoomOut : uint16&;
                              var free_camera_input__turbo : uint16&;
                              var free_camera_input__speedUp : uint16&;
                              var free_camera_input__speedDown : uint16&;
                              var free_camera_input__speedReset : uint16&;
                              var free_camera_input__bank : uint16&;
                              var free_camera_input__toggleDir : uint16&;
                              var free_camera_input__resetRoll : uint16&;
                              var free_camera_input__dash : uint16&)
  if evt.init
    init_actions(
      free_camera_input__moveXZ,
      free_camera_input__rotate,
      free_camera_input__moveY,
      free_camera_input__zoomIn,
      free_camera_input__zoomOut,
      free_camera_input__turbo,
      free_camera_input__speedUp,
      free_camera_input__speedDown,
      free_camera_input__speedReset,
      free_camera_input__bank,
      free_camera_input__toggleDir,
      free_camera_input__resetRoll,
      free_camera_input__dash)
  else
    reset_actions(
      free_camera_input__moveXZ,
      free_camera_input__rotate,
      free_camera_input__moveY,
      free_camera_input__zoomIn,
      free_camera_input__zoomOut,
      free_camera_input__turbo,
      free_camera_input__speedUp,
      free_camera_input__speedDown,
      free_camera_input__speedReset,
      free_camera_input__bank,
      free_camera_input__toggleDir,
      free_camera_input__resetRoll,
      free_camera_input__dash)


[es(tag=input, on_appear)]
def free_camera_input_appear_es(evt : Event;
                                var free_camera_input__moveXZ : uint16&;
                                var free_camera_input__rotate : uint16&;
                                var free_camera_input__moveY : uint16&;
                                var free_camera_input__zoomIn : uint16&;
                                var free_camera_input__zoomOut : uint16&;
                                var free_camera_input__turbo : uint16&;
                                var free_camera_input__speedUp : uint16&;
                                var free_camera_input__speedDown : uint16&;
                                var free_camera_input__speedReset : uint16&;
                                var free_camera_input__bank : uint16&;
                                var free_camera_input__toggleDir : uint16&;
                                var free_camera_input__resetRoll : uint16&;
                                var free_camera_input__dash : uint16&)
  init_actions(
    free_camera_input__moveXZ,
    free_camera_input__rotate,
    free_camera_input__moveY,
    free_camera_input__zoomIn,
    free_camera_input__zoomOut,
    free_camera_input__turbo,
    free_camera_input__speedUp,
    free_camera_input__speedDown,
    free_camera_input__speedReset,
    free_camera_input__bank,
    free_camera_input__toggleDir,
    free_camera_input__resetRoll,
    free_camera_input__dash)


[es(tag=input, on_disappear)]
def free_camera_input_disappear_es(evt : Event;
                                   var free_camera_input__moveXZ : uint16&;
                                   var free_camera_input__rotate : uint16&;
                                   var free_camera_input__moveY : uint16&;
                                   var free_camera_input__zoomIn : uint16&;
                                   var free_camera_input__zoomOut : uint16&;
                                   var free_camera_input__turbo : uint16&;
                                   var free_camera_input__speedUp : uint16&;
                                   var free_camera_input__speedDown : uint16&;
                                   var free_camera_input__speedReset : uint16&;
                                   var free_camera_input__bank : uint16&;
                                   var free_camera_input__toggleDir : uint16&;
                                   var free_camera_input__resetRoll : uint16&;
                                   var free_camera_input__dash : uint16&)
  reset_actions(
    free_camera_input__moveXZ,
    free_camera_input__rotate,
    free_camera_input__moveY,
    free_camera_input__zoomIn,
    free_camera_input__zoomOut,
    free_camera_input__turbo,
    free_camera_input__speedUp,
    free_camera_input__speedDown,
    free_camera_input__speedReset,
    free_camera_input__bank,
    free_camera_input__toggleDir,
    free_camera_input__resetRoll,
    free_camera_input__dash)


[es(tag=input, before=free_camera_update)]
def free_camera_input_es(info : UpdateStageInfoBeforeRender;
                         camera__input_enabled : bool;
                         camera__active : bool;
                         free_camera_input__moveXZ : uint16;
                         free_camera_input__turbo : uint16;
                         free_camera_input__rotate : uint16;
                         free_camera_input__bank : uint16;
                         free_camera_input__moveY : uint16;
                         var free_camera__move : float3&;
                         var free_camera__turboMode : bool&;
                         var free_camera__rotate : float3&)
  if !camera__active || !camera__input_enabled
    return

  let moveXZ = get_analog_stick_action_state(free_camera_input__moveXZ)
  let moveY = get_analog_axis_action_state(free_camera_input__moveY)
  free_camera__move = float3(moveXZ.x, moveY.x, moveXZ.y)

  let turbo = get_analog_axis_action_state(free_camera_input__turbo)
  free_camera__turboMode = turbo.x > 0.0

  let rotate = get_analog_stick_action_state(free_camera_input__rotate)
  let turn = get_analog_axis_action_state(free_camera_input__bank)
  free_camera__rotate = float3(turn.x, rotate.x, rotate.y)


[es(tag=input, no_order)]
def free_camera_update_fov_input_es(info : ParallelUpdateFrameDelayed;
                                    free_camera_input__zoomIn : uint16;
                                    free_camera_input__zoomOut : uint16;
                                    camera__active : bool;
                                    free_camera__zoomInertia : float;
                                    free_camera__zoomSpeed : float;
                                    var free_camera__zoomLinVel : float&;
                                    var fov : float&)
  if !camera__active
    free_camera__zoomLinVel = 0.
    return

  var fovDir = 0
  if is_action_active(free_camera_input__zoomIn) && get_digital_action_state(free_camera_input__zoomIn).bState
    fovDir = 1
  elif is_action_active(free_camera_input__zoomOut) && get_digital_action_state(free_camera_input__zoomOut).bState
    fovDir = -1

  assume inertion = free_camera__zoomInertia
  free_camera__zoomLinVel = free_camera__zoomLinVel * inertion + float(fovDir) * (free_camera__zoomSpeed * (1. - inertion))
  free_camera__zoomLinVel
  if abs(free_camera__zoomLinVel) > 1.0E-5
    fov += free_camera__zoomLinVel * 1. / 60.
    fov = clamp(fov, 10., 130.)


[es(tag=input)]
def free_camera_input_action_es(evt : EventDaInputActionTriggered;
                                eid : EntityId;
                                free_camera_input__speedUp : uint16;
                                free_camera_input__speedDown : uint16;
                                free_camera_input__speedReset : uint16;
                                free_camera_input__dash : uint16;
                                free_camera_input__resetRoll : uint16;
                                free_camera__moveSpeedDefault : float;
                                var free_camera__upVector : float3&;
                                var free_camera__moveSpeed : float&;
                                free_camera__moveSpeedChangeFactor = 1.03)
  if evt.action == free_camera_input__speedUp
    free_camera__moveSpeed *= pow(free_camera__moveSpeedChangeFactor, 1.)
  elif evt.action == free_camera_input__speedDown
    free_camera__moveSpeed *= pow(free_camera__moveSpeedChangeFactor, -1.)
  elif evt.action == free_camera_input__speedReset
    free_camera__moveSpeed = free_camera__moveSpeedDefault
  elif evt.action == free_camera_input__dash
    sendEvent(eid, CmdCameraDash())
  elif evt.action == free_camera_input__resetRoll
    free_camera__upVector = float3(0.0, 1.0, 0.0)


[es(tag=input)]
def free_camera_toggle_direction_es(evt : EventDaInputActionTriggered;
                                    transform : float3x4;
                                    free_camera_input__toggleDir : uint16;
                                    var free_camera__useFixedDirection : bool&;
                                    var free_camera__fixedDirection : float3&)
  if evt.action == free_camera_input__toggleDir
    free_camera__useFixedDirection = !free_camera__useFixedDirection
    free_camera__fixedDirection = free_camera__useFixedDirection ? transform[0] : float3()