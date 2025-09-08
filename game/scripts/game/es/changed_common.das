module changed_common shared
require ecs
require app
require math.base
require math.random
require Grid
require GridCollision
require DagorMath
require Dacoll
require PhysMat
require DagorMath


def trigger_changeds_around(radius : float; pos : float3; max_count : int)
  var choices : array<tuple<eid : EntityId; weight : float>>
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, radius), GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=agent_dangers__triggeredUntil)] (transform : float3x4)
      let dst = distance_sq(pos, transform[3])
      choices |> emplace((eid, square(radius) - dst))
  var triggersLeft = max_count
  while length(choices) > 0 && triggersLeft-- > 0
    let targetIdx = choose_index_by_weight(choices)
    query(choices[targetIdx].eid) <| $ [es] (agent_dangers__triggerDuration : float;
                                             var agent_dangers__triggeredUntil : float&;
                                             var agent_dangers__lastAgroTime : float?)
      agent_dangers__triggeredUntil = get_sync_time() + agent_dangers__triggerDuration
      if agent_dangers__lastAgroTime != null
        *agent_dangers__lastAgroTime = get_sync_time()
    choices |> erase(targetIdx)


def traceray_blink(prev_pos : float3;
                   new_pos : float3;
                   transform : float3x4;
                   blink_trace_mat_id : int)
  let tracePosFrom = prev_pos + transform[1]
  let tracePosTo = new_pos + transform[1]

  let delta = tracePosTo - tracePosFrom
  let deltaLenSq = length_sq(delta)
  if deltaLenSq < VERY_SMALL_NUMBER
    return true

  let deltaLen = sqrt(deltaLenSq)
  let deltaDir = delta / deltaLen

  var t = deltaLen
  var matId = PHYSMAT_INVALID
  var norm : float3
  var riDesc = RendInstDesc()
  return traceray_normalized(tracePosFrom, deltaDir, t, matId, norm, ETF_ALL, riDesc, blink_trace_mat_id)