require ecs
require DagorSystem
require DagorDataBlock
require DagorMath
require math
require game.events.events_active_matter
require game.es.animation_curve_common


[es(tag=gameClient, on_appear)]
def camera_fov_es(evt : Event; fovLimits : float2; camera__fovSettingsPath : string; var fovSettings : float&)
  var fovFromSettings = fovSettings
  dgs_get_settings() |> datablock_get_block("gameplay") <| $(blk)
    fovFromSettings = blk |> datablock_getReal(camera__fovSettingsPath, fovFromSettings)
  fovSettings = clamp(fovFromSettings, fovLimits.x, fovLimits.y)


[es(tag=gameClient, no_order)]
def human_cam_magnification_normalizer_affect(act : ParallelUpdateFrameDelayed;
                                              eid : EntityId;
                                              game_effect__attachedTo : EntityId;
                                              human_cam_magnification_normalizer_affect__normalizationSpeed : float)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    let d = human_cam_magnification_normalizer_affect__normalizationSpeed * act.dt
    if abs(human__cameraMagnificationMult - 1.0) <= d
      human__cameraMagnificationMult = 1.0
      destroyEntity(eid)
      return

    human__cameraMagnificationMult = 1.0 < human__cameraMagnificationMult ? human__cameraMagnificationMult - d : human__cameraMagnificationMult + d


[es(tag=gameClient, before=camera_magnification_es)]
def human_cam_magnification_affect_update(act : UpdateStageInfoAct;
                                          game_effect__attachedTo : EntityId;
                                          human_cam_magnification_affect__magnification : float)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    human__cameraMagnificationMult = human_cam_magnification_affect__magnification


[es(tag=gameClient, on_disappear, REQUIRE=human_cam_magnification_affect__magnification)]
def human_cam_magnification_affect_disappear(evt : Event;
                                             game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human__cameraMagnificationMult : float&)
    human__cameraMagnificationMult = 1.0


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def actor_appear_update_human_cam_magnification_affect(evt : Event;
                                                       eid : EntityId;
                                                       var human__cameraMagnificationMult : float&)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          human_cam_magnification_affect__magnification : float)
    if game_effect__attachedTo == eid
      human__cameraMagnificationMult = human_cam_magnification_affect__magnification
      return true
    return false


[es(tag=gameClient, before=human_cam_magnification_affect_update)]
def client_human_cam_magnification_curve_affect_update(act : UpdateStageInfoAct;
                                                       game_effect__timeToDestroy : float;
                                                       game_effect__clientDestroyAt : float;
                                                       human_cam_magnification_affect__curve : Array;
                                                       var human_cam_magnification_affect__magnification : float&)
  let progress = cvt(act.curTime, game_effect__clientDestroyAt - game_effect__timeToDestroy, game_effect__clientDestroyAt,
                     0.0, 1.0)
  human_cam_magnification_affect__magnification = animation_curve_evaluate_smooth(human_cam_magnification_affect__curve, progress)
