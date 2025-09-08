require ecs
require danetlibs.native_dasevents.main.native_events
require RendInst
require DagorMath
require DagorDebug3D
require GeomNodeTree
require AnimV20


[es(tag=ui, on_appear, on_event=(EventRendinstsLoaded, CmdTeleportEntity))]
def item_world_marker_ri_init(evt : Event;
                              item_world_marker__riColliderPoint : float3;
                              item_world_marker__riColliderPointOffset : float3;
                              ri_extra : RiExtraComponent;
                              var item_world_marker__offset : float3&)
  if !riex_isRiGenExtraValid(ri_extra.handle)
    return

  let riType = handle_to_ri_type(ri_extra.handle)
  let riCollres = get_ri_gen_extra_collres(int(riType))
  if riCollres == null
    return

  let riBox = BBox3(riCollres.vFullBBox)
  let riPoint = lerp(riBox.boxMin, riBox.boxMax, item_world_marker__riColliderPoint)
  item_world_marker__offset = riPoint + item_world_marker__riColliderPointOffset


[es(tag=ui, on_appear, on_event=(EventRendinstsLoaded, CmdTeleportEntity),
  after=item_world_marker_ri_init,
  REQUIRE=item_world_marker__copyOffsetToUseObject)]
def item_world_marker_copy_offset_to_use_object(evt : Event;
                                                item_world_marker__offset : float3;
                                                var use_object__offset : float3&)
  use_object__offset = item_world_marker__offset


[es(on_event=ParallelUpdateFrameDelayed, REQUIRE=ui_visible)]
def item_world_marker_attach_to_node(evt : Event;
                                     item_world_marker__attachToNode : string;
                                     var item_world_marker__pos : float3&;
                                     var item_world_marker__attachToNodeIdx : int&;
                                     animchar : AnimcharBaseComponent const?;
                                     item_world_marker__attachedToEid = INVALID_ENTITY_ID)
  if item_world_marker__attachToNodeIdx < 0
    var nodeTree = animchar != null ? animchar.nodeTree : null
    query(item_world_marker__attachedToEid) <| $ [es] (animchar : AnimcharBaseComponent)
      nodeTree = animchar.nodeTree
    if nodeTree != null
      item_world_marker__attachToNodeIdx = geomtree_findNodeIndex(*nodeTree, item_world_marker__attachToNode)

    // The index must always be found
    // If it was not found at this stage - it will be noticeable in the game
    // (the marker will be in coordinates 0,0,0)
    // Therefore, if everything is correctly configured geomtree_findNodeIndex should work only once
    if item_world_marker__attachToNodeIdx < 0
      return

  var nodeTree = animchar != null ? animchar.nodeTree : null
  query(item_world_marker__attachedToEid) <| $ [es] (animchar : AnimcharBaseComponent)
    nodeTree = animchar.nodeTree
  if nodeTree != null
    item_world_marker__pos = geomtree_getNodeWpos(*nodeTree, item_world_marker__attachToNodeIdx)