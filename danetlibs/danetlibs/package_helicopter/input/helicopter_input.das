require ecs
require math.base
require math.ang
require GamePhys
require DagorMath
require DagorMathUtils
require DagorInput
require DngHelicopter
require TouchInput


[cpp_event(broadcast)]
struct UpdateStageUpdateInput
  curTime : float
  dt : float


[cpp_event(broadcast)]
struct EventDaInputInit
  init : bool


def init(helicopter_input__mouseAimEnabled : bool;
         var helicopter_input__aNose : int&;
         var helicopter_input__aRoll : int&;
         var helicopter_input__aYaw : int&;
         var helicopter_input__aFly : int&;
         var helicopter_input__aMouseAim : int&;
         var helicopter_input__aTouchAim : int&)
  helicopter_input__aNose = int(get_action_handle("Helicopter.Nose", TYPEGRP_AXIS))
  helicopter_input__aRoll = int(get_action_handle("Helicopter.Roll", TYPEGRP_AXIS))
  helicopter_input__aYaw = int(get_action_handle("Helicopter.Yaw", TYPEGRP_AXIS))
  helicopter_input__aFly = int(get_action_handle("Helicopter.Fly", TYPEGRP_AXIS))
  helicopter_input__aMouseAim = int(get_action_handle("HelicopterMouse.MouseAim", TYPEGRP_STICK))
  helicopter_input__aTouchAim = int(get_action_handle("HelicopterTouch.TouchAim", TYPEGRP_STICK))
  activate_action_set(get_action_set_handle("Helicopter"), true)

  if helicopter_input__mouseAimEnabled
    activate_action_set(get_action_set_handle("HelicopterMouse"), true)


def reset(helicopter_input__mouseAimEnabled : bool;
          var helicopter_input__aNose : int&;
          var helicopter_input__aRoll : int&;
          var helicopter_input__aYaw : int&;
          var helicopter_input__aFly : int&;
          var helicopter_input__aMouseAim : int&;
          var helicopter_input__aTouchAim : int&)
  helicopter_input__aNose = int(BAD_ACTION_HANDLE)
  helicopter_input__aRoll = int(BAD_ACTION_HANDLE)
  helicopter_input__aYaw = int(BAD_ACTION_HANDLE)
  helicopter_input__aFly = int(BAD_ACTION_HANDLE)
  helicopter_input__aMouseAim = int(BAD_ACTION_HANDLE)
  helicopter_input__aTouchAim = int(BAD_ACTION_HANDLE)
  activate_action_set(get_action_set_handle("Helicopter"), false)

  if helicopter_input__mouseAimEnabled
    activate_action_set(get_action_set_handle("HelicopterMouse"), false)


def apply_ctrl_state(keyboard_accum_roll : float;
                     keyboard_accum_pitch : float;
                     keyboard_accum_yaw : float;
                     keyboard_accum_throttle : float;
                     var phys : HelicopterActor)
  assume ct = phys.phys.producedCT
  assume orient = phys.phys.currentState.location.O

  // prevent pitching too much and rolling too much
  let rollOffset = cvt(orient.roll, -45.0, 45.0, 1.0, -1.0)
  let pitchOffset = cvt(orient.pitch, -30.0, 30.0, -1.0, 1.0)

  ct.pitch = clamp(keyboard_accum_pitch, -1.0 + pitchOffset, 1.0 + pitchOffset)
  ct.roll = clamp(keyboard_accum_roll, -1.0 + rollOffset, 1.0 + rollOffset)
  ct.yaw = keyboard_accum_yaw

  ct.relativePower = (keyboard_accum_throttle + 1.0) * 0.5


[es(tag=input, on_appear)]
def helicopter_input_on_appear(evt : Event;
                               helicopter_input__wishLookDir : float3;
                               helicopter_input__mouseAimEnabled : bool;
                               var helicopter_input__aNose : int&;
                               var helicopter_input__aRoll : int&;
                               var helicopter_input__aYaw : int&;
                               var helicopter_input__aFly : int&;
                               var helicopter_input__aMouseAim : int&;
                               var helicopter_input__aTouchAim : int&;
                               var helicopter_input__mouseAimXY : float2&)
  init(helicopter_input__mouseAimEnabled, helicopter_input__aNose, helicopter_input__aRoll, helicopter_input__aYaw, helicopter_input__aFly, helicopter_input__aMouseAim, helicopter_input__aTouchAim)

  if helicopter_input__mouseAimEnabled
    helicopter_input__mouseAimXY = dir_to_sph_ang(helicopter_input__wishLookDir)
    helicopter_input__mouseAimXY.x = PI * 0.5 - helicopter_input__mouseAimXY.x


