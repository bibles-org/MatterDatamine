require ecs
require AnimV20
require strings

[es(on_appear, track=anim_state__forceAnimState, after=(navmesh_move_anim, navmesh_move_offline_anim),
    REQUIRE_NOT=(animchar__actOnDemand, deadEntity))]
def npys_forced_anim_init(evt : Event; anim_state__forceAnimState : string; animchar : AnimcharBaseComponent;
                          var anim_state__forceAnimStateId : int&)
  if empty(anim_state__forceAnimState)
    anim_state__forceAnimStateId = -1
    return
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__forceAnimStateId = *animGraph |> anim_graph_getStateIdx(anim_state__forceAnimState)
    // todo: recreate with tag


[es(on_appear, after=(navmesh_move_anim, navmesh_move_offline_anim),
    before=(anim_state_es, amimchar_entities_with_random_starter_es),
    REQUIRE_NOT=(animchar__actOnDemand, deadEntity))] // use anim_state__deathState for dead entites
def npys_forced_anim_update(act : UpdateStageInfoAct; anim_state__forceAnimStateId : int; anim_state__animChannels : StringList;
                            var animchar__animState : Object; var animchar__animStateDirty : bool&)
  if anim_state__forceAnimStateId != -1
    for channel in anim_state__animChannels
      animchar__animState |> set(string(channel), anim_state__forceAnimStateId)
    animchar__animStateDirty = true
