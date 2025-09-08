require ecs
require app
require game.es.ecs_common
require math.base
require AnimV20
require GeomNodeTree
require DagorSystem


def create_entity_in_node_transform(game_effect_eid : EntityId;
                                    game_effect__attachedTo : EntityId;
                                    game_effect_create_server_entity_on_appear__nodeName : string;
                                    game_effect_create_server_entity_on_appear__template : string)
  assume nodeName = game_effect_create_server_entity_on_appear__nodeName

  query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
    var entityTm = IDENT_TM
    let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, nodeName)
    if nodeId >= 0
      geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, entityTm)

      createEntity(game_effect_create_server_entity_on_appear__template) <| $(var init : ComponentsInitializer)
        init |> set("transform", entityTm)
    else
      logerr("{get_entity_info(game_effect__attachedTo)}: Unknown node - {nodeName}! effect={get_entity_info(game_effect_eid)}")


[es(tag=server, on_appear)]
def game_effect_create_server_entity_on_appear(evt : Event;
                                               eid : EntityId;
                                               game_effect__attachedTo : EntityId;
                                               game_effect_create_server_entity_on_appear__nodeName : string;
                                               game_effect_create_server_entity_on_appear__template : string)
  create_entity_in_node_transform(eid, game_effect__attachedTo,
                                  game_effect_create_server_entity_on_appear__nodeName,
                                  game_effect_create_server_entity_on_appear__template)


[es(tag=gameClient, on_appear)]
def game_effect_create_client_entity_on_appear(evt : Event;
                                               eid : EntityId;
                                               game_effect__attachedTo : EntityId;
                                               game_effect_create_client_entity_on_appear__nodeName : string;
                                               game_effect_create_client_entity_on_appear__template : string)
  create_entity_in_node_transform(eid, game_effect__attachedTo,
                                  game_effect_create_client_entity_on_appear__nodeName,
                                  game_effect_create_client_entity_on_appear__template)
