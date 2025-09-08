module damage_decals_matrices_common shared
require ecs
require ecs.common
require DamageDecals

def get_matrix_id(coll_node_id : int;
                  var damage_decals__collNodeId : IntList&;
                  var damage_decals__nodeMatrixId : UInt32List&;
                  mergedMatrices : bool)
  if mergedMatrices
    if length(damage_decals__nodeMatrixId) > 0
      return damage_decals__nodeMatrixId[0]
    else
      let matrixId = damage_decals_add_new_matrix_id()
      push(damage_decals__nodeMatrixId, matrixId)
      return matrixId

  let idx = find_index(damage_decals__collNodeId, coll_node_id)
  if idx >= 0
    return damage_decals__nodeMatrixId[idx]
  else
    let matrixId = damage_decals_add_new_matrix_id()
    push(damage_decals__collNodeId, coll_node_id)
    push(damage_decals__nodeMatrixId, matrixId)
    assert(length(damage_decals__collNodeId) == length(damage_decals__nodeMatrixId))
    return matrixId