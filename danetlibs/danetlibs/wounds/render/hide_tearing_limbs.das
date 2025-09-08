require ecs
require ecs.safe
require danetlibs.node_collapser.render.node_collapser_events
require danetlibs.node_collapser.render.node_collapser_common
require AnimV20
require GeomNodeTree
require DagorSystem
require math.base
require ecs.soa_template
require danetlibs.renderer.includes.render_events


[soa_es, es(track=animchar_node_collapser__nodes, REQUIRE=updatableNodeCollapser, before=animchar_before_render_es)]
def node_collapser_recreate(evt : Event;
                            eid : EntityId;
                            var animchar_node_collapser : AnimcharNodeCollapser_SOA&;
                            var animchar_node_collapser__children : IntList&;
                            animchar_node_collapser__nodes : Object;
                            animchar : AnimcharBaseComponent;
                            animchar_render : AnimcharRendComponent)
  animchar_node_collapser |> clear()

  let scene = animchar_render.sceneInstance
  let geomtree = animchar.nodeTree
  for iter in animchar_node_collapser__nodes
    let rootNodeIdx = *geomtree |> geomtree_findNodeIndex(iter.key)
    let rootRenderNodeIdx = *scene |> scene_instance_getNodeId(iter.key)
    if rootNodeIdx <= 0 || rootRenderNodeIdx <= 0
      continue
    if length(animchar_node_collapser) >= MAX_COLLAPSE_NODES
      logerr("Attempt to collapse > {MAX_COLLAPSE_NODES} nodes in {getEntityTemplateName(eid)}")
      return

    var childNodes : array<int>
    childNodes |> push(rootNodeIdx)
    var i = 0
    var childrenCount = 0
    while i < length(childNodes)
      let nodeName = *geomtree |> geomtree_getNodeName(childNodes[i])
      if i > 0 && has(animchar_node_collapser__nodes, nodeName)
        i += 1
        continue
      let nodeId = *scene |> scene_instance_getNodeId(nodeName)
      if nodeId > 0
        animchar_node_collapser__children |> push(nodeId)
        childrenCount += 1
      let childCount = *geomtree |> geomtree_getChildCount(childNodes[i])
      for j in range(childCount)
        childNodes |> push(*geomtree |> geomtree_getChildNodeIdx(childNodes[i], uint(j)))
      i += 1
    let target = iter.value ?? ""
    animchar_node_collapser |> push() <| AnimcharNodeCollapser(
      animchar_node_collapser__rootNode = rootRenderNodeIdx,
      animchar_node_collapser__targetNode = target == "" ? -1 : *scene |> scene_instance_getNodeId(target),
      animchar_node_collapser__childrenCount = childrenCount
    )

  if length(animchar_node_collapser) == 0
    logwarn("animchar_node_collapser: not found any nodes of entity {eid} <{getEntityTemplateName(eid)}>")

[soa_def]
def limb_collapser(var animchar_render : AnimcharRendComponent&;
                   animchar_visbits : animchar_visbits_t;
                   animchar_node_collapser : AnimcharNodeCollapser_SOA;
                   animchar_node_collapser__children : IntList)
  if animchar_visbits == animchar_visbits_t(0)
    return
  assume scene = animchar_render.sceneInstance
  var zeroTm = float3x4()
  var from = 0
  for node in animchar_node_collapser
    let rootPos = scene_instance_getNodeWtm(*scene, uint(node.animchar_node_collapser__rootNode))[3]
    zeroTm[3] = (node.animchar_node_collapser__targetNode > 0 ?
                  scene_instance_getNodeWtm(*scene, uint(node.animchar_node_collapser__targetNode))[3] :
                  rootPos)
    for childIdx in range(from, from + node.animchar_node_collapser__childrenCount)
      let child = uint(animchar_node_collapser__children[childIdx])
      *scene |> scene_instance_setNodeWtm(child, zeroTm)
    from += node.animchar_node_collapser__childrenCount



[soa_es, es(tag=render, REQUIRE=(updatableNodeCollapser, hideShadowFromCollapsedNode), before=animchar_before_render_es)]
def on_animchar_update_without_shadow_collapser_item(info : BeforeDraw;
                                                     var animchar_render : AnimcharRendComponent&;
                                                     animchar_visbits : animchar_visbits_t;
                                                     animchar_node_collapser : AnimcharNodeCollapser_SOA;
                                                     animchar_node_collapser__children : IntList)
  limb_collapser(animchar_render, animchar_visbits, animchar_node_collapser, animchar_node_collapser__children)

[soa_es, es(tag=render, REQUIRE=(updatableNodeCollapser), REQUIRE_NOT=hideShadowFromCollapsedNode, before=animchar_before_render_es)]
def on_animchar_update_collapser_item(evt : HideNodesEvent;
                                      var animchar_render : AnimcharRendComponent&;
                                      animchar_visbits : animchar_visbits_t;
                                      animchar_node_collapser : AnimcharNodeCollapser_SOA;
                                      animchar_node_collapser__children : IntList)
  limb_collapser(animchar_render, animchar_visbits, animchar_node_collapser, animchar_node_collapser__children)