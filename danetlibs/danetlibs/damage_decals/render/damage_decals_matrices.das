require ecs
require dm
require AnimV20
require CollRes
require DamageDecals
require DagorSystem

[es(tag=render, before=vehicle_damage_decals_update_es)]
def vehicle_damage_decals_clear_unused_matrices_es(info : UpdateStageInfoAct;
                                                   var damage_decals__collNodeId : IntList&;
                                                   var damage_decals__nodeMatrixId : UInt32List&)
  if get_dagor_frame_no() % 60u != 0u // no need to run this system every frame
    return
  let numMatrices = length(damage_decals__nodeMatrixId)
  for i in range(numMatrices)
    let reverseIdx = numMatrices - 1 - i
    if !damage_decals_is_matrix_id_used(damage_decals__nodeMatrixId[reverseIdx])
      damage_decals_delete_matrix_id(damage_decals__nodeMatrixId[reverseIdx])
      erase(damage_decals__nodeMatrixId, reverseIdx)
      if (length(damage_decals__collNodeId) > 0)
        erase(damage_decals__collNodeId, reverseIdx)

[es(tag=render, REQUIRE_NOT=disableUpdate, after=animchar_fast_phys_es)]
def vehicle_damage_decals_update_es(info : UpdateStageInfoAct;
                                    transform : float3x4;
                                    animchar : AnimcharBaseComponent;
                                    collres : CollisionResource;
                                    damage_decals__collNodeId : IntList;
                                    damage_decals__nodeMatrixId : UInt32List;
                                    isExploded : bool = false)
  if isExploded && length(damage_decals__nodeMatrixId) > 0
    damage_decals_set_matrix(damage_decals__nodeMatrixId[0], transform)
    return
  for collNodeId, matrixId in damage_decals__collNodeId, damage_decals__nodeMatrixId
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
    damage_decals_set_matrix(matrixId, nodeTm)

[es(tag=render, on_disappear)]
def vehicle_damage_decals_on_destroy(evt : Event; damage_decals__nodeMatrixId : UInt32List)
  for matrixId in damage_decals__nodeMatrixId
    damage_decals_delete_matrix_id(matrixId)

[es(tag=render, track=isExploded)]
def vehicle_damage_decals_merge_matrices_on_explosion(evt : Event;
                                                      transform : float3x4;
                                                      animchar : AnimcharBaseComponent;
                                                      collres : CollisionResource;
                                                      damage_model : DamageModel;
                                                      isExploded : bool;
                                                      var damage_decals__collNodeId : IntList&;
                                                      var damage_decals__nodeMatrixId : UInt32List&;
                                                      damage_decals__projectileHitDecalId : IntList;
                                                      damage_decals__projectileHitCollNodeId : IntList;
                                                      damage_decals__shrapnelDecalId : IntList;
                                                      damage_decals__shrapnelDecalPartId : IntList)
  if (!isExploded || length(damage_decals__collNodeId) == 0)
    return
  let invTm = inverse(transform)
  let newMatrixId = length(damage_decals__nodeMatrixId) > 0 ? damage_decals__nodeMatrixId[0] : damage_decals_add_new_matrix_id()

  assume projectileHitDecalId = damage_decals__projectileHitDecalId
  assume projectileHitCollNodeId = damage_decals__projectileHitCollNodeId
  for decalId, collNodeId in projectileHitDecalId, projectileHitCollNodeId
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
    change_vehicle_decal_matrix(decalId, newMatrixId, invTm * nodeTm)

  assume shrapnelDecalId = damage_decals__shrapnelDecalId
  assume shrapnelDecalPartId = damage_decals__shrapnelDecalPartId
  for decalId, partId in shrapnelDecalId, shrapnelDecalPartId
    let collNodeId = damage_model.dmData |> get_collision_node_id(partId)
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
    change_vehicle_decal_matrix(decalId, newMatrixId, invTm * nodeTm)

  for i in range(1, length(damage_decals__nodeMatrixId))
    damage_decals_delete_matrix_id(damage_decals__nodeMatrixId[i])
  resize(damage_decals__nodeMatrixId, 1)
  resize(damage_decals__collNodeId, 0)
