require ecs
require ecs.safe
require math.ang
require math.base
require game.events.events_active_matter
require DagorMath
require DagorRandom
require DagorSystem


[es(tag=gameClient, on_appear)]
def euclid_anomaly_visual_init(evt : Event;
                               eid : EntityId;
                               euclid_anomaly_visual__subObjects : Array;
                               transform : float3x4;
                               var animchar_render__dist_sq : float&)
  animchar_render__dist_sq = square(3000.0)
  for item in euclid_anomaly_visual__subObjects
    let itemObj = item as Object
    if itemObj != null
      if (itemObj?.creationTemplate ?? "") == "sphere"
        let countOnEquator = itemObj?.count ?? 0
        let templateName = itemObj?.templateName ?? ""
        if countOnEquator == 0 || templateName == ""
          continue
        let meridianDeltaAngle = PI / float(countOnEquator)
        for i in range(0, countOnEquator)
          let countOnMeridian = max(1, int(float(countOnEquator) * sin(PI * float(i) / float(countOnEquator))))
          let parallelDeltaAngle = TWOPI / float(countOnMeridian)
          var sinM, cosM : float
          sincos(float(i) * meridianDeltaAngle, sinM, cosM)
          for j in range(0, countOnMeridian)
            var sinP,  cosP : float
            sincos(float(j) * parallelDeltaAngle, sinP, cosP)
            var tm := transform
            tm[1] = float3(sinM * cosP, sinM * sinP, cosM)
            tm[2] = cross(tm[1], transform[2])
            tm[0] = cross(tm[1], tm[2])
            createEntity(templateName) <| $(var init)
              init |> set("transform", tm)
              init |> set("euclid_anomaly_visual__parentEid", eid)
      else
        let count = itemObj?.count ?? 0
        let templateName = itemObj?.templateName ?? ""
        if count == 0 || templateName == ""
          continue
        createEntity(templateName) <| $(var init)
          init |> set("transform", transform)
          init |> set("euclid_anomaly_visual__parentEid", eid)


[es(tag=gameClient, track=transform, REQUIRE=euclid_anomaly_visual__subObjects)]
def euclid_anomaly_visual_move(evt : Event;
                               eid : EntityId;
                               transform aka parent_transform : float3x4)
  query() <| $ [es] (euclid_anomaly_visual__parentEid : EntityId; var transform : float3x4&)
    if euclid_anomaly_visual__parentEid == eid
      transform[3] = parent_transform[3]


[es(tag=gameClient, on_disappear, REQUIRE=euclid_anomaly_visual__subObjects)]
def euclid_anomaly_visual_destroy(evt : Event; eid aka parent_eid : EntityId)
  query() <| $ [es] (eid, euclid_anomaly_visual__parentEid : EntityId)
    if euclid_anomaly_visual__parentEid == parent_eid
      destroyEntity(eid)


[es(tag=gameClient, on_appear)]
def euclid_anomaly_visual_scale_anim_init(evt : Event;
                                          transform : float3x4;
                                          var euclid_anomaly_visual__scaleRng : float2&;
                                          var euclid_anomaly_visual__scaleAxisIdx : int&;
                                          var euclid_anomaly_visual__curScaleVal : float&;
                                          var euclid_anomaly_visual__scaleAxis : float3&;
                                          var animchar_render__dist_sq : float&)
  if euclid_anomaly_visual__scaleAxisIdx > 2
    logerr("[Euclid Anomaly Visual] euclid_anomaly_visual__scaleAxisIdx must be in range 0..2. Fallback to 1 (y).")
    euclid_anomaly_visual__scaleAxisIdx = 1
  if euclid_anomaly_visual__scaleRng.x > euclid_anomaly_visual__scaleRng.y
    logerr("[Euclid Anomaly Visual] euclid_anomaly_visual__scaleRng.x greater then y. Fallback to 0.3..1.")
    euclid_anomaly_visual__scaleRng = float2(0.3, 1.0)

  euclid_anomaly_visual__curScaleVal = rnd_float(0.0, TWOPI)
  euclid_anomaly_visual__scaleAxis = transform[euclid_anomaly_visual__scaleAxisIdx]

  animchar_render__dist_sq = square(3000.0)


[es(tag=gameClient)]
def euclid_anomaly_visual_scale_anim(evt : ParallelUpdateFrameDelayed;
                                     euclid_anomaly_visual__scaleAxis : float3;
                                     euclid_anomaly_visual__scaleRng : float2;
                                     euclid_anomaly_visual__scaleSpd : float;
                                     euclid_anomaly_visual__scaleAxisIdx : int;
                                     var euclid_anomaly_visual__curScaleVal : float&;
                                     var transform : float3x4&)
  euclid_anomaly_visual__curScaleVal += evt.dt * euclid_anomaly_visual__scaleSpd
  euclid_anomaly_visual__curScaleVal = norm_ang(euclid_anomaly_visual__curScaleVal)
  assume scaleRng = euclid_anomaly_visual__scaleRng
  let curScale = cvt(sin(euclid_anomaly_visual__curScaleVal), -1.0, 1.0, scaleRng.x, scaleRng.y)
  transform[euclid_anomaly_visual__scaleAxisIdx] = euclid_anomaly_visual__scaleAxis * curScale


[es(tag=gameClient, on_appear)]
def euclid_anomaly_visual_base_scale(evt : Event;
                                     euclid_anomaly_visual__totalScale : float;
                                     var transform : float3x4&)
  transform = scale_tm(euclid_anomaly_visual__totalScale)


[es(tag=gameClient)]
def euclid_anomaly_visual_rotate_anim(evt : ParallelUpdateFrameDelayed;
                                      euclid_anomaly_visual__rotateSpd : float;
                                      euclid_anomaly_visual__rotationAxisTime : float;
                                      var euclid_anomaly_visual__nextRotationAxisAt : float&;
                                      var euclid_anomaly_visual__curRotationAxisIdx : int&;
                                      var transform : float3x4&)
  if evt.curTime >= euclid_anomaly_visual__nextRotationAxisAt
    euclid_anomaly_visual__nextRotationAxisAt = evt.curTime + euclid_anomaly_visual__rotationAxisTime
    euclid_anomaly_visual__curRotationAxisIdx = rnd_int(0, 2)

  var eulerAngles : float3
  eulerAngles[euclid_anomaly_visual__curRotationAxisIdx] = norm_ang(evt.dt * euclid_anomaly_visual__rotateSpd)
  var rotationQuat : quat
  euler_to_quat(eulerAngles.y, eulerAngles.z, eulerAngles.x, rotationQuat)
  var rotationTm : float3x4
  make_tm(rotationQuat, rotationTm)
  transform = transform * rotationTm
