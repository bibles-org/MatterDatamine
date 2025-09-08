require ecs
require AnimV20
require DagorMath
require DngHuman
require DngPhys
require DngWeapon
require GeomNodeTree
require DagorSystem
require Gun
require math
require replay
require game.es.ecs_common
require game.es.human_weap_common
require debug.logerr_once


def human_aim_tm_common(info : UpdateStageInfoAct;
                        eid : EntityId;
                        human_weap__currentGunEid : EntityId;
                        transform : float3x4;
                        human_attached_gun__attachedGunEid : EntityId;
                        human_net_phys : HumanActor;
                        human_use_object__nodeId : int;
                        animchar : AnimcharBaseComponent;
                        var human__aimTm : float3x4)
  var gunEid : EntityId
  if human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
    gunEid = human_attached_gun__attachedGunEid
  elif human_weap__currentGunEid != INVALID_ENTITY_ID
    gunEid = human_weap__currentGunEid

  var gunPtr : Gun const?
  query(gunEid) <| $ [es] (gun : Gun const?)
    gunPtr = gun

  let spectated = eid |> has("watchedByPlr") && !(eid |> has("hero"))
  if is_replay_playing() || spectated || gunPtr == null || !is_human_allowed_aiming(eid, human_attached_gun__attachedGunEid, human_net_phys)
    // Use use_object in this case scenario
    if human_use_object__nodeId >= 0
      let zAxis = normalize(transform[2])
      human__aimTm[0] = normalize(human_net_phys.phys.currentState.gunDir)
      human__aimTm[1] = cross(zAxis, human__aimTm[0])
      human__aimTm[2] = zAxis
      human__aimTm[3] = geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId)
    else
      human__aimTm[0] = normalize(transform[0])
      human__aimTm[1] = normalize(transform[1])
      human__aimTm[2] = normalize(transform[2])
      human__aimTm[3] = float3()
  else
    human__aimTm = lerpGunTm(*gunPtr, get_phys_interp_time(human_net_phys.phys, info.curTime))

    // TODO: Remove this extra check later (f.e. if you find it after 2025-07-01)
    if length_sq(human__aimTm[0]) < 0.99
      logerr_once("{get_entity_info(eid)}: lerpGunTm returned non normalized aimTm - {human__aimTm}
transform={transform}
human_weap__currentGunEid={get_entity_info(human_weap__currentGunEid)}")


[es(tag=gameClient, before=camera_set_sync, after=human_weap_request_reload_es, REQUIRE=watchedByPlr)]
def human_aim_tm_es(info : UpdateStageInfoAct;
                    eid : EntityId;
                    human_weap__currentGunEid : EntityId;
                    transform : float3x4;
                    human_attached_gun__attachedGunEid : EntityId;
                    human_net_phys : HumanActor;
                    human_use_object__nodeId : int;
                    animchar : AnimcharBaseComponent;
                    var human__aimTm : float3x4)

  human_aim_tm_common(info, eid, human_weap__currentGunEid, transform, human_attached_gun__attachedGunEid,
                      human_net_phys, human_use_object__nodeId, animchar, human__aimTm)

[es(tag=server, before=camera_set_sync, after=human_weap_request_reload_es, REQUIRE_NOT=(watchedByPlr, sleeping_monster))]
def human_aim_tm_server_es(info : UpdateStageInfoAct;
                           eid : EntityId;
                           human_weap__currentGunEid : EntityId;
                           transform : float3x4;
                           human_attached_gun__attachedGunEid : EntityId;
                           human_net_phys : HumanActor;
                           human_use_object__nodeId : int;
                           animchar : AnimcharBaseComponent;
                           var human__aimTm : float3x4)

  human_aim_tm_common(info, eid, human_weap__currentGunEid, transform, human_attached_gun__attachedGunEid,
                      human_net_phys, human_use_object__nodeId, animchar, human__aimTm)
