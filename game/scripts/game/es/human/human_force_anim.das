require app
require ecs
require player
require math
require game.events.events
require game.events.events_active_matter
require game.events.vehicle_events
require game.es.human.human_force_anim_common
require DagorSystem
require AnimV20
require PhysVars
require debug.logerr_once


def get_state_id_or(eid : EntityId; state : string; default_value : int)
  var res = default_value
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent)
    let animGraph = animchar.animGraph
    if animGraph != null
      res = anim_graph_getStateIdx(*animGraph, state)
  return res

[es(on_appear)]
def init_force_anim(evt : Event;
                    game_effect__attachedTo : EntityId;
                    game_effect__forceAnimState : string;
                    var game_effect__forceAnimStateId : int&)
  game_effect__forceAnimStateId = get_state_id_or(game_effect__attachedTo, game_effect__forceAnimState, game_effect__forceAnimStateId)
  send_change_anim_state_event_safe(game_effect__attachedTo, game_effect__forceAnimStateId)


[es(on_appear, after=init_force_anim)]
def init_force_anim_with_progress(evt : Event;
                                  game_effect__attachedTo : EntityId;
                                  game_effect__forceAnimStateProgressTime : float;
                                  game_effect__forceAnimStateProgressVarName : string;
                                  var game_effect__forceAnimStateFinishAt : float&;
                                  var game_effect__forceAnimStateStartedAt : float&;
                                  var game_effect__forceAnimStateProgressVarId : int&)
  let curTime = get_sync_time()
  game_effect__forceAnimStateFinishAt = curTime + game_effect__forceAnimStateProgressTime
  game_effect__forceAnimStateStartedAt = curTime
  query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
    assume animGraph = animchar.animGraph
    game_effect__forceAnimStateProgressVarId = *animGraph |> anim_graph_getParamId(game_effect__forceAnimStateProgressVarName, int(PT_ScalarParam))


[es(after=force_anim_state_es, before=animchar_es)]
def force_anim_state_with_progress(act : ParallelUpdateFrameDelayed;
                                   game_effect__attachedTo : EntityId;
                                   game_effect__forceAnimStateProgressFromTo : float2;
                                   game_effect__forceAnimStateFinishAt : float;
                                   game_effect__forceAnimStateStartedAt : float;
                                   game_effect__forceAnimStateProgressVarId : int)
  query(game_effect__attachedTo) <| $ [es] (var animchar : AnimcharBaseComponent)
    let progress = saturate((act.curTime - game_effect__forceAnimStateStartedAt) / (game_effect__forceAnimStateFinishAt - game_effect__forceAnimStateStartedAt))
    assume from = game_effect__forceAnimStateProgressFromTo.x
    assume to = game_effect__forceAnimStateProgressFromTo.y
    let scaledProgres = from + (to - from) * progress
    *animchar.animState |> anim_state_holder_setParam(game_effect__forceAnimStateProgressVarId, scaledProgres)


[es(after=animchar_es)]
def force_anim_state_with_destroy_on_finish(act : ParallelUpdateFrameDelayed;
                                            eid aka effect_eid : EntityId;
                                            game_effect__forceAnimStateFinishAt : float;
                                            game_effect__forceAnimStateStartedAt : float)
  let progress = (act.curTime - game_effect__forceAnimStateStartedAt) / (game_effect__forceAnimStateFinishAt - game_effect__forceAnimStateStartedAt)
  if progress >= 1.0
    destroyEntity(effect_eid)


[es(on_appear)]
def init_force_anim_internal(evt : Event;
                             eid : EntityId;
                             animchar__forceAnimState : string;
                             var animchar__forceAnimStateId : int&)
  animchar__forceAnimStateId = get_state_id_or(eid, animchar__forceAnimState, animchar__forceAnimStateId)
  send_change_anim_state_event_safe(eid, animchar__forceAnimStateId)

[es(on_appear, track=animchar__forceLowerAnimState)]
def init_force_lower_anim_internal(evt : Event;
                                   eid : EntityId;
                                   animchar__forceLowerAnimState : string;
                                   var animchar__forceLowerAnimStateId : int&)
  animchar__forceLowerAnimStateId = get_state_id_or(eid, animchar__forceLowerAnimState, animchar__forceLowerAnimStateId)
  send_change_anim_lower_state_event_safe(eid, animchar__forceLowerAnimStateId)

[es(on_appear, track=animchar__forceUpperAnimState)]
def init_force_upper_anim_internal(evt : Event;
                                   eid : EntityId;
                                   animchar__forceUpperAnimState : string;
                                   var animchar__forceUpperAnimStateId : int&)
  animchar__forceUpperAnimStateId = get_state_id_or(eid, animchar__forceUpperAnimState, animchar__forceUpperAnimStateId)
  send_change_anim_upper_state_event_safe(eid, animchar__forceUpperAnimStateId)

[es(on_appear)]
def init_force_anim_lower(evt : Event;
                          game_effect__attachedTo : EntityId;
                          game_effect__forceAnimLowerState : string;
                          var game_effect__forceAnimLowerStateId : int&)
  game_effect__forceAnimLowerStateId = get_state_id_or(game_effect__attachedTo, game_effect__forceAnimLowerState, game_effect__forceAnimLowerStateId)
  send_change_anim_lower_state_event_safe(game_effect__attachedTo, game_effect__forceAnimLowerStateId)

