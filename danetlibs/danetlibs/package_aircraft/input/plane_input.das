require ecs
require ecs.safe
require DngPlane
require Plane
require DagorInput
require GamePhys
require DagorMath
require DagorConsole
require DagorSystem
require quirrel
require strings

[es(tag=input, on_appear, track=plane_input__mouseAimEnabled)]
def track_mouse_aim_enabled_es_event_handler(evt : Event;
                                             plane_net_phys : PlaneActor;
                                             plane_input__mouseAimEnabled : bool;
                                             var plane_input : PlaneInput&;
                                             var plane_input__simpleJoyEnabled : bool&)
  if plane_input__mouseAimEnabled
    var bank = 0.0f
    quat_to_euler(plane_net_phys.phys.visualLocation.O.quat, plane_input.mouseAimAng.x, plane_input.mouseAimAng.y, bank)
    plane_input__simpleJoyEnabled = false


[es(tag=input, after=track_mouse_aim_enabled_es_event_handler, on_appear, on_disappear, track=plane_input__simpleJoyEnabled)]
def track_simple_joy_enabled_es_event_handler(evt : Event;
                                              plane_input__simpleJoyEnabled : bool;
                                              var plane_input__mouseAimEnabled : bool&;
                                              var plane_input__aileronsAxis : float&;
                                              var plane_input__elevatorAxis : float&)
  plane_input__aileronsAxis = 0.0f
  plane_input__elevatorAxis = 0.0f
  if plane_input__simpleJoyEnabled
    plane_input__mouseAimEnabled = false


[es(tag=input, on_event=EventDaInputActionTriggered)]
def plane_input_auto_disable_mouseaim_es_event_handler(evt : Event;
                                                       plane_input__autoDisableMouseAim : bool;
                                                       var plane_input : PlaneInput&;
                                                       var plane_input__mouseAimEnabled : bool&)
  let mask = get_last_used_device_mask()
  if plane_input__autoDisableMouseAim && ((mask & DEV_USED_gamepad) != 0u)
    get_difficulty().isAutotrimEnabled = false
    plane_input.instructorAutoTrimEnabled = false
    plane_input.instructorStickPusherEnabled = false
    plane_input__mouseAimEnabled = false

[es(tag=input, on_disappear)]
def plane_input_save_throttle_es(evt : Event;
                                 plane_input : PlaneInput;
                                 var plane__savedThrottleValue : float&)
  plane__savedThrottleValue = get_analog_axis_action_state(plane_input.aThrottle).x


[es(tag=input, on_appear)]
def plane_input_init_throttle_es_event_handler(evt : Event;
                                               plane__savedThrottleValue : float;
                                               plane__roughThrottleOverride : float = -1f;
                                               startRelativeSpeed : float;
                                               var plane_input : PlaneInput&)
  var roughThrottle = plane__savedThrottleValue
  if plane__savedThrottleValue == -1.f
    roughThrottle = plane__roughThrottleOverride == -1.f ? sqrt(clamp(startRelativeSpeed, 0.0f, 1.0f)) : plane__roughThrottleOverride * THROTTLE_WEP_MAX
  plane_input.throttle = roughThrottle
  set_analog_axis_action_state(plane_input.aThrottle, roughThrottle)
