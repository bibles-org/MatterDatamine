require ecs
require app
require math
require math.base
require math.easing
require DagorMath
require DagorSystem
require DagorRandom
require game.events.events_active_matter


[es(on_appear)]
def static_sinusoidal_oscillation_init(evt : Event;
                                       transform : float3x4;
                                       static_sinusoidal_oscillation__generateSalt : bool;
                                       var static_sinusoidal_oscillation__origin : float3&;
                                       var static_sinusoidal_oscillation__salt : float&)
  static_sinusoidal_oscillation__origin = transform[3]
  if static_sinusoidal_oscillation__generateSalt
    static_sinusoidal_oscillation__salt = rnd_float(0.0, TWOPI)


[es(no_order)]
def static_sinusoidal_oscillation_update(act : ParallelUpdateFrameDelayed;
                                         static_sinusoidal_oscillation__frequency : float;
                                         static_sinusoidal_oscillation__amplitude : float;
                                         static_sinusoidal_oscillation__axis : float3;
                                         static_sinusoidal_oscillation__origin : float3;
                                         static_sinusoidal_oscillation__salt : float;
                                         var transform : float3x4)
  assume frequency = static_sinusoidal_oscillation__frequency
  assume amplitude = static_sinusoidal_oscillation__amplitude

  let oscillationValue = sin(act.curTime * frequency + static_sinusoidal_oscillation__salt) * amplitude
  let oscillationShift = oscillationValue * static_sinusoidal_oscillation__axis
  transform[3] = static_sinusoidal_oscillation__origin + oscillationShift


[es(no_order)]
def euler_sinusoidal_oscillation_update(act : ParallelUpdateFrameDelayed;
                                        euler_sinusoidal_oscillation__origin : float3;
                                        euler_sinusoidal_oscillation__amplitude : float3;
                                        euler_sinusoidal_oscillation__frequency : float3;
                                        var transform : float3x4;
                                        var euler_sinusoidal_oscillation__anglesLastUpdate : float3&)
  assume origin = euler_sinusoidal_oscillation__origin
  assume amplitude = euler_sinusoidal_oscillation__amplitude
  assume frequency = euler_sinusoidal_oscillation__frequency

  let oscillationValue = sin(act.curTime * frequency) * amplitude
  let oscillationAngles = oscillationValue + euler_sinusoidal_oscillation__origin
  let oscillationAnglesDelta = oscillationAngles - euler_sinusoidal_oscillation__anglesLastUpdate
  euler_sinusoidal_oscillation__anglesLastUpdate = oscillationAngles

  assume yaw = oscillationAnglesDelta.y
  assume pitch = oscillationAnglesDelta.z
  assume roll = oscillationAnglesDelta.x
  var q : quat
  var rotTm : float3x4
  euler_to_quat(yaw, pitch, roll, q)
  make_tm(q, rotTm)
  transform = transform * rotTm