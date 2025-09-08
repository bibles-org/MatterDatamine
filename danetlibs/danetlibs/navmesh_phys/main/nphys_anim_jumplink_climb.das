require ecs
require AnimV20
require PhysDecl
require DagorSystem
require DagorMath
require danetlibs.navmesh_phys.main.nphys_jumplink_climb_common
require danetlibs.navmesh_phys.main.nphys_events
require PhysVars


[es(on_appear, tag=server)]
def jumplink_climp_anim_init(evt : Event; eid : EntityId; animchar : AnimcharBaseComponent;
                             anim_state__climbStateName : string; var anim_state__climbState : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__climbState = *animGraph |> anim_graph_getStateIdx(anim_state__climbStateName)
  if anim_state__climbState == -1
    logerr("{eid}: <{getEntityTemplateName(eid)}> unable to find '{anim_state__climbStateName}' anim state")


// anim var

[es(on_appear, before=anim_phys_init_es)]
def jumplink_climp_anim_var_init(evt : Event; anim_state__climbProgressVarName : string; var anim_state__climbProgressVarId : int&; var phys_vars : PhysVars)
  anim_state__climbProgressVarId = phys_vars |> registerVar(anim_state__climbProgressVarName, 0.0)


[es(after=(navmesh_move_anim, navmesh_move_offline_anim, actions_es),
    before=(anim_state_es, nphys_ragdoll_death_anim), REQUIRE_NOT=navmesh_phys__climbJumpStartSpeed)]
def jumplink_climp_anim_update(act : UpdateStageInfoAct; transform : float3x4;
                               navmesh_phys__shouldClimbUp : bool;
                               navmesh_phys__defaultClimbHeight : float;
                               path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd : float3;
                               anim_state__climbState : int;
                               anim_state__climbProgressVarId : int const?; var anim_state__forceAnimStateId : int&;
                               var phys_vars : PhysVars?)
  if navmesh_phys__shouldClimbUp
    anim_state__forceAnimStateId = anim_state__climbState
    if phys_vars != null
      let height = path_corridor__jumpLinkEnd.y - path_corridor__jumpLinkStart.y
      let restHeight = max(0f, path_corridor__jumpLinkEnd.y - transform[3].y)
      let offset = clamp(1f - safediv(height, navmesh_phys__defaultClimbHeight), 0., 0.75)
      let time = lerp(offset, 1f, 1f - safediv(restHeight, height))
      *phys_vars |> setVar(*anim_state__climbProgressVarId, time)
  elif anim_state__forceAnimStateId == anim_state__climbState
    anim_state__forceAnimStateId = -1


[es(after=(navmesh_move_anim, navmesh_move_offline_anim, actions_es),
    before=(anim_state_es, nphys_ragdoll_death_anim), REQUIRE=navmesh_phys__climbJumpStartSpeed)]
def jumplink_jump_anim_update(act : UpdateStageInfoAct; transform : float3x4;
                              navmesh_phys__shouldClimbUp : bool;
                              path_corridor__isClimbing : bool;
                              path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd : float3;
                              anim_state__climbState : int;
                              anim_state__climbProgressVarId : int const?; var anim_state__forceAnimStateId : int&;
                              var phys_vars : PhysVars?;
                              anim_state__climbJumpProgressVarOffset = 0f)
  if navmesh_phys__shouldClimbUp && path_corridor__isClimbing
    anim_state__forceAnimStateId = anim_state__climbState
    if phys_vars != null
      let height = path_corridor__jumpLinkEnd.y - path_corridor__jumpLinkStart.y
      let restHeight = max(0f, path_corridor__jumpLinkEnd.y - transform[3].y)
      let time = saturate(1f - safediv(restHeight, height) + anim_state__climbJumpProgressVarOffset)
      *phys_vars |> setVar(*anim_state__climbProgressVarId, saturate(time))
  elif anim_state__forceAnimStateId == anim_state__climbState
    anim_state__forceAnimStateId = -1


[es(tag=gameClient)]
def on_path_corridor_jump_link_start_end_changed(evt : PathCorridorJumpLinkStartEndChanged;
                                                 var path_corridor__jumpLinkStart : float3&;
                                                 var path_corridor__jumpLinkEnd : float3&)
  path_corridor__jumpLinkStart = evt.start
  path_corridor__jumpLinkEnd = evt.end