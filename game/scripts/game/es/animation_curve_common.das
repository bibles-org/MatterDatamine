module animation_curve_common shared
require ecs
require ecs.safe
require math.base


def animation_curve_evaluate(curve : Array;
                             time : float;
                             evalute_fn : block<(keyframe0 : Object; keyframe1 : Object; time : float) : float>)
  let curveKeyframes = length(curve)
  if curveKeyframes == 0
    return 0.0

  assume firstKeyframe = curve[0] as Object
  if time <= firstKeyframe?.t ?? 0.0
    return firstKeyframe?.v ?? 0.0

  assume lastKeyframe = curve[curveKeyframes - 1] as Object
  if time >= lastKeyframe?.t ?? 0.0
    return lastKeyframe?.v ?? 0.0

  for i in range(1, length(curve))
    assume keyframe = curve[i] as Object
    if keyframe?.t ?? 0.0 > time
      assume prevKeyframe = curve[i - 1] as Object

      return invoke(evalute_fn, *prevKeyframe, *keyframe, time)

  return firstKeyframe?.v ?? 0.0


def animation_curve_evaluate_smooth(curve : Array;
                                    time : float)
  return animation_curve_evaluate(curve, time) <| $(keyframe0 : Object;
                                                    keyframe1 : Object;
                                                    keyTime : float)
    let time0 = keyframe0.t ?? 0.0
    let time1 = keyframe1.t ?? 0.0

    let value0 = keyframe0.v ?? 0.0
    let value1 = keyframe1.v ?? 0.0

    let outTangent0 = (keyframe0.tan ?? float2(0.0)).y
    let inTangent1 = (keyframe1.tan ?? float2(0.0)).x

    let dt = time1 - time0
    let t = (keyTime - time0) / dt


    let m0 = outTangent0 * dt
    let m1 = inTangent1 * dt

    let t2 = square(t)
    let t3 = t2 * t

    let a = 2.0 * t3 - 3.0 * t2 + 1.0
    let b = t3 - 2.0 * t2 + t
    let c = t3 - t2
    let d = -2.0 * t3 + 3.0 * t2

    return a * value0 + b * m0 + c * m1 + d * value1


def animation_curve_evaluate_linear(curve : Array;
                                    time : float)
  return animation_curve_evaluate(curve, time) <| $(keyframe0 : Object;
                                                    keyframe1 : Object;
                                                    keyTime : float)
    let time0 = keyframe0.t ?? 0.0
    let time1 = keyframe1.t ?? 0.0

    let value0 = keyframe0.v ?? 0.0
    let value1 = keyframe1.v ?? 0.0

    let dt = time1 - time0
    let t = (keyTime - time0) / dt

    return lerp(value0, value1, t)


def animation_curve_evaluate_fixed(curve : Array;
                                   time : float)
  return animation_curve_evaluate(curve, time) <| $[unused_argument(keyframe0, keyTime)] (keyframe0 : Object;
                                                                                          keyframe1 : Object;
                                                                                          keyTime : float)
    let value1 = keyframe1.v ?? 0.0
    return value1