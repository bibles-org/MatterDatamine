module use_query_params_common shared
require ecs
require AnimV20
require GeomNodeTree
require math.base
require game.es.ecs_common
require debug.logerr_once


struct UseQueryParams
  canUse : bool
  pos : float3
  dir : float3
  dist : float2
  pickupRemoveRad : float
  pickupRemoveHeight : float
  thresholdDist : float
  dot : float


def get_use_query_params(eid : EntityId) : UseQueryParams
  var result : UseQueryParams
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent;
                        transform : float3x4;
                        human_use_object__useMinMaxDist : float2;
                        human__aimTm : float3x4;
                        human_inventory__pickupRemoveRadius : float;
                        human_inventory__pickupRemoveHeight : float;
                        isAlive = true;
                        human_use_object__nodeId = 0;
                        human_use_object__useDirMinDot = 0.7;
                        human_use_object__thresholdDist = 12f)

    if human_use_object__nodeId < 0
      logerr_once("[get_use_query_params] failed to get node for <{getEntityTemplateName(eid)}>")
      return

    result.dot = human_use_object__useDirMinDot
    result.dist = human_use_object__useMinMaxDist
    result.thresholdDist = human_use_object__thresholdDist
    result.canUse = isAlive
    result.dir = human__aimTm[0]

    if length_sq(human__aimTm[0]) < 0.99
      logerr_once("[get_use_query_params] human__aimTm is not normalized - {human__aimTm}
entity={get_entity_info(eid)}
transform={transform}")
      result.dir = normalize(result.dir)

    result.pos = geomtree_getNodeWpos(*animchar.nodeTree, human_use_object__nodeId)
    result.pickupRemoveRad = human_inventory__pickupRemoveRadius
    result.pickupRemoveHeight = human_inventory__pickupRemoveHeight
  return result
