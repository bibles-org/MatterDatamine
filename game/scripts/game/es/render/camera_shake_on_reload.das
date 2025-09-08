require ecs
require DagorMath
require AnimV20
require GeomNodeTree
require DagorSystem
require DngHuman
require math.base


def clamp(x : float; minmax : float2)
  return clamp(x, minmax[0], minmax[1])


def get_weapon_direction(animchar : AnimcharBaseComponent; node1_index, node2_index : int)
  let node1Pos = geomtree_getNodeWpos(*animchar.nodeTree, node1_index)
  let node2Pos = geomtree_getNodeWpos(*animchar.nodeTree, node2_index)
  return normalize(node2Pos - node1Pos)


[es(tag=gameClient, on_appear)]
def camera_shake_on_reload_init(evt : Event;
                                eid : EntityId;
                                animchar : AnimcharBaseComponent;
                                gun_reload_camera_shake__node1Name : string;
                                gun_reload_camera_shake__node2Name : string;
                                var gun_reload_camera_shake__node1Index : int&;
                                var gun_reload_camera_shake__node2Index : int&)
  gun_reload_camera_shake__node1Index = geomtree_findNodeIndex(*animchar.nodeTree, gun_reload_camera_shake__node1Name)
  if gun_reload_camera_shake__node1Index == -1
    logerr("The weapon '{getEntityTemplateName(eid)}' does not contain node '{gun_reload_camera_shake__node1Name}'")

  gun_reload_camera_shake__node2Index = geomtree_findNodeIndex(*animchar.nodeTree, gun_reload_camera_shake__node2Name)
  if gun_reload_camera_shake__node2Index == -1
    logerr("The weapon '{getEntityTemplateName(eid)}' does not contain node '{gun_reload_camera_shake__node2Name}'")


[es(tag=gameClient, after=shooter_cam_update_tm_es, before=after_camera_sync, REQUIRE=watchedByPlr)]
def camera_shake_on_reload_update(info : UpdateStageInfoAct;
                                  isTpsView : bool;
                                  isInVehicle : bool;
                                  transform aka soldier_transform : float3x4;
                                  camera__lookDir : float3;
                                  possessedByPlr : EntityId;
                                  human_net_phys : HumanActor;
                                  human_weap__currentGunEid : EntityId;
                                  check_ammo_controller__ammoInspectionProgress : float;
                                  check_ammo_controller__ammoInspectionProgressEnd : float)
  if isTpsView || isInVehicle
    return

  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                              gun_reload_camera_shake__node1Index : int;
                                              gun_reload_camera_shake__node2Index : int;
                                              gun_reload_camera_shake__limitX : float2;
                                              gun_reload_camera_shake__limitY : float2;
                                              gun_reload_camera_shake__scale : float2;
                                              gun_anim__reloadProgress : float;
                                              gun_reload_camera_shake__offsetDisableViscosity : float;
                                              gun_boxed_ammo_reload__reloadState : int = -1;
                                              var gun_reload_camera_shake__initialWeaponDirection : float3&;
                                              var gun_reload_camera_shake__initialWeaponDirectionInited : bool&;
                                              var gun_reload_camera_shake__currentOffset : float2&)
    var enabled = human_net_phys.phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED && gun_reload_camera_shake__node1Index != -1 && gun_reload_camera_shake__node2Index != -1

    assume isReload = gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.0 || gun_boxed_ammo_reload__reloadState != -1
    assume isInspect = check_ammo_controller__ammoInspectionProgress > 0.0 && check_ammo_controller__ammoInspectionProgress < check_ammo_controller__ammoInspectionProgressEnd
    enabled &&= isReload || isInspect

    if enabled
      if !gun_reload_camera_shake__initialWeaponDirectionInited
        gun_reload_camera_shake__initialWeaponDirectionInited = true
        let weaponDirectionInWorld = get_weapon_direction(animchar, gun_reload_camera_shake__node1Index, gun_reload_camera_shake__node2Index)
        gun_reload_camera_shake__initialWeaponDirection = rotate(inverse(soldier_transform), weaponDirectionInWorld)
    else
      gun_reload_camera_shake__initialWeaponDirectionInited = false

    let cameraEid = get_Eid(possessedByPlr, "activeCamEid") ?? INVALID_ENTITY_ID
    query(cameraEid) <| $ [es] (var transform aka camera_transform : float3x4&)
      var targetOffset = float2(0.0)
      if !enabled
        targetOffset = approach(gun_reload_camera_shake__currentOffset, float2(0.0), info.dt, gun_reload_camera_shake__offsetDisableViscosity)
      else
        let weaponDirInWorld = get_weapon_direction(animchar, gun_reload_camera_shake__node1Index, gun_reload_camera_shake__node2Index)
        let weaponDirLocal = rotate(inverse(soldier_transform), weaponDirInWorld)
        let weaponRotateQuat = quat(quat_from_unit_arc(normalize(gun_reload_camera_shake__initialWeaponDirection), normalize(weaponDirLocal)))
        let cameraRotatedDirection = weaponRotateQuat * camera__lookDir
        let cameraDiffDir = cameraRotatedDirection - camera__lookDir

        let projX = dot(cameraDiffDir, -soldier_transform[2])
        let projY = dot(cameraDiffDir, soldier_transform[1])

        let offsetX = clamp(projX * gun_reload_camera_shake__scale.x, gun_reload_camera_shake__limitX)
        let offsetY = clamp(projY * gun_reload_camera_shake__scale.y, gun_reload_camera_shake__limitY)

        targetOffset = float2(offsetX, offsetY)

      gun_reload_camera_shake__currentOffset = targetOffset

      var q : quat
      euler_to_quat(targetOffset.y, targetOffset.x, targetOffset.x, q)
      var shakerTm : float3x4
      make_tm(q, float3(0.0), shakerTm)
      camera_transform = camera_transform * shakerTm
