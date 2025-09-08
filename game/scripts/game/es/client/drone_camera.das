require ecs
require math.base
require game.es.client.drone_camera_common
require DngHelicopter
require DagorMath


[es(tag=gameClient, REQUIRE=isDrone, on_event=DroneEnterEvent)]
def create_drone_camera_es(evt : Event;
                           eid aka drone_eid : EntityId;
                           drone__owner : EntityId;
                           transform aka drone_transform : float3x4;
                           drone__camTemplate : string;
                           var helicopter_input__wishLookDir : float3&;
                           var drone__prevCam : EntityId&;
                           var drone__attachedCam : EntityId&)
  create_drone_camera(drone_eid, drone__owner, drone_transform, drone__camTemplate, drone__prevCam, drone__attachedCam)
  helicopter_input__wishLookDir = drone_transform[0]


[es(tag=gameClient, REQUIRE=drone__view, on_disappear, on_event=(DroneLeaveEvent, DroneForceLeaveEvent))]
def destroy_drone_camera_es(evt : Event;
                            eid aka drone_eid : EntityId;
                            drone__owner : EntityId;
                            drone__prevCam : EntityId;
                            var drone__attachedCam : EntityId&)
  destroy_drone_camera(drone_eid, drone__owner, drone__prevCam, drone__attachedCam)


[es(tag=gameClient, after=helicopter_phys_es, REQUIRE=drone__local)]
def drone_camera_update(info : UpdateStageInfoAct;
                        eid : EntityId;
                        transform aka drone_transform : float3x4;
                        helicopter_net_phys : HelicopterActor;
                        drone_crash__isCrashed : bool;
                        helicopter_input__wishLookDir : float3)
  if drone_crash__isCrashed
    return
  query() <| $ [es(REQUIRE=droneCamera)] (var transform aka drone_camera_transform : float3x4&;
                                          camera__vertAngleLimit : float2;
                                          camera__offset : float3;
                                          camera__target : EntityId)
    if camera__target == eid
      var wishLookDir = helicopter_input__wishLookDir
      let oy = asin(helicopter_input__wishLookDir.y) * RAD_TO_DEG
      if camera__vertAngleLimit.x < oy ||  camera__vertAngleLimit.y > oy
        let clampedOy = clamp(oy, camera__vertAngleLimit.x, camera__vertAngleLimit.y) * DEG_TO_RAD
        let azimut = atan2(wishLookDir.z, wishLookDir.x)
        let xzLength = cos(clampedOy)
        let sin = sin(clampedOy)
        let newX = cos(azimut) * xzLength
        let newZ = sin(azimut) * xzLength
        wishLookDir = normalize(float3(newX, sin, newZ))

      drone_camera_transform[2] = wishLookDir
      drone_camera_transform[0] = normalize(cross(drone_transform[1], helicopter_input__wishLookDir))
      drone_camera_transform[1] = normalize(cross(drone_camera_transform[2], drone_camera_transform[0]))
      var tm = drone_transform
      tm[3] = float3()
      drone_camera_transform[3] = approach(drone_transform[3],
                                  float3(helicopter_net_phys.phys.currentState.location.P),
                                  info.dt, 0.8f) + tm * camera__offset


[es(tag=gameClient, REQUIRE=drone__view, on_appear)]
def hide_drone_from_camera(evt : Event; var animchar_render__enabled : bool&)
  animchar_render__enabled = false


[es(tag=gameClient, REQUIRE=drone__view, on_disappear)]
def cancel_hide_drone_from_camera(evt : Event; var animchar_render__enabled : bool&)
  animchar_render__enabled = true
