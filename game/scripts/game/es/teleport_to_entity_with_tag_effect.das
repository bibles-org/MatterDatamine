require ecs
require DngActor
require DngHuman
require DagorConsole


[es(on_appear)]
def teleport_to_entity_with_tag_effect(evt : Event;
                                       game_effect__attachedTo : EntityId;
                                       game_effect__teleportToEntityWithTag : string)
  assume componentName = game_effect__teleportToEntityWithTag
  let componentHash = ecs_hash(componentName)

  find_query() <| $ [es] (eid : EntityId; transform : float3x4)
    if !has(eid, componentName, componentHash)
      return false

    var transformWithOffset = transform
    query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor)
      transformWithOffset[3] = transformWithOffset[3] + human_net_phys.phys.currentState.posOffset

    teleport_phys_actor(game_effect__attachedTo, transformWithOffset)
    return true

[es(on_appear, tag=render, REQUIRE=game_effect__tempDisableSsr)]
def temp_disable_ssr(evt : Event)
  console_command("render.disable_ssr_in_frame 5")