require ecs
require ecs.safe
require AnimV20
require PhysVars
require DngNet
require DagorMath
require game.events.events
require game.events.events_active_matter
require game.events.events_game
require game.es.anim_common
require game.es.human_inventory_postponed_usage_common


[es(on_appear)]
def four_step_healing_register_var(evt : Event;
                                   game_effect__attachedTo : EntityId;
                                   four_step_healing__selectedBodypartIdx : int;
                                   var four_step_healing__progressVarId : int&;
                                   healing_effect_client : Tag const?)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars&;
                                            var animchar : AnimcharBaseComponent&;
                                            hero : Tag const?)
    if hero != null && healing_effect_client == null
      return

    four_step_healing__progressVarId = registerVar(phys_vars, "healing_by_sovmod_meds_progress", 0f)
    assume animState = animchar.animState
    assume animGraph = animchar.animGraph
    let paramId = *animGraph |> anim_graph_getParamId("healing_sovmod_meds_bodypart", int(PT_ScalarParam))
    if paramId != -1 && four_step_healing__selectedBodypartIdx >= 0
      *animState |> anim_state_holder_setParam(paramId, float(four_step_healing__selectedBodypartIdx))
    setVar(phys_vars, four_step_healing__progressVarId, 0.f)


[es(tag=gameClient, on_appear, before=four_step_healing_register_var)]
def four_step_healing_animation_create_animchars_on_appear(evt : Event;
                                                           game_effect__attachedTo : EntityId;
                                                           @shared_comp four_step_healing__animcharTemplateNames : StringList;
                                                           @shared_comp four_step_healing__animcharAlternativeSlots : StringList;
                                                           @shared_comp four_step_healing__useAlternativeSlots : BoolList;
                                                           four_step_healing__selectedBodypartIdx : int;
                                                           var four_step_healing__animcharEids : EidList&;
                                                           healing_effect_client : Tag const?)
  if has(game_effect__attachedTo, "hero") && healing_effect_client == null
    return

  let minIdx = max(0, length(four_step_healing__useAlternativeSlots) - 1)
  let bodypartIdx = min(minIdx, max(0, four_step_healing__selectedBodypartIdx))
  for i, templateName in iter_range(four_step_healing__animcharTemplateNames), four_step_healing__animcharTemplateNames
    let animcharEid = createEntity(string(templateName)) <| $(init)
      init |> set("game_effect__attachedTo", game_effect__attachedTo)
      if four_step_healing__useAlternativeSlots[bodypartIdx]
        init |> set("slot_attach__slotName", four_step_healing__animcharAlternativeSlots[i])
    four_step_healing__animcharEids |> push(animcharEid)


[es(no_order)]
def process_four_step_healing_animation(act : ParallelUpdateFrameDelayed;
                                        game_effect__attachedTo : EntityId;
                                        four_step_healing__progressVarId, four_step_healing__selectedBodypartIdx : int;
                                        @shared_comp four_step_healing__animationInOutDurations : Point3List;
                                        healing_effect_client : Tag const?;
                                        var four_step_healing__didAnimLoopEnd : bool&)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars&;
                                            human_inventory__entityUseStart : float;
                                            human_inventory__entityUseEnd : float;
                                            animchar__updatable = true;
                                            hero : Tag const?)
    if hero != null && healing_effect_client == null
      return
    if !animchar__updatable || human_inventory__entityUseEnd < act.curTime
      return

    let minIdx = max(0, length(four_step_healing__animationInOutDurations) - 1)
    let bodypartIdx = min(minIdx, max(0, four_step_healing__selectedBodypartIdx))
    assume duration = four_step_healing__animationInOutDurations[bodypartIdx]
    let secondIntroStartAt = human_inventory__entityUseStart + duration.x
    let cycleStartAt = human_inventory__entityUseStart + duration.x + duration.y
    let cycleEndAt = human_inventory__entityUseEnd - duration.z
    var progress = 0.0
    if act.curTime < secondIntroStartAt
      progress = cvt(act.curTime, human_inventory__entityUseStart, secondIntroStartAt, 0.0, 1.0)
    elif act.curTime < cycleStartAt
      progress = cvt(act.curTime, secondIntroStartAt, cycleStartAt, 1.0, 2.0)
    elif act.curTime > cycleEndAt
      progress = cvt(act.curTime, cycleEndAt, human_inventory__entityUseEnd, 3.0, 4.0)
    else
      progress = cvt(act.curTime, cycleStartAt, cycleEndAt, 2.0, 3.0)
    setVar(phys_vars, four_step_healing__progressVarId, progress)

    let effectAt = min(cycleEndAt, cycleStartAt)
    if !four_step_healing__didAnimLoopEnd && act.curTime >= effectAt
      four_step_healing__didAnimLoopEnd = true


[es(tag=server, before=process_four_step_healing_animation)]
def process_four_step_healing_heal(act : ParallelUpdateFrameDelayed;
                                   game_effect__attachedTo : EntityId;
                                   four_step_healing__item : EntityId;
                                   four_step_healing__selectedBodypartIdx : int = -1;
                                   var four_step_healing__healAt : float&)
  if four_step_healing__healAt < 0.0 || act.curTime < four_step_healing__healAt
    return

  four_step_healing__healAt = -1.0
  query(four_step_healing__item) <| $ [es] (item__healTemplateName : das_string const?;
                                            item__boostTemplateName : das_string const?;
                                            var item__currentBoxedItemCount : int?)

    if !has(game_effect__attachedTo, "infinite_heal_items") && item__currentBoxedItemCount != null
      --(*item__currentBoxedItemCount)
    if item__healTemplateName != null
      createEntity("{*item__healTemplateName}") <| $(var init)
        init |> set("game_effect__attachedTo", game_effect__attachedTo)
        init |> set("healing_effect__healItem", four_step_healing__item)
        if four_step_healing__selectedBodypartIdx >= 0
          init |> set("healing_effect__bodypartIdx", four_step_healing__selectedBodypartIdx)
    if item__boostTemplateName != null
      createEntity("{*item__boostTemplateName}") <| $(var init)
        init |> set("game_effect__attachedTo", game_effect__attachedTo)
  sendEvent(four_step_healing__item, EventHealItemUsed())


[es(tag=server, no_order, REQUIRE=four_step_healing__animationInOutDurations, REQUIRE_NOT=healing_effect_client)]
def delete_four_step_healing_animation_server(act : ParallelUpdateFrameDelayed; eid, game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_inventory__entityUseEnd : float; human_inventory_postponed_usage__state : int = 0)
    if human_inventory__entityUseEnd < act.curTime && human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
      destroyEntity(eid)


[es(tag=gameClient, no_order, REQUIRE=(four_step_healing__animationInOutDurations, healing_effect_client))]
def delete_four_step_healing_animation_client(act : ParallelUpdateFrameDelayed; eid, game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_inventory__entityUseEnd : float; human_inventory_postponed_usage__state : int = 0)
    if human_inventory__entityUseEnd < act.curTime && human_inventory_postponed_usage__state != int(PostponedUsageState.WaitForSwapToUnarmed)
      destroyEntity(eid)


[es(tag=gameClient, on_disappear)]
def four_step_healing_animation_disappear(evt : Event; four_step_healing__animcharEids : EidList)
  for animcharEid in four_step_healing__animcharEids
    destroyEntity(animcharEid)


[es(tag=server)]
def handle_four_step_healing_animation_interrupt(evt : EventItemUseInterrupted;
                                                 four_step_healing__effectEid : EntityId)
  destroyEntity(four_step_healing__effectEid)
