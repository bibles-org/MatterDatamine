require ecs
require DngHuman
require DagorMath
require math.base


[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync, REQUIRE=watchedByPlr)]
def human_lean_camera(info : UpdateStageInfoAct;
                      human_net_phys : HumanActor;
                      possessedByPlr : EntityId;
                      human_cam_lean__maxAngle : float;
                      human_cam_lean__viscocity : float;
                      var human_cam_lean__angle : float&)
  assume phys = human_net_phys.phys
  assume curSt = phys.currentState
  assume prevSt = phys.previousState

  let cameraEid = get_Eid(possessedByPlr, "activeCamEid") ?? INVALID_ENTITY_ID
  query(cameraEid) <| $ [es] (var transform aka camera_transform : float3x4&)
    let interpK = get_phys_interpk_clamped(phys, info.curTime)
    let lean = lerp(prevSt.leanPosition, curSt.leanPosition, interpK)
    let leanProgress = cvt(lean, -phys.leanDegrees, phys.leanDegrees, -1.0, 1.0)

    // smoothing function to avoid unpleasant camera movement when fastly changing lean directions
    let wishCamLean = leanProgress * leanProgress * sign(leanProgress)
    human_cam_lean__angle = approach(human_cam_lean__angle, wishCamLean * human_cam_lean__maxAngle, info.dt, human_cam_lean__viscocity)

    let radians = deg_to_rad(human_cam_lean__angle)
    var q : quat
    euler_to_quat(0.0, -radians, 0.0, q)

    var tm : float3x4
    make_tm(q, float3(0.0), tm)

    camera_transform = camera_transform * tm
