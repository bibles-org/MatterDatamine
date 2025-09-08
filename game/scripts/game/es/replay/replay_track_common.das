module replay_track_common shared
require ecs
require ecs.common
require ecs.soa_template


[soa_template]
struct KeyFrame
  replay_track__time : float
  replay_track__position : float3
  replay_track__direction : float3
  replay_track__up : float3
  replay_track__roll : float
  replay_track__fov : float


[soa_template]
struct PostProductionEntity
  replay_post_production__creationTime : float
  replay_post_production__template : string
  replay_post_production__transform : float3x4
  replay_post_production__isAutoDestroy : bool


def keyFrameToString(index : int; time : float; position, direction, up : float3; roll : float; fov : float)
  return "KeyFrame[{index}] time:{time}; position:({position}); direction:({direction}); up:({up}; roll:({roll}); fov:({fov}))"


[soa_def]
def keyFrameToString(keyFrames : KeyFrame_SOA;
                     index : int)
  let keyFrameIsExists = 0 <= index && index < length(keyFrames)
  return keyFrameIsExists ? keyFrameToString(index,
                                             keyFrames[index].replay_track__time,
                                             keyFrames[index].replay_track__position,
                                             keyFrames[index].replay_track__direction,
                                             keyFrames[index].replay_track__up,
                                             keyFrames[index].replay_track__roll,
                                             keyFrames[index].replay_track__fov) : "KeyFrame[{index}] doesn't exists"

def make_bezier_directors(xm, x0, x1, xp : auto(TT); var r0, r1 : TT&; smooth : float)
  let g1 = lerp(x0, xm, -smooth)
  let g2 = lerp(x0, x1, smooth)
  let g3 = lerp(g1, g2, 0.5f)
  let u1 = lerp(x1, x0, -smooth)
  let u2 = lerp(x1, xp, smooth)
  let u3 = lerp(u1, u2, 0.5f)
  r0 = g3 // = lerp(x0, g3, 1)
  r1 = lerp(x1, u3, -1.0f)

def bezier_interp4(x0, x1, x2, x3 : auto(TT); t : float)
  let q0 = lerp(x0, x1, t)
  let q1 = lerp(x1, x2, t)
  let q2 = lerp(x2, x3, t)
  let r0 = lerp(q0, q1, t)
  let r1 = lerp(q1, q2, t)
  return lerp(r0, r1, t)
