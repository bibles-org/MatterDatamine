require ecs
require app
require DagorMath


[es(tag=gameClient, REQUIRE=watchedByPlr, after=shooter_cam_update_tm_es, before=shooter_cam_tau_move_scalar_es)]
def confusion_from_heartrate(cmd : UpdateStageInfoAct;
                             bindedCamera : EntityId;
                             heartrate__value : float;
                             heartrate__stamina : float;
                             heartrate__visualHeartbeat__staminaThreshold : float;
                             heartrate__visualHeartbeatIntensity : float2;
                             var heartrate__lastVisualHeartbeat : float&)
  let timeBetweenBeats = 60.0 / heartrate__value
  let time = get_sync_time()
  let enableVisualHeartbeat = (heartrate__stamina < heartrate__visualHeartbeat__staminaThreshold)
  if enableVisualHeartbeat && (time - heartrate__lastVisualHeartbeat > timeBetweenBeats)
    heartrate__lastVisualHeartbeat = time
    query(bindedCamera) <| $ [es] (camera__active : bool; var fov : float&)
      if camera__active
        fov -= cvt(heartrate__stamina,
                    heartrate__visualHeartbeat__staminaThreshold,
                    0.0,
                    heartrate__visualHeartbeatIntensity.x,
                    heartrate__visualHeartbeatIntensity.y)
