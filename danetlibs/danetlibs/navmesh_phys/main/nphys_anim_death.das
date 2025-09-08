require app
require ecs
require ecs.safe
require AnimV20
require PhysDecl
require Dacoll
require danetlibs.navmesh_phys.main.nphys_events


[es(on_appear)]
def nphys_init_death_states(evt : Event; animchar : AnimcharBaseComponent;
                            anim_state__deathStateName : string; var anim_state__deathState : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__deathState = *animGraph |> anim_graph_getStateIdx(anim_state__deathStateName)


[es(track=isAlive, after=(navmesh_move_anim, navmesh_move_offline_anim), before=anim_state_es)]
def nphys_death_anim_state(evt : Event; isAlive : bool; anim_state__deathState : int;
                           anim_state__animChannels : StringList;
                           var animchar__animState : Object;
                           var animchar__animStateDirty : bool&)
  if !isAlive
    for channel in anim_state__animChannels
      animchar__animState |> set(string(channel), anim_state__deathState)
    animchar__animStateDirty = true
