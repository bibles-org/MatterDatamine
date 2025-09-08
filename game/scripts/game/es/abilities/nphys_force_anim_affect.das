require ecs
require AnimV20
require DagorSystem
require DagorMath
require PhysVars
require strings
require game.events.events_active_matter


[es(tag=server, on_appear)]
def force_anim_state_appear(evt : Event;
                            eid, game_effect__attachedTo : EntityId;
                            game_effect__nPhysForceAnimState : string;
                            var game_effect__nPhysForceAnimStateId : int&)
  let found = query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent; var anim_state__forceAnimStateId : int&)
    let animGraph = animchar.animGraph
    if animGraph != null
      game_effect__nPhysForceAnimStateId = *animGraph |> anim_graph_getStateIdx(game_effect__nPhysForceAnimState)
      anim_state__forceAnimStateId = game_effect__nPhysForceAnimStateId
  if !found
    logerr("{eid}: {getEntityTemplateName(eid)} Forced anim affect was attached to entity without required archetype (animchar & anim_state__forceAnimStateId)")


[es(tag=server, on_disappear)]
def force_anim_state_disappear(evt : Event;
                               game_effect__attachedTo : EntityId;
                               game_effect__nPhysForceAnimStateId : int)
  query(game_effect__attachedTo) <| $ [es] (var anim_state__forceAnimStateId : int&)
    if anim_state__forceAnimStateId == game_effect__nPhysForceAnimStateId
      anim_state__forceAnimStateId = -1
