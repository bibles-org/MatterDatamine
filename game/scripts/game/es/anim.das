require ecs
require app
require math.base
require DagorMath
require game.events.events_game


// TODO: it is necessary to completely transfer keyTrackAnim to das,
// it is inappropriate to create a module
enum AnimType
  ANIM_SINGLE
  ANIM_CYCLIC
  ANIM_EXTRAPOLATED


[es(on_appear, track=(ang_speed_yaw, ang_speed_pitch, ang_speed_roll, local_space, ri_motion__enabled), REQUIRE=set_rotation)]
def set_rotation_es(evt : Event;
                    eid : EntityId;
                    ang_speed_yaw, ang_speed_pitch, ang_speed_roll : float;
                    local_space : bool;
                    transform : float3x4 const?;
                    ri_motion__enabled : bool = true)
  let start = float3(0.0)
  var end = ri_motion__enabled ? float3(ang_speed_yaw * DEG_TO_RAD, ang_speed_pitch * DEG_TO_RAD, ang_speed_roll * DEG_TO_RAD) : start
  let endLen = length(end)
  var endScale = 1.0
  if (endLen > 1.0)
    endScale = (1.0 / (endLen * 10.0 + 0.00001))
    end *= endScale

  var startQuat, endQuat : quat
  euler_to_quat(start.x, start.y, start.z, startQuat)
  euler_to_quat(end.x, end.y, end.z, endQuat)

  if local_space && transform != null
    let initialRotationQuat = DagorMath::quat(*transform) |> normalize()
    startQuat = initialRotationQuat * startQuat
    endQuat = initialRotationQuat * endQuat

  let startTime = max(0.0, get_sync_time())
  if endLen > 0.0
    sendEvent(eid, CmdResetRotAnim(firstKey = float4(startQuat), firstKeyTime = startTime, animType = int(AnimType.ANIM_EXTRAPOLATED)))
    sendEvent(eid, CmdAddRotAnim(firstKey = float4(endQuat), firstKeyTime = endScale, useAdditionalTime = true))
  else
    sendEvent(eid, CmdResetRotAnim(firstKey = float4(startQuat), firstKeyTime = startTime, animType = int(AnimType.ANIM_SINGLE)))
