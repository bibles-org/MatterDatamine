require ecs
require ecs.common
require danetlibs.heat_sources.render.heat_source_common
require CollRes

[es(tag=render, on_appear, before=human_heat_source_init_es, after=human_damage_model_init, REQUIRE=human_damage_model__parts)]
def human_heat_source_prepare_am_init_es(evt : Event;
                                         human_heat_parts : Array;
                                         collres : CollisionResource;
                                         var human_damage_model__parts : Object;
                                         var heat_source__bodyCollisonNodeIds : IntList&;
                                         var heat_source__partTypes : IntList&)
  for partName in human_heat_parts
    var prtType = partType.HULL
    var collisionNodeId = -1
    var nodeType = ""
    for part in human_damage_model__parts
      var obj = getRW_ecs_object(part.value)
      if obj == null
        continue
      let list = get_ecs_StringList(obj, "list")
      if list == null
        continue
      for nodeName in *list
        if (string(nodeName) == get_string(partName, ""))
          let nodeId = collres_get_node_index_by_name(collres, string(nodeName))
          collisionNodeId = nodeId
          nodeType = part.key
    if (nodeType == "head")
      prtType = partType.HUMAN_HEAD
    elif (nodeType == "body")
      prtType = partType.HUMAN_TORSO
    elif (nodeType == "left_leg" || nodeType == "right_leg")
      prtType = partType.HUMAN_LEG
    elif (nodeType == "left_hand" || nodeType == "right_hand")
      prtType = partType.HUMAN_HAND
    push(heat_source__partTypes, int(prtType))
    push(heat_source__bodyCollisonNodeIds, collisionNodeId)