[es(tag=input, on_disappear)]
def helicopter_input_on_disappear(evt : Event;
                                  helicopter_input__mouseAimEnabled : bool;
                                  var helicopter_input__aNose : int&;
                                  var helicopter_input__aRoll : int&;
                                  var helicopter_input__aYaw : int&;
                                  var helicopter_input__aFly : int&;
                                  var helicopter_input__aMouseAim : int&;
                                  var helicopter_input__aTouchAim : int&)
  reset(helicopter_input__mouseAimEnabled, helicopter_input__aNose, helicopter_input__aRoll, helicopter_input__aYaw, helicopter_input__aFly, helicopter_input__aMouseAim, helicopter_input__aTouchAim)


[es(tag=input)]
def helicopter_input_on_dainput_init(evt : EventDaInputInit;
                                     helicopter_input__mouseAimEnabled : bool;
                                     var helicopter_input__aNose : int&;
                                     var helicopter_input__aRoll : int&;
                                     var helicopter_input__aYaw : int&;
                                     var helicopter_input__aFly : int&;
                                     var helicopter_input__aMouseAim : int&;
                                     var helicopter_input__aTouchAim : int&)
  if evt.init
    init(helicopter_input__mouseAimEnabled, helicopter_input__aNose, helicopter_input__aRoll, helicopter_input__aYaw, helicopter_input__aFly, helicopter_input__aMouseAim, helicopter_input__aTouchAim)
  else
    reset(helicopter_input__mouseAimEnabled, helicopter_input__aNose, helicopter_input__aRoll, helicopter_input__aYaw, helicopter_input__aFly, helicopter_input__aMouseAim, helicopter_input__aTouchAim)


[es(tag=input, no_order)]
def helicopter_input_update_dir_es(info : UpdateStageInfoAct;
                                   helicopter_input__mouseAimXY : float2;
                                   var helicopter_input__wishLookDir : float3&)
  let ang = float2(PI * 0.5 - helicopter_input__mouseAimXY.x, helicopter_input__mouseAimXY.y)
  helicopter_input__wishLookDir = sph_ang_to_dir(ang)


[es(tag=input, on_disappear, before=helicopter_input_reset_es)]
def helicopter_idle_reset_es(evt : Event;
                             helicopter_input__mouseAimXY : float2;
                             var helicopter_idle__mouseAim : float2&)
  helicopter_idle__mouseAim = helicopter_input__mouseAimXY


[es(tag=input, on_event=(EventOnEntityReset, EventComponentsDisappear))]
def helicopter_input_reset_es(evt : Event;
                              helicopter_input__keyboardAccumRoll : float;
                              helicopter_input__keyboardAccumPitch : float;
                              helicopter_input__keyboardAccumYaw : float;
                              helicopter_input__keyboardAccumThrottle : float;
                              var helicopter_net_phys : HelicopterActor;
                              var helicopter_input__mouseAimXY : float2&)
  helicopter_input__mouseAimXY = float2(0.0)
  apply_ctrl_state(helicopter_input__keyboardAccumRoll, helicopter_input__keyboardAccumPitch, helicopter_input__keyboardAccumYaw, helicopter_input__keyboardAccumThrottle, helicopter_net_phys)


