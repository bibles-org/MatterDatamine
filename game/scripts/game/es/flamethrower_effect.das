require ecs
require AnimV20
require GeomNodeTree
require game.es.node_attach_common
require DagorSystem

[es(on_appear)]
def flamethrower_init_effect(evt : Event;
                             eid : EntityId;
                             animchar : AnimcharBaseComponent;
                             flamethrower__streamEffectNodeName : string;
                             var flamethrower__streamEffectNodeIdx : int&)
  let nodeName = flamethrower__streamEffectNodeName
  flamethrower__streamEffectNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, nodeName)
  if flamethrower__streamEffectNodeIdx == -1
    logerr("<{getEntityTemplateName(eid)}> does not have '{nodeName}' animchar node. Failed to assign flamethrower.streamEffectNodeIdx")

[es(tag=gameClient, track=flamethrower__active)]
def flamethrower_manage_stream_effect(evt : Event;
                                      eid : EntityId;
                                      animchar : AnimcharBaseComponent;
                                      flamethrower__active : bool;
                                      flamethrower__streamEffectTemplate : string;
                                      flamethrower__streamEffectNodeIdx : int;
                                      var flamethrower__streamEffectEid : EntityId&)
  if flamethrower__active
    if !flamethrower__streamEffectEid && flamethrower__streamEffectNodeIdx >= 0
      flamethrower__streamEffectEid = createEntity(flamethrower__streamEffectTemplate) <| $(var init : ComponentsInitializer)
        var tm : float3x4
        geomtree_getNodeWtmScalar(*animchar.nodeTree, flamethrower__streamEffectNodeIdx, tm)
        set(init, "transform", tm)
      attach_to_node(flamethrower__streamEffectEid, eid, flamethrower__streamEffectNodeIdx)
  elif flamethrower__streamEffectEid != INVALID_ENTITY_ID
    destroyEntity(flamethrower__streamEffectEid)
    flamethrower__streamEffectEid = INVALID_ENTITY_ID

[es(tag=server, track=human_gun_attached)]
def flamethrower_disable_unattached(evt : Event;
                                    human_gun_attached : bool;
                                    var flamethrower__active : bool&)
  if !human_gun_attached
    flamethrower__active = false
