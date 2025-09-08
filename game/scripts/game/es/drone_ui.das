require ecs
require game.events.events_active_matter
require game.utils.team
require DagorMath


[es(tag=render, no_order, REQUIRE=drone__view)]
def drone_camera_interference(info : ParallelUpdateFrameDelayed;
                              transform aka drone_transform : float3x4;
                              drone_crash__isCrashed : bool;
                              drone__owner : EntityId;
                              drone__attachedCam : EntityId;
                              drone__coverageArea : float2;
                              drone__interference : float2)
  if drone_crash__isCrashed
    return
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    query(drone__attachedCam) <| $ [es] (var vhs_camera__noiseIntensity : float&)
      let dist = distance(owner_transform[3], drone_transform[3])
      vhs_camera__noiseIntensity = cvt(dist, drone__coverageArea.x, drone__coverageArea.y, drone__interference.x, drone__interference.y)


[es(tag=gameClient, track=drone_crash__isCrashed, REQUIRE=drone__view)]
def drone_camera_interference_on_exit(evt : Event;
                                      drone_crash__isCrashed : bool;
                                      drone__attachedCam : EntityId;
                                      drone_crash__cameraNoiseIntensityMultiplier : float)
  if drone_crash__isCrashed
    query(drone__attachedCam) <| $ [es] (var vhs_camera__noiseIntensity : float&)
      vhs_camera__noiseIntensity *= drone_crash__cameraNoiseIntensityMultiplier
