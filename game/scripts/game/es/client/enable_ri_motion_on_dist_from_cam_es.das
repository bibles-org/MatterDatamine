require ecs
require game.es.camera_common

[es(tag=gameClient, no_order)]
def enable_ri_motion_on_distance_from_cam_es(info : UpdateStageInfoAct;
                                             transform : float3x4;
                                             ri_motion__enableDistSqFromCam : float;
                                             var ri_motion__enabled : bool&)
  let camPos = get_cam_itm()[3]
  let distSqToCam = distance_sq(camPos, transform[3])
  ri_motion__enabled = distSqToCam < ri_motion__enableDistSqFromCam