[es(on_appear)]
def init_force_anim_upper(evt : Event;
                          game_effect__attachedTo : EntityId;
                          game_effect__forceAnimUpperState : string;
                          var game_effect__forceAnimUpperStateId : int&)
  game_effect__forceAnimUpperStateId = get_state_id_or(game_effect__attachedTo, game_effect__forceAnimUpperState, game_effect__forceAnimUpperStateId)
  send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperStateId)

[es(on_appear)]
def init_force_anim_upper_crawl(evt : Event;
                                game_effect__attachedTo : EntityId;
                                game_effect__forceAnimUpperCrawlState : string;
                                var game_effect__forceAnimUpperCrawlStateId : int&)
  game_effect__forceAnimUpperCrawlStateId = get_state_id_or(game_effect__attachedTo, game_effect__forceAnimUpperCrawlState, game_effect__forceAnimUpperCrawlStateId)
  if (get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
    send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperCrawlStateId)

[es(on_appear)]
def init_force_anim_upper_non_crawl(evt : Event;
                                    game_effect__attachedTo : EntityId;
                                    game_effect__forceAnimUpperNonCrawlState : string;
                                    var game_effect__forceAnimUpperNonCrawlStateId : int&)
  game_effect__forceAnimUpperNonCrawlStateId = get_state_id_or(game_effect__attachedTo, game_effect__forceAnimUpperNonCrawlState, game_effect__forceAnimUpperNonCrawlStateId)
  if !(get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
    send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperNonCrawlStateId)

[es(before=animchar_es)]
def force_anim_state_es(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimStateId : int)
  send_change_anim_state_event_safe(game_effect__attachedTo, game_effect__forceAnimStateId)

[es(after=(human_anim_es, force_anim_state_es))]
def force_anim_state_internal(act : ParallelUpdateFrameDelayed; eid : EntityId; animchar__forceAnimStateId : int)
  send_change_anim_state_event_safe(eid, animchar__forceAnimStateId)

[es(after=(human_anim_es, force_anim_state_es))]
def force_lower_anim_state_internal(act : ParallelUpdateFrameDelayed; eid : EntityId; animchar__forceLowerAnimStateId : int)
  send_change_anim_lower_state_event_safe(eid, animchar__forceLowerAnimStateId)

[es(after=(human_anim_es, force_anim_state_es))]
def force_upper_anim_state_internal(act : ParallelUpdateFrameDelayed; eid : EntityId; animchar__forceUpperAnimStateId : int)
  send_change_anim_upper_state_event_safe(eid, animchar__forceUpperAnimStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_lower(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimLowerStateId : int)
  send_change_anim_lower_state_event_safe(game_effect__attachedTo, game_effect__forceAnimLowerStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperStateId : int)
  send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper_non_crawl(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperNonCrawlStateId : int)
  if !(get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
    send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperNonCrawlStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper_crawl(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperCrawlStateId : int)
  if (get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
    send_change_anim_upper_state_event_safe(game_effect__attachedTo, game_effect__forceAnimUpperCrawlStateId)


[es(on_appear, after=init_force_anim_internal)]
def init_force_anim_var_values(evt : Event;
                               animchar__forceVarValues : Object;
                               var phys_vars : PhysVars;
                               var animchar__animStateDirty : bool?)
  if length(animchar__forceVarValues) > 0
    for animVar in animchar__forceVarValues
      let varId = registerVar(phys_vars, animVar.key, 0f)
      setVar(phys_vars, varId, get_float(animVar.value) ?? 0f)
    if animchar__animStateDirty != null
      *animchar__animStateDirty = true


[es(on_appear, before=init_force_anim_var_values, after=init_force_anim_internal)]
def init_force_anim_param_values(evt : Event;
                                 animchar__forceParamValues : Object;
                                 var animchar : AnimcharBaseComponent)
  for animParam in animchar__forceParamValues
    let paramId = anim_graph_getParamId(*animchar.animGraph, animParam.key, int(PT_ScalarParam))
    anim_state_holder_setParam(*animchar.animState, paramId, get_float(animParam.value) ?? 0f)


def set_param_without_type(var animchar : AnimcharBaseComponent&; paramId : int; value : float)
  assume graph = *animchar.animGraph
  assume state = *animchar.animState
  let paramType = graph |> anim_graph_getParamType(paramId)
  if paramType == PT_TimeParam || paramType == PT_ScalarParam
    state |> anim_state_holder_setParam(paramId, value)
  elif paramType == PT_ScalarParamInt
    state |> anim_state_holder_setParamInt(paramId, int(value))
  else
    logerr_once("set_param_without_type: unsupported param type ({paramType}) for paramId ({paramId})<{graph |> anim_graph_getParamName(paramId)}> ")

[es(after=(human_anim_es, anim_phys_updater_es), before=anim_state_es)]
def force_anim_param_values(info : ParallelUpdateFrameDelayed;
                            animchar__forceParamValuesOnUpdate : Object;
                            var animchar : AnimcharBaseComponent)
  for animParam in animchar__forceParamValuesOnUpdate
    let paramId = anim_graph_getParamId(*animchar.animGraph, animParam.key)
    if paramId < 0
      logerr("Anim param '{animParam.key}' not found in anim graph")
      continue
    set_param_without_type(animchar, paramId, get_float(animParam.value) ?? 0f)
