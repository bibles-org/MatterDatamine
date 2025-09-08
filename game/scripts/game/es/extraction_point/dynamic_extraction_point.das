require ecs
require app
require game.es.random_common
require game.events.events_active_matter
require game.es.ecs_common
require game.utils.hero
require DagorSystem
require DngNet
require game.es.extraction_point.extraction_point_common


def logerr_dynamic_extraction(text : string)
  logerr("[DYNAMIC EXTRACTION] {text}")


[es(tag=server, on_event=EventLevelLoaded, REQUIRE=dynamic_extraction_controller)]
def dynamic_extraction_controller_on_level_loaded(evt : Event;
                                                  eid : EntityId;
                                                  dynamic_extraction_controller__initialDelay : float;
                                                  dynamic_extraction_controller__pointsPerStep : int;
                                                  var dynamic_extraction_controller__seed : int&;
                                                  var dynamic_extraction_controller__pointEids : EidList;
                                                  var dynamic_extraction_controller__nextStepAt : float&)
  dynamic_extraction_controller__seed = int(get_session_id())
  query() <| $ [es(REQUIRE=dynamic_extraction_point)] (eid aka point_eid : EntityId)
    dynamic_extraction_controller__pointEids |> push(point_eid)

  if length(dynamic_extraction_controller__pointEids) == 0
    logerr_dynamic_extraction("No dynamic extraction points found")
    destroyEntity(eid)
    return

  if dynamic_extraction_controller__pointsPerStep > length(dynamic_extraction_controller__pointEids)
    logerr_dynamic_extraction("pointsPerStep={dynamic_extraction_controller__pointsPerStep} is greater than total points count={length(dynamic_extraction_controller__pointEids)}")
    destroyEntity(eid)
    return

  dynamic_extraction_controller__nextStepAt = get_sync_time() + dynamic_extraction_controller__initialDelay


def get_points_for_time_index(time_index : int;
                              dynamic_extraction_controller__pointEids : EidList;
                              dynamic_extraction_controller__seed : int;
                              dynamic_extraction_controller__pointsPerStep : int)
  var points : array<EntityId>
  let pointsCount = length(dynamic_extraction_controller__pointEids)
  if pointsCount > 0
    for i in range(dynamic_extraction_controller__pointsPerStep)
      let pointIndex = generate_non_duplicate_alternated_sequence_index(time_index + i,
                                                                        pointsCount,
                                                                        dynamic_extraction_controller__seed)
      points |> push(dynamic_extraction_controller__pointEids[pointIndex])
  return <- points


def get_points_for_step(dynamic_extraction_controller__step : int;
                        dynamic_extraction_controller__pointEids : EidList;
                        dynamic_extraction_controller__seed : int;
                        dynamic_extraction_controller__pointsPerStep : int)
  let timeIndex = dynamic_extraction_controller__step * dynamic_extraction_controller__pointsPerStep
  return <- get_points_for_time_index(timeIndex,
                                      dynamic_extraction_controller__pointEids,
                                      dynamic_extraction_controller__seed,
                                      dynamic_extraction_controller__pointsPerStep)


[es(tag=server, no_order)]
def dynamic_extraction_controller_on_update(act : UpdateStageInfoAct;
                                            dynamic_extraction_controller__pointEids : EidList;
                                            dynamic_extraction_controller__interval : float;
                                            dynamic_extraction_controller__seed : int;
                                            dynamic_extraction_controller__pointsPerStep : int;
                                            var dynamic_extraction_controller__nextStepAt : float&;
                                            var dynamic_extraction_controller__step : int&)
  let timestamp = act.curTime

  if timestamp < dynamic_extraction_controller__nextStepAt
    return

  dynamic_extraction_controller__nextStepAt = act.curTime + dynamic_extraction_controller__interval

  var pointsPrevStep <- get_points_for_step(dynamic_extraction_controller__step,
                                            dynamic_extraction_controller__pointEids,
                                            dynamic_extraction_controller__seed,
                                            dynamic_extraction_controller__pointsPerStep)

  dynamic_extraction_controller__step++

  let pointsCurrentStep <- get_points_for_step(dynamic_extraction_controller__step,
                                               dynamic_extraction_controller__pointEids,
                                               dynamic_extraction_controller__seed,
                                               dynamic_extraction_controller__pointsPerStep)

  let pointsPrevStepCount = length(pointsPrevStep)
  for idx in range(pointsPrevStepCount)
    let reverseIdx = pointsPrevStepCount - idx - 1
    let eid = pointsPrevStep[reverseIdx]

    if find_index(pointsCurrentStep, eid) >= 0
      pointsPrevStep |> erase(reverseIdx)
    else
      send_net_event(eid, CmdDynamicExtractionChangeState(enabled = false, timestamp = timestamp))

  for eid in pointsCurrentStep
    send_net_event(eid, CmdDynamicExtractionChangeState(enabled = true, timestamp = timestamp))


[es(tag=server, on_event=EventOnMovingZoneStarted)]
def dynamic_extraction_controller_on_zone_shrink_started(evt : Event;
                                                         eid : EntityId;
                                                         dynamic_extraction_controller__pointEids : EidList)
  for pointEid in dynamic_extraction_controller__pointEids
    query(pointEid) <| $ [es] (extraction__currentState : int)
      if extraction__currentState != int(ExtractionPointState.DISABLED)
        send_net_event(pointEid, CmdDynamicExtractionChangeState(enabled = false, timestamp = get_sync_time()))
  destroyEntity(eid)


[es(tag=server)]
def dynamic_extraction_on_change_state_cmd_server(evt : CmdDynamicExtractionChangeState;
                                                  eid : EntityId;
                                                  var extraction__currentState : int&)
  if evt.enabled
    if extraction__currentState == int(ExtractionPointState.DISABLED)
      extraction__currentState = int(ExtractionPointState.INACTIVE)
  elif extraction__currentState != int(ExtractionPointState.DISABLED)
    addSubTemplate(eid, "disable_extraction_point_when_inactive")


[es]
def dynamic_extraction_on_change_state_cmd(evt : CmdDynamicExtractionChangeState;
                                           var extraction_disable_time__at : float&)
  if evt.enabled
    query() <| $ [es] (dynamic_extraction_controller__interval : float)
      extraction_disable_time__at = evt.timestamp + dynamic_extraction_controller__interval
  else
    extraction_disable_time__at = 0.0
