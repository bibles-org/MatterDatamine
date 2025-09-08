require ecs
require app
require game.es.client.postfx_fade_common
require active_matter.game.es.binoculars_common
require GeomNodeTree
require DagorSystem
require DagorMath
require AnimV20
require DngHuman


def get_binoculars_postfx_fade_layer_hash()
  return int(ecs_hash("binoculars"))


[es(tag=render, on_appear)]
def binoculars_attached_animchar_appear_client(evt : Event;
                                               eid : EntityId;
                                               animchar : AnimcharBaseComponent;
                                               binoculars_attached_animchar__cameraViewNode : string;
                                               var binoculars_attached_animchar__cameraViewNodeId : int&)
  assume cameraViewNode = binoculars_attached_animchar__cameraViewNode
  assume cameraViewNodeId = binoculars_attached_animchar__cameraViewNodeId

  cameraViewNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(cameraViewNode)
  if cameraViewNodeId < 0
    let templateName = getEntityTemplateName(eid)
    logerr("Can't find binoculars node {cameraViewNode} in {templateName}")


[es(tag=render, REQUIRE=watchedByPlr,
  after=(human_gun_lookat_camera_es, camera_set_sync, animchar_cam_target_es, animchar_cam_target_with_offset_es,
    after_net_phys_sync, human_fpv_cam_pos),
  before=before_camera_sync)]
def binoculars_lookat_camera_es(info : UpdateStageInfoAct;
                                binoculars_controller__attachedAnimcharEid : EntityId;
                                binoculars_controller__watchingState : int;
                                var camera__look_at : DPoint3&)

  assume watchingState = binoculars_controller__watchingState

  if watchingState >= int(BinocularsWatchingState.IN_FADEOUT) && watchingState <= int(BinocularsWatchingState.OUT_FADEIN)
    query(binoculars_controller__attachedAnimcharEid) <| $ [es] (animchar aka binoculars_animchar : AnimcharBaseComponent;
                                                                 binoculars_attached_animchar__cameraViewNodeId : int;
                                                                 binoculars_attached_animchar__cameraViewNodeOffset : float3)
      if binoculars_attached_animchar__cameraViewNodeId < 0
        return

      var wtm : float3x4
      *binoculars_animchar.nodeTree |> geomtree_getNodeWtmScalar(binoculars_attached_animchar__cameraViewNodeId, wtm)

      let offset = rotate(wtm, binoculars_attached_animchar__cameraViewNodeOffset)
      camera__look_at = DPoint3(wtm[3]) + DPoint3(offset)


[es(tag=render, REQUIRE=watchedByPlr, track=binoculars_controller__watchingState, after=binoculars_controller_track_watching_state)]
def binoculars_controller_track_watching_state_client(evt : Event;
                                                      binoculars_controller__watchingState : int;
                                                      binoculars_controller__watchingNextStateAt : float;
                                                      binoculars_controller_client__fadeColor : E3DCOLOR;
                                                      var binoculars_controller_client__fadeActive : bool&)
  assume state = binoculars_controller__watchingState
  let fadeColor =  float4(Color4(binoculars_controller_client__fadeColor))

  let leftToNextState = binoculars_controller__watchingNextStateAt - get_sync_time()

  if state == BinocularsWatchingState.IN_FADEIN || state == BinocularsWatchingState.OUT_FADEIN
    if leftToNextState > 0.0
      postfx_fadein(fadeColor, leftToNextState, get_binoculars_postfx_fade_layer_hash())
    else
      postfx_fade_immediate(fadeColor, get_binoculars_postfx_fade_layer_hash())
    binoculars_controller_client__fadeActive = true
  elif (state != BinocularsWatchingState.IN_FADE && state != BinocularsWatchingState.OUT_FADE &&
       binoculars_controller_client__fadeActive)
    if leftToNextState > 0.0
      postfx_fadeout(leftToNextState, get_binoculars_postfx_fade_layer_hash())
    else
      postfx_fadeout_immediate(get_binoculars_postfx_fade_layer_hash())
    binoculars_controller_client__fadeActive = false


[es(tag=render, REQUIRE=watchedByPlr, on_disappear)]
def binoculars_controller_client_disappear(evt : Event;
                                           binoculars_controller_client__fadeActive : bool)
  if binoculars_controller_client__fadeActive
    postfx_fadeout_immediate(get_binoculars_postfx_fade_layer_hash())
