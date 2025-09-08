require ecs
require AnimV20
require PhysDecl
require DagorSystem
require game.events.events_active_matter

[es(on_appear)]
def flower_human_static_state(evt : Event; eid : EntityId; animchar : AnimcharBaseComponent;
                              anim_state__staticStateName : string; var anim_state__staticState : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__staticState = *animGraph |> anim_graph_getStateIdx(anim_state__staticStateName)
  if anim_state__staticState == -1
    logerr("{eid}: <{getEntityTemplateName(eid)}> unable to find '{anim_state__staticStateName}' anim state")


[es(after=(navmesh_move_anim, navmesh_move_offline_anim),
    before=(anim_state_es, actions_es))]
def flower_human_static_anim_state(act : ParallelUpdateFrameDelayed; sleep_mode__isSleeping : bool;
                                   anim_state__staticState : int;
                                   sleep_mode_preparing_for_sleep_server_sleepAt : float const?;
                                   sleep_mode_preparing_for_sleep_client : Tag const?;
                                   var anim_state__forceAnimStateId : int&)
  let isPreparingToSleep = (sleep_mode_preparing_for_sleep_client != null) || (sleep_mode_preparing_for_sleep_server_sleepAt != null)

  if sleep_mode__isSleeping || isPreparingToSleep
    anim_state__forceAnimStateId = anim_state__staticState
  elif anim_state__forceAnimStateId == anim_state__staticState
    anim_state__forceAnimStateId = -1
