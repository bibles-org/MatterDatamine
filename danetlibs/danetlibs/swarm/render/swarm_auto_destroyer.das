require ecs


[es(tag=render, REQUIRE=swarm__autoDestroyRender, on_disappear)]
def swarm_auto_destroy_render(evt : Event; eid, swarmRenderEntity : EntityId; swarmRenderTemplate : string)
  let curSwarmRenderTemplate = swarmRenderTemplate
  let excludeEid = eid
  let hasMoreSwarms = find_query() <| $ [es(REQUIRE=swarm__autoDestroyRender)] (eid : EntityId; swarmRenderTemplate : string)
    return eid != excludeEid && curSwarmRenderTemplate == swarmRenderTemplate
  if !hasMoreSwarms
    destroyEntity(swarmRenderEntity)
    find_query() <| $ [es] (var globalSwarmRenders : Object&)
      globalSwarmRenders |> erase(swarmRenderTemplate)
      return true

[es(tag=render, REQUIRE=boids_spawner, on_disappear)]
def swarm_auto_destroy_boids(evt : Event; eid : EntityId)
  let swarmEid = eid
  query() <| $ [es] (eid, parentSwarm : EntityId)
    if parentSwarm == swarmEid
      destroyEntity(eid)

[es(tag=render, on_appear)]
def verify_boid_has_swarm(evt : Event; eid, parentSwarm : EntityId)
  if !doesEntityExist(parentSwarm)
    destroyEntity(eid)
