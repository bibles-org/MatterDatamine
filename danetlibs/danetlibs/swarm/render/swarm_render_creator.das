require ecs

[es(tag=render, on_appear)]
def swarm_render_creator(evt : Event; var swarmRenderEntity aka host_swarmRenderEntity : EntityId&;
                         swarmRenderTemplate : string; var isSwarmRenderCreating aka host_isSwarmRenderCreating : bool&)
  let curSwarmRenderTemplate = swarmRenderTemplate
  var alreadyCreating = find_query() <| $ [es] (swarmRenderEntity : EntityId; swarmRenderTemplate : string; isSwarmRenderCreating : bool)
    if curSwarmRenderTemplate == swarmRenderTemplate && isSwarmRenderCreating
      host_swarmRenderEntity = swarmRenderEntity
      host_isSwarmRenderCreating = isSwarmRenderCreating
      return true
    return false
  if alreadyCreating
    return
  find_query() <| $ [es] (globalSwarmRenders : Object)
    swarmRenderEntity = get_Eid(globalSwarmRenders, swarmRenderTemplate) ?? INVALID_ENTITY_ID
    alreadyCreating = swarmRenderEntity != INVALID_ENTITY_ID
    isSwarmRenderCreating = alreadyCreating
    return true
  if alreadyCreating
    return
  swarmRenderEntity = createEntity(swarmRenderTemplate)
  isSwarmRenderCreating = true
  find_query() <| $ [es] (var globalSwarmRenders : Object&)
    globalSwarmRenders |> set(swarmRenderTemplate, swarmRenderEntity)
    return true
