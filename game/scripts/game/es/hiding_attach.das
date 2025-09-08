require ecs
require ecs.common
require AnimV20
require DngNet
require GeomNodeTree
require game.events.events_active_matter
require DagorSystem


// Geomtree hider
[es(tag=server, on_appear, track=(slot_attach__attachedTo, slot_attach__attached_hide_geomtree_nodes__attachedTo))]
def slot_attach_attached_hide_geomtree_nodes_track_attached_to(evt : Event;
                                                               slot_attach__attachedTo : EntityId;
                                                               slot_attach__attached_hide_geomtree_nodes__hiddenNodes : StringList;
                                                               var slot_attach__attached_hide_geomtree_nodes__attachedTo : EntityId&)
  if slot_attach__attachedTo == slot_attach__attached_hide_geomtree_nodes__attachedTo
    return

  if doesEntityExist(slot_attach__attached_hide_geomtree_nodes__attachedTo)
    for node in slot_attach__attached_hide_geomtree_nodes__hiddenNodes
      send_net_event(slot_attach__attached_hide_geomtree_nodes__attachedTo, EventAnimcharShowGeomtreeNode(nodeName = string(node)))

  if doesEntityExist(slot_attach__attachedTo)
    for node in slot_attach__attached_hide_geomtree_nodes__hiddenNodes
      send_net_event(slot_attach__attachedTo, EventAnimcharHideGeomtreeNode(nodeName = string(node)))

  slot_attach__attached_hide_geomtree_nodes__attachedTo = slot_attach__attachedTo


[es(tag=server, on_disappear, REQUIRE=slot_attach__attachedTo)]
def slot_attach_attached_hide_geomtree_nodes_disappear(evt : Event;
                                                       slot_attach__attached_hide_geomtree_nodes__hiddenNodes : StringList;
                                                       var slot_attach__attached_hide_geomtree_nodes__attachedTo : EntityId&)
  if doesEntityExist(slot_attach__attached_hide_geomtree_nodes__attachedTo)
    for node in slot_attach__attached_hide_geomtree_nodes__hiddenNodes
      send_net_event(slot_attach__attached_hide_geomtree_nodes__attachedTo, EventAnimcharShowGeomtreeNode(nodeName = string(node)))

  slot_attach__attached_hide_geomtree_nodes__attachedTo = INVALID_ENTITY_ID



// Dynmodel hider
[es(tag=server, on_appear, track=(slot_attach__attachedTo, slot_attach__attached_hide_dynmodel_nodes__attachedTo))]
def slot_attach_attached_hide_dynmodel_nodes_track_attached_to(evt : Event;
                                                               slot_attach__attachedTo : EntityId;
                                                               slot_attach__attached_hide_dynmodel_nodes__hiddenNodes : StringList;
                                                               var slot_attach__attached_hide_dynmodel_nodes__attachedTo : EntityId&)
  if slot_attach__attachedTo == slot_attach__attached_hide_dynmodel_nodes__attachedTo
    return

  slot_attach__attached_hide_dynmodel_nodes__attachedTo = slot_attach__attachedTo
  query(slot_attach__attached_hide_dynmodel_nodes__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__hiddenNodes : StringList)
    for node in slot_attach__attached_hide_dynmodel_nodes__hiddenNodes
      let idx = animchar_dynmodel_nodes_hider__hiddenNodes |> find_index(node)
      if idx >= 0
        animchar_dynmodel_nodes_hider__hiddenNodes |> erase(idx)

  query(slot_attach__attached_hide_dynmodel_nodes__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__hiddenNodes : StringList)
    for node in slot_attach__attached_hide_dynmodel_nodes__hiddenNodes
      animchar_dynmodel_nodes_hider__hiddenNodes |> push(node)


[es(tag=server, on_disappear, REQUIRE=slot_attach__attachedTo)]
def slot_attach_attached_hide_dynmodel_nodes_disappear(evt : Event;
                                                       slot_attach__attached_hide_dynmodel_nodes__hiddenNodes : StringList;
                                                       var slot_attach__attached_hide_dynmodel_nodes__attachedTo : EntityId&)
  query(slot_attach__attached_hide_dynmodel_nodes__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__hiddenNodes : StringList)
    for node in slot_attach__attached_hide_dynmodel_nodes__hiddenNodes
      let idx = animchar_dynmodel_nodes_hider__hiddenNodes |> find_index(node)
      if idx >= 0
        animchar_dynmodel_nodes_hider__hiddenNodes |> erase(idx)

  slot_attach__attached_hide_dynmodel_nodes__attachedTo = INVALID_ENTITY_ID


[es(tag=server, on_appear, track=(slot_attach__attachedTo, slot_attach__attached_show_dynmodel_nodes__attachedTo))]
def slot_attach_attached_show_dynmodel_nodes_track_attached_to(evt : Event;
                                                               slot_attach__attachedTo : EntityId;
                                                               slot_attach__attached_show_dynmodel_nodes__forceShownNodes : StringList;
                                                               var slot_attach__attached_show_dynmodel_nodes__attachedTo : EntityId&)
  if slot_attach__attachedTo == slot_attach__attached_show_dynmodel_nodes__attachedTo
    return

  query(slot_attach__attached_show_dynmodel_nodes__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__forceShownNodes : StringList)
    for node in slot_attach__attached_show_dynmodel_nodes__forceShownNodes
      let idx = animchar_dynmodel_nodes_hider__forceShownNodes |> find_index(node)
      if idx >= 0
        animchar_dynmodel_nodes_hider__forceShownNodes |> erase(idx)

  query(slot_attach__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__forceShownNodes : StringList)
    for node in slot_attach__attached_show_dynmodel_nodes__forceShownNodes
      animchar_dynmodel_nodes_hider__forceShownNodes |> push(node)

  slot_attach__attached_show_dynmodel_nodes__attachedTo = slot_attach__attachedTo


[es(tag=server, on_disappear, REQUIRE=slot_attach__attachedTo)]
def slot_attach_attached_show_dynmodel_nodes_disappear(evt : Event;
                                                       slot_attach__attached_show_dynmodel_nodes__forceShownNodes : StringList;
                                                       var slot_attach__attached_show_dynmodel_nodes__attachedTo : EntityId&)
  query(slot_attach__attached_show_dynmodel_nodes__attachedTo) <| $ [es] (var animchar_dynmodel_nodes_hider__forceShownNodes : StringList)
    for node in slot_attach__attached_show_dynmodel_nodes__forceShownNodes
      let idx = animchar_dynmodel_nodes_hider__forceShownNodes |> find_index(node)
      if idx >= 0
        animchar_dynmodel_nodes_hider__forceShownNodes |> erase(idx)

  slot_attach__attached_show_dynmodel_nodes__attachedTo = INVALID_ENTITY_ID
