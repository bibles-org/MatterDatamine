module drone_camera_common shared
require ecs
require DagorMath
require DngCamera

def create_drone_camera(drone_eid : EntityId;
                        drone__owner : EntityId;
                        transform : float3x4;
                        drone__camTemplate : string;
                        var drone__prevCam : EntityId&;
                        var drone__attachedCam : EntityId&)
  if !has(drone__owner, "watchedByPlr")
    return

  query(drone__owner) <| $ [es] (hero : Tag const?)
    if hero != null
      addSubTemplate(drone_eid, "localDrone")
    else
      addSubTemplate(drone_eid, "viewDrone")

  query() <| $ [es] (var camera__active : bool&;
                     eid : EntityId)
    if camera__active
      drone__prevCam = eid
      camera__active = false

  let callback <- @ <| (eid : EntityId)
    query(eid) <| $ [es] (var camera__accuratePos : DPoint3&)
      camera__accuratePos = DPoint3(transform[3])
  var transformCamera = transform
  orthonormalize(transformCamera)
  drone__attachedCam = createEntity(drone__camTemplate, callback) <| $(var init)
    set(init, "camera__active", true)
    set(init, "camera__target", drone_eid)
    set(init, "transform", transformCamera)


def destroy_drone_camera(drone_eid : EntityId;
                         drone__owner : EntityId;
                         drone__prevCam : EntityId;
                         var drone__attachedCam : EntityId&)
  query() <| $ [es(REQUIRE=droneCamera)] (var camera__active : bool&;
                                          camera__target : EntityId;
                                          eid aka drone_cam_eid : EntityId)
    if camera__target == drone_eid
      camera__active = false
      destroyEntity(drone_cam_eid)
  let activeCameraFound = find_query() <| $ [es] (camera__active : bool)
    return camera__active
  if !activeCameraFound
    set_scene_camera_entity(drone__prevCam)
  drone__attachedCam = INVALID_ENTITY_ID
  query(drone__owner) <| $ [es] (hero : Tag const?)
    if hero != null
      removeSubTemplate(drone_eid, "localDrone")
    else
      removeSubTemplate(drone_eid, "viewDrone")