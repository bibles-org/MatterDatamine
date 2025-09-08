require ecs

[es(tag=render, track=camera__target, REQUIRE=camera__target)]
def shooter_cam_track_es(evt : Event;
                         shooter_cam__tauOnChange : float;
                         var shooter_cam__tauInc : float&)
  shooter_cam__tauInc = shooter_cam__tauOnChange

[es(tag=gameClient, on_appear, track=respawnCameraLookFrom, REQUIRE=respawnCameraLookFrom)]
def respawn_camera_track_es(evt : Event;
                            eid : EntityId)
  ecs::query() <| $ [es(REQUIRE=respawnCamera)] (respawnCameraTargerPoint : EntityId;
                                                 camera__active : bool;
                                                 shooter_cam__tau_on_change : float;
                                                 var shooter_cam__tauInc : float&)
    if camera__active && respawnCameraTargerPoint == eid
      shooter_cam__tauInc = shooter_cam__tau_on_change