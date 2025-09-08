require ecs
require ecs.common
require AnimV20
require DngNet
require GeomNodeTree
require game.events.events_active_matter
require DagorSystem


// Geomtree hider
def gather_children_geomtree_nodes_indices(tree : GeomNodeTree;
                                           node : uint16;
                                           var out : UInt16List&)
  out |> push(node)
  let childCount = tree |> geomtree_getChildCount(int(node))
  for i in range(childCount)
    gather_children_geomtree_nodes_indices(tree, uint16(tree |> geomtree_getChildNodeIdx(int(node), uint(i))), out)


def rebuild_hiding_geomtree_list(hide_from_nodes : StringList;
                                 var animchar_geomtree_nodes_hider__hiddenNodesIds : UInt16List&;
                                 tree : GeomNodeTree)
  animchar_geomtree_nodes_hider__hiddenNodesIds |> clear()
  for item in hide_from_nodes
    let firstIdx = tree |> geomtree_findNodeIndex(string(item))
    if firstIdx < 0
      continue
    gather_children_geomtree_nodes_indices(tree, uint16(firstIdx), animchar_geomtree_nodes_hider__hiddenNodesIds)


def restore_hidden_geomtree_nodes(animchar_geomtree_nodes_hider__hiddenNodesIds : UInt16List;
                                  var animchar : AnimcharBaseComponent&)
  for idx in animchar_geomtree_nodes_hider__hiddenNodesIds
    geomtree_getNodeTm(*animchar.nodeTree, int(idx)) = geomtree_getNodeTm(*animchar.originalNodeTree, int(idx))
  animchar |> animchar_doRecalcAnimAndWtm()


[es(tag=gameClient)]
def on_animchar_geomtree_nodes_hider_hide_event(evt : EventAnimcharHideGeomtreeNode;
                                                var animchar_geomtree_nodes_hider__hiddenNodes : StringList&)
  animchar_geomtree_nodes_hider__hiddenNodes |> push(evt.nodeName)


[es(tag=gameClient)]
def on_animchar_geomtree_nodes_hider_show_event(evt : EventAnimcharShowGeomtreeNode;
                                                var animchar_geomtree_nodes_hider__hiddenNodes : StringList&)
  let idx = animchar_geomtree_nodes_hider__hiddenNodes |> find_index(evt.nodeName)
  if idx >= 0
    animchar_geomtree_nodes_hider__hiddenNodes |> erase(idx)


[es(tag=gameClient, on_appear, track=animchar_geomtree_nodes_hider__hiddenNodes)]
def animchar_geomtree_nodes_hider_track_hidden_nodes(evt : Event;
                                                     animchar_geomtree_nodes_hider__hiddenNodes : StringList;
                                                     var animchar : AnimcharBaseComponent&;
                                                     var animchar_geomtree_nodes_hider__hiddenNodesIds : UInt16List&)
  restore_hidden_geomtree_nodes(
    animchar_geomtree_nodes_hider__hiddenNodesIds,
    animchar)
  rebuild_hiding_geomtree_list(
    animchar_geomtree_nodes_hider__hiddenNodes,
    animchar_geomtree_nodes_hider__hiddenNodesIds,
    *animchar.nodeTree)



// Dynmodel hider
[es(tag=gameClient, on_appear, track=(animchar_dynmodel_nodes_hider__hiddenNodes, animchar_dynmodel_nodes_hider__forceShownNodes))]
def animchar_dynmodel_nodes_hider_track_hidden_nodes(evt : Event;
                                                     animchar_dynmodel_nodes_hider__hiddenNodes : StringList;
                                                     animchar_dynmodel_nodes_hider__forceShownNodes : StringList;
                                                     var animchar_render : AnimcharRendComponent;
                                                     var animchar_dynmodel_nodes_hider__hiddenNodesIds : IntList&)
  assume sceneInstance = animchar_render.sceneInstance

  for nodeId in animchar_dynmodel_nodes_hider__hiddenNodesIds
    sceneInstance |> scene_instance_show_node(nodeId, true)

  animchar_dynmodel_nodes_hider__hiddenNodesIds |> clear()
  for nodeName in animchar_dynmodel_nodes_hider__hiddenNodes
    let isForceShown = find_index(animchar_dynmodel_nodes_hider__forceShownNodes, string(nodeName)) >= 0
    if !isForceShown
      let nodeId = *sceneInstance |> scene_instance_getNodeId(string(nodeName))
      animchar_dynmodel_nodes_hider__hiddenNodesIds |> push(nodeId)
      sceneInstance |> scene_instance_show_node(nodeId, false)

