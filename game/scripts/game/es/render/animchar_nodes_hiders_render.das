require ecs
require AnimV20
require GeomNodeTree
require danetlibs.renderer.includes.render_events


[es(tag=gameClient)]
def animchar_geomtree_nodes_hider_render(evt : UpdateStageInfoBeforeRender;
                                         animchar_geomtree_nodes_hider__hiddenNodesIds : UInt16List;
                                         var animchar : AnimcharBaseComponent&;
                                         var animchar_node_wtm : AnimcharNodesMat44&;
                                         var animchar_render__root_pos : vec4f&)
  if animchar_geomtree_nodes_hider__hiddenNodesIds |> empty()
    return

  assume tree = animchar.nodeTree
  for idx in animchar_geomtree_nodes_hider__hiddenNodesIds
    *tree |> geomtree_setNodeTmScalar(int(idx), float3x4()) // set tm to ZERO<TMatrix>()
    *tree |> geomtree_invalidateWtm()

  animchar |> animchar_recalc_wtm()
  animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)