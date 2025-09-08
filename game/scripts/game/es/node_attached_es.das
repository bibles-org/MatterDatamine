require ecs
require game.events.events
require AnimV20
require GeomNodeTree
require game.events.events_active_matter


[es]
def node_attached_itm(info : ParallelUpdateFrameDelayed;
                      node_attached__entity : EntityId;
                      node_attached__nodeId : int;
                      node_attached__localTm : float3x4;
                      var transform : float3x4&)
  if node_attached__nodeId < 0
    return

  query(node_attached__entity) <| $ [es] (animchar : AnimcharBaseComponent)
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, node_attached__nodeId, tm)
    transform = tm * node_attached__localTm

[es]
def node_attached_pos(info : ParallelUpdateFrameDelayed;
                      node_attached__entity : EntityId;
                      node_attached__nodeId : int;
                      node_attached__localPos : float3;
                      var transform : float3x4&)
  if node_attached__nodeId < 0
    return

  query(node_attached__entity) <| $ [es] (animchar : AnimcharBaseComponent)
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, node_attached__nodeId, tm)
    transform[3] = tm * node_attached__localPos

[es(tag=server, tag=net, no_order, REQUIRE=node_attached__destroyWithParent)]
def node_attached_destroy_with_parent_server(info : ParallelUpdateFrameDelayed; eid : EntityId; node_attached__entity : EntityId)
  if !doesEntityExist(node_attached__entity)
    destroyEntity(eid)

[es(no_order, REQUIRE=node_attached__destroyWithParent, REQUIRE_NOT=replication)]  // same as above ES but for local (not networking) entities
def node_attached_destroy_with_parent_local(info : ParallelUpdateFrameDelayed; eid : EntityId; node_attached__entity : EntityId)
  if !doesEntityExist(node_attached__entity)
    destroyEntity(eid)