[es(tag=input)]
def helicopter_input_es(info : UpdateStageUpdateInput;
                        helicopter_input__aNose : int;
                        helicopter_input__aRoll : int;
                        helicopter_input__aYaw : int;
                        helicopter_input__aFly : int;
                        helicopter_input__aMouseAim : int;
                        helicopter_input__aTouchAim : int;
                        helicopter_drone_speed_control__pitch : float = 0.0;
                        helicopter_input__pitchFeedbackMult : float = 0.01;
                        helicopter_input__rollFeedbackMult : float = 0.01;
                        helicopter_input__yawMouseFeedbackMult : float = 0.01;
                        helicopter_input__rollMouseFeedbackMult : float = 0.01;
                        helicopter_input__throttleMouseFeedbackMult : float = 0.01;
                        helicopter_input__yawPropMult : float = 1.0;
                        helicopter_input__yawDiffMult : float = 1.0;
                        helicopter_input__rollPropMult : float = 1.0;
                        helicopter_input__rollDiffMult : float = 1.0;
                        helicopter_input__throttlePropMult : float = 1.0;
                        helicopter_input__throttleDiffMult : float = 1.0;
                        helicopter_input__vertLookAngle : float = 45.0;
                        helicopter_input__mouseAimEnabled : bool = false;
                        helicopter_input__mouseAimYawEnabled : bool = true;
                        helicopter_input__mouseAimRollEnabled : bool = false;
                        helicopter_input__mouseAimThrottleEnabled : bool = false;
                        var helicopter_net_phys : HelicopterActor;
                        var helicopter_input__isActionNoseActive : bool&;
                        var helicopter_input__keyboardAccumRoll : float&;
                        var helicopter_input__keyboardAccumPitch : float&;
                        var helicopter_input__keyboardAccumYaw : float&;
                        var helicopter_input__keyboardAccumThrottle : float&;
                        var helicopter_input__mouseAimXY : float2&)
  assume orient = helicopter_net_phys.phys.currentState.location.O

  let touchStickVal = helicopter_input__aTouchAim != int(BAD_ACTION_HANDLE) ? get_stick_value(uint16(helicopter_input__aTouchAim)) : float2(0.0)
  let aRoll = get_analog_axis_action_state(uint16(helicopter_input__aRoll)).x + get_axis_value(uint16(helicopter_input__aRoll))
  let aPitch = get_analog_axis_action_state(uint16(helicopter_input__aNose)).x + get_axis_value(uint16(helicopter_input__aNose)) + -touchStickVal.y
  let aYaw = get_analog_axis_action_state(uint16(helicopter_input__aYaw)).x + get_axis_value(uint16(helicopter_input__aYaw)) + touchStickVal.x
  let aFly = get_analog_axis_action_state(uint16(helicopter_input__aFly)).x + get_axis_value(uint16(helicopter_input__aFly))

  helicopter_input__isActionNoseActive = get_analog_axis_action_state(uint16(helicopter_input__aNose)).x != 0.0

  var wishYaw = aYaw
  let wishPitch = helicopter_drone_speed_control__pitch + aPitch + orient.pitch * helicopter_input__pitchFeedbackMult
  var wishRoll = aRoll + orient.roll * helicopter_input__rollFeedbackMult
  var wishThrottle = aFly

  if helicopter_input__mouseAimEnabled
    let aim = get_analog_stick_action_state(uint16(helicopter_input__aMouseAim))
    let aimXY = float2(touchStickVal.x + aim.x, touchStickVal.y + aim.y)
    helicopter_input__mouseAimXY.x = norm_ang(helicopter_input__mouseAimXY.x - aimXY.x * get_sens_scale_vehicle())
    // TODO: rework, so no +90 deg is needed...
    let proportionalHorz = helicopter_input__mouseAimXY.x - renorm_ang(deg_to_rad(orient.yaw), helicopter_input__mouseAimXY.x)
    let differentialHorz = helicopter_net_phys.phys.currentState.omega.y
    if helicopter_input__mouseAimYawEnabled
      wishYaw = (proportionalHorz * helicopter_input__yawPropMult + differentialHorz * helicopter_input__yawDiffMult) * helicopter_input__yawMouseFeedbackMult

    if helicopter_input__mouseAimRollEnabled
      wishRoll += (proportionalHorz * helicopter_input__rollPropMult + differentialHorz * helicopter_input__rollDiffMult) * helicopter_input__rollMouseFeedbackMult

    let vertLookAngle = deg_to_rad(helicopter_input__vertLookAngle)
    helicopter_input__mouseAimXY.y = clamp(helicopter_input__mouseAimXY.y + aimXY.y * get_sens_scale_vehicle(), -vertLookAngle, vertLookAngle)

    if helicopter_input__mouseAimThrottleEnabled
      let proportionalThrottle = (helicopter_input__mouseAimXY.y / vertLookAngle) * helicopter_input__throttlePropMult
      let differentialThrottle = -helicopter_net_phys.phys.currentState.acceleration.y * helicopter_input__throttleDiffMult
      wishThrottle += (proportionalThrottle + differentialThrottle) * helicopter_input__throttleMouseFeedbackMult * -sign(aPitch)

  helicopter_input__keyboardAccumYaw = move_to(helicopter_input__keyboardAccumYaw, wishYaw, info.dt, 4.0)
  helicopter_input__keyboardAccumPitch = move_to(helicopter_input__keyboardAccumPitch, wishPitch, info.dt, 4.0)
  helicopter_input__keyboardAccumRoll = move_to(helicopter_input__keyboardAccumRoll, wishRoll, info.dt, 4.0)
  helicopter_input__keyboardAccumThrottle = move_to(helicopter_input__keyboardAccumThrottle, wishThrottle, info.dt, 8.0)

  apply_ctrl_state(helicopter_input__keyboardAccumRoll, helicopter_input__keyboardAccumPitch, helicopter_input__keyboardAccumYaw, helicopter_input__keyboardAccumThrottle, helicopter_net_phys)
