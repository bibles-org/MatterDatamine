require ecs
require AnimV20
require ecs.safe
require math.base
require GeomNodeTree
require DngHuman
require game.es.flashlights.flashlight_common
require game.utils.hero
require DngActor
require DagorMath
require DagorSystem
require game.es.camera_common


[es(tag=render, after=after_animchar_update_sync, before=animchar_before_render_es)]
def update_attached_flashlight_hero(act : UpdateStageInfoAct;
                                    attached_flashlight__actorEid : EntityId;
                                    attached_flashlight__controllerEid : EntityId;
                                    attached_flashlight__lightScale : float;
                                    attached_flashlight__extraRotationQuat : float4;
                                    var transform : float3x4)
  query(attached_flashlight__actorEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                                  human_net_phys : HumanActor;
                                                  isAlive : bool;
                                                  watchedByPlr : EntityId const?)
    query(attached_flashlight__controllerEid) <| $ [es] (attached_flashlight_controller__nodeId : int;
                                                         attached_flashlight_controller__offset = float3(0.0))
      if attached_flashlight_controller__nodeId < 0
        return

      var tm : float3x4
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(attached_flashlight_controller__nodeId, tm)

      let interpK = get_phys_interpk_clamped(human_net_phys.phys, act.curTime)
      let localHero = (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) != 0 && watchedByPlr != null

      var forwardDir : float3

      if localHero && isAlive
        forwardDir = get_cam_itm()[2]
      else
        forwardDir = lerp(human_net_phys.phys.previousState.headDir, human_net_phys.phys.currentState.headDir, float3(interpK))

      let finalQuat = dir_to_quat(forwardDir) * quat(attached_flashlight__extraRotationQuat)
      make_tm(finalQuat, tm[3], tm)
      assume offset = attached_flashlight_controller__offset
      tm[3] += tm[0] * offset.x + tm[1] * offset.y + tm[2] * offset.z
      transform = tm * scale_tm(attached_flashlight__lightScale)


[es(tag=render, track=attached_flashlight__isOn)]
def use_attached_flashlight_client(evt : Event;
                                   attached_flashlight__isOn : bool;
                                   attached_flashlight__normalBrightness : float;
                                   attached_flashlight__controllerEid : EntityId;
                                   attached_flashlight__type : int = int(FlashlightType.DEFAULT);
                                   var light__brightness : float&)
  light__brightness = attached_flashlight__isOn ? attached_flashlight__normalBrightness : 0f
  query(attached_flashlight__controllerEid) <| $ [es] (flashlight_device__emissiveOnValue : float;
                                                       flashlight_device__emissiveColor : float3;
                                                       flashlight_device__type : int = int(FlashlightType.DEFAULT);
                                                       var dynamic_material_channels_arr : Array&)
    if attached_flashlight__type != flashlight_device__type
      return
    for channel in dynamic_material_channels_arr
      let emissiveValue = float4(flashlight_device__emissiveColor, attached_flashlight__isOn ? flashlight_device__emissiveOnValue : 0.0)
      *((channel as Object)?.dynmat_param__emissive_color ?as float4) = emissiveValue


[es(on_disappear, REQUIRE=(flashlight_device__type, slot_attach__attachedTo))]
def flashlight_device_detached_client(evt : Event;
                                      flashlight_device__emissiveColor : float3;
                                      var dynamic_material_channels_arr : Array&)
  for channel in dynamic_material_channels_arr
    let emissiveValue = float4(flashlight_device__emissiveColor, 0.0)
    *((channel as Object)?.dynmat_param__emissive_color ?as float4) = emissiveValue