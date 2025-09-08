require app
require ecs
require ecs.safe
require ecs.soa_template
require math.base
require DagorSystem


enum GameEffectSequenceStateFlags
  AFFECT_SETUP_TRANSFORM = 0x1
  SYNC_CREATION = 0x2


[soa_template]
struct GameEffectSequenceState
  game_effect_sequence__states__stageIdx : int
  game_effect_sequence__states__startEndTime : float2 // x - timeStart, y - timeEnd
  game_effect_sequence__states__delay : float
  game_effect_sequence__states__duration : float
  game_effect_sequence__states__affectTemplate : string
  game_effect_sequence__states__affectEid : EntityId
  game_effect_sequence__states__flags : int


def create_game_affect_sequence_affect_entity(affect_template : string;
                                              duration : float;
                                              sequence_eid : EntityId;
                                              game_effect__attachedTo : ecs::EntityId;
                                              flags : int;
                                              transform : float3x4 const?)
  var res = INVALID_ENTITY_ID
  using() <| $(var init : ComponentsInitializer)
    assume templateName = duration >= FLT_MAX ? "{affect_template}+report_destruction_to_sequence" : affect_template
    init |> set("game_effect__attachedTo", game_effect__attachedTo)
    init |> set("game_effect__parentEffectEid", sequence_eid)
    init |> set("duration", duration)
    if duration >= FLT_MAX
      init |> set("report_destruction_to_sequence__sequenceEid", sequence_eid)

    if (flags & int(GameEffectSequenceStateFlags.AFFECT_SETUP_TRANSFORM)) != 0
      init |> set("transform", transform ?? IDENT_TM)

    let isSync = (flags & int(GameEffectSequenceStateFlags.SYNC_CREATION)) != 0
    res = isSync ? createEntitySync(templateName, init) : createEntity(templateName, init)

  return res


[soa_def]
def schedule_game_affect_sequence_stage(var game_effect_sequence__states : GameEffectSequenceState_SOA;
                                        stage : Object const?;
                                        stage_idx : int;
                                        game_effect__attachedTo : EntityId;
                                        sequence_eid : EntityId)
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4 const?)
    let affectTemplate = stage.affectTemplate ?? ""
    let delay = stage.delay ?? 0.0
    let waitForDestruction = stage.waitForDestruction ?? false
    let duration = stage.duration ?? (waitForDestruction ? FLT_MAX : 0.0)
    var affectEid = INVALID_ENTITY_ID

    var flags = 0
    if stage.setupTransform ?? false
      flags |= int(GameEffectSequenceStateFlags.AFFECT_SETUP_TRANSFORM)
    if stage.syncCreation ?? false
      flags |= int(GameEffectSequenceStateFlags.SYNC_CREATION)

    if affectTemplate != "" && delay <= 0.0
      affectEid = create_game_affect_sequence_affect_entity(affectTemplate, duration, sequence_eid, game_effect__attachedTo, flags, transform)

    let timeStart = get_sync_time()
    let timeEnd = timeStart + delay + duration

    game_effect_sequence__states |> push(
      GameEffectSequenceState(
          game_effect_sequence__states__stageIdx = stage_idx,
          game_effect_sequence__states__startEndTime = float2(timeStart, timeEnd),
          game_effect_sequence__states__delay = delay,
          game_effect_sequence__states__duration = duration,
          game_effect_sequence__states__affectTemplate := affectTemplate,
          game_effect_sequence__states__affectEid = affectEid,
          game_effect_sequence__states__flags = flags
        ))


[soa_es, es(on_appear)]
def game_effect_sequence_appear(evt : Event;
                                eid aka sequence_eid : EntityId;
                                game_effect__attachedTo : EntityId;
                                game_effect_sequence__stages : Array;
                                var game_effect_sequence__states : GameEffectSequenceState_SOA)
  for st in game_effect_sequence__stages
    let stage = st as Object
    schedule_game_affect_sequence_stage(game_effect_sequence__states, stage, 0, game_effect__attachedTo, sequence_eid)
    break


[soa_def]
def end_game_effect_sequence_state(var states : GameEffectSequenceState_SOA;
                                   state_idx : int)
  assume affectEid = states[state_idx].game_effect_sequence__states__affectEid
  if affectEid != INVALID_ENTITY_ID
    destroyEntity(affectEid)
    affectEid = INVALID_ENTITY_ID


[soa_es, es(no_order)]
def game_effect_sequence_update(act : UpdateStageInfoAct;
                                eid aka game_effect_eid : EntityId;
                                game_effect__attachedTo : EntityId;
                                game_effect_sequence__stages : Array;
                                game_effect_sequence__autoDestroy : bool = true;
                                var game_effect_sequence__states : GameEffectSequenceState_SOA)
  var statesToRemove : array<int>
  for stateIndex, state in iter_range(game_effect_sequence__states), game_effect_sequence__states
    assume delay = state.game_effect_sequence__states__delay
    assume affectEid = state.game_effect_sequence__states__affectEid
    assume duration = state.game_effect_sequence__states__duration
    let timeEnd = state.game_effect_sequence__states__startEndTime.y
    let stageIdx = state.game_effect_sequence__states__stageIdx
    let flags = state.game_effect_sequence__states__flags


    if delay > 0.0
      delay -= act.dt
      if delay <= 0.0

        if affectEid != INVALID_ENTITY_ID
          logerr("{affectEid}<{getEntityTemplateName(affectEid)}>: Affect already exists?")
          destroyEntity(affectEid)

        query(game_effect__attachedTo) <| $ [es] (transform : float3x4 const?)
          let affectTemplate = string(state.game_effect_sequence__states__affectTemplate)
          affectEid = create_game_affect_sequence_affect_entity(affectTemplate, duration, game_effect_eid, game_effect__attachedTo, flags, transform)

    if act.curTime >= timeEnd
      statesToRemove |> push(stateIndex)

      end_game_effect_sequence_state(game_effect_sequence__states, stateIndex)

      if stageIdx >= 0
        let nextStageIdx = stageIdx + 1
        if nextStageIdx < length(game_effect_sequence__stages)
          let nextStage = game_effect_sequence__stages[nextStageIdx] as Object
          schedule_game_affect_sequence_stage(game_effect_sequence__states, nextStage, nextStageIdx, game_effect__attachedTo, game_effect_eid)

  let statesToRemoveCount = length(statesToRemove)
  for stateIndex in range(statesToRemoveCount)
    let reverseIdx = statesToRemoveCount - stateIndex - 1
    game_effect_sequence__states |> erase(reverseIdx)

  if length(game_effect_sequence__states) == 0 && game_effect_sequence__autoDestroy
    destroyEntity(game_effect_eid)


[soa_es, es(on_disappear)]
def report_destruction_to_sequence(evt : Event; eid : EntityId; report_destruction_to_sequence__sequenceEid : EntityId)
  query(report_destruction_to_sequence__sequenceEid) <| $ [soa_blk, es] (var game_effect_sequence__states : GameEffectSequenceState_SOA)
    for state in game_effect_sequence__states
      assume affectEid = state.game_effect_sequence__states__affectEid
      if eid != affectEid
        continue
      state.game_effect_sequence__states__startEndTime.y = 0.0
      break


[soa_es, es(on_disappear)]
def game_effect_sequence_disappear(evt : Event;
                                   var game_effect_sequence__states : GameEffectSequenceState_SOA)
  for stateIndex in iter_range(game_effect_sequence__states)
    end_game_effect_sequence_state(game_effect_sequence__states, stateIndex)
  game_effect_sequence__states |> clear()