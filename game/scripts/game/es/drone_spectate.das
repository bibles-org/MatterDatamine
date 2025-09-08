require ecs
require app
require DagorMath
require game.utils.hero
require DagorSystem


[es(tag=gameClient, REQUIRE=drone__view, REQUIRE_NOT=drone__local, no_order)]
def spectator_drone_update_es(info : UpdateStageInfoAct;
                              transform aka drone_transform : float3x4;
                              drone__cameraReplicateEid : EntityId)
  query(drone__cameraReplicateEid) <| $ [es] (transform aka camera_replicating_transform : float3x4)
    query() <| $ [es(REQUIRE=droneCamera)] (var transform aka drone_camera_transform : float3x4&;
                                            camera__offset : float3;
                                            camera__active : bool)
      if !camera__active
        return
      drone_camera_transform = camera_replicating_transform
      drone_camera_transform |> orthonormalize()
      var tm = drone_camera_transform
      tm[3] = float3()
      drone_camera_transform[3] = drone_transform[3] + tm * camera__offset


[es(tag=server, on_appear, REQUIRE=isDrone)]
def add_replicate_camera_on_server(evt : Event;
                                   eid aka drone_eid : EntityId;
                                   drone__cameraReplicateTempl : string;
                                   var drone__cameraReplicateEid : EntityId&)
  drone__cameraReplicateEid = createEntity(drone__cameraReplicateTempl) <| $(var init)
    set(init, "observedDrone", drone_eid)


[es(tag=gameClient, on_appear, REQUIRE=droneCameraReplicating)]
def ignore_loc_snapshot_for_drone_owner(evt : Event;
                                        eid aka camera_replicating_eid : EntityId;
                                        observedDrone : EntityId)
  query(observedDrone) <| $ [es(REQUIRE=drone__local)] ()
    addSubTemplate(camera_replicating_eid, "loc_snapshots_dont_update")
