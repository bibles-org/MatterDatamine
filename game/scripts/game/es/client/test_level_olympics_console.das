options no_aot

require DagorConsole
require ecs
require ecs.safe
require app
require game.events.events_active_matter
require DngHuman
require DagorDebug3DSolid
require DagorDebug3D
require DagorMath
require strings
require game.es.item_equip_common


[console_cmd(name="olympics.create_runner")]
def olympics_create_runner(weight : float; chronogene_1 : string = ""; chronogene_2 : string = ""; chronogene_3 : string = ""; chronogene_4 : string = "")
  using() <| $(var chronogenes : StringList)
    if chronogene_1 != ""
      chronogenes |> push(chronogene_1)
    if chronogene_2 != ""
      chronogenes |> push(chronogene_2)
    if chronogene_3 != ""
      chronogenes |> push(chronogene_3)
    if chronogene_4 != ""
      chronogenes |> push(chronogene_4)

    find_query() <| $ [es(REQUIRE=running_olympics_start)] (transform : float3x4)
      createEntity("am_militant_bot+equipped_bot+running_olympics_runner") <| $(init)
        set(init, "running_olympics_runner__runStart", get_sync_time())
        set(init, "transform", transform)
        set(init, "running_olympics_runner__overrideWeight", weight)
        set(init, "running_olympics_runner__chronogenes", chronogenes)
        set(init, "beh_tree__enabled", true)
        set(init, "beh_tree__node", "running_olympian")
        set(init, "equipped_bot__equipmentGeneratorName", "olympics_equipment_generator")
        set(init, "equipped_bot__equipmentGeneratorCorruptionChance", 0.0)
      return true


[es(on_disappear, REQUIRE=initial_loadout_creation)]
def olympics_give_chonogenes_to_runner(evt : Event; running_olympics_runner__chronogenes : StringList; eid : EntityId)
  var chronogeneIndex = 1
  for chronogeneTemplate in running_olympics_runner__chronogenes
    create_item_in_slot(string(chronogeneTemplate), INVALID_ENTITY_ID, INVALID_ENTITY_ID,
                                  eid, "equipment_chronogene_secondary_{chronogeneIndex}") <| $ [unused_argument(init)] (var init)
      return
    chronogeneIndex++


[console_cmd(name="olympics.reset_results")]
def olympics_reset_results()
  find_query() <| $ [es] (var running_olympics__results : Array)
    clear(running_olympics__results)
    return true


[es(on_disappear)]
def olympics_finish_run(evt : Event;
                        human_net_phys : HumanActor;
                        running_olympics_runner__overrideWeight : float;
                        running_olympics_runner__runStart : float)
  var startPos : float3
  var finishPos : float3
  find_query() <| $ [es(REQUIRE=running_olympics_start)] (transform : float3x4)
    startPos = transform[3]
    return true

  find_query() <| $ [es(REQUIRE=running_olympics_finish)] (transform : float3x4)
    finishPos = transform[3]
    return true

  let curTime = get_sync_time()
  let raceTime = curTime - running_olympics_runner__runStart

  find_query() <| $ [es] (var running_olympics__results : Array)
    using() <| $(var result : Object)
      set(result, "weight", running_olympics_runner__overrideWeight)
      set(result, "time", raceTime)
      set(result, "stamina", human_net_phys.phys.currentState.stamina)
      push(running_olympics__results, result)
    return true


[es(REQUIRE=running_olympics_checkpoint_processor)]
def olympics_process_checkpoint(evt : EventGameTrigger;
                                game_trigger_processor__onTriggerHash : int)
  if evt.triggerHash != game_trigger_processor__onTriggerHash
    return

  let runner = evt.target
  query(runner) <| $ [es] (running_olympics_runner__prevFrameSpeedMult : float;
                           running_olympics_runner__prevFrameSpeed : float;
                           running_olympics_runner__runStart : float;
                           running_olympics_runner__overrideWeight : float;
                           var running_olympics_runner__runCheckpoints : FloatList)
    let curTime = get_sync_time()
    push(running_olympics_runner__runCheckpoints, curTime)
    let weight = fmt(":.2f", running_olympics_runner__overrideWeight)
    let checkpointNum = length(running_olympics_runner__runCheckpoints)
    let time = fmt(":.2f", curTime - running_olympics_runner__runStart)
    let msMult = fmt(":.2f", running_olympics_runner__prevFrameSpeedMult)
    let speed = fmt(":.2f", running_olympics_runner__prevFrameSpeed)
    console_print("runner <{runner}> with weight {weight} reached checkpoint {checkpointNum} at {time} (msMult = {msMult}, speed = {speed})")


[es(REQUIRE=running_olympic_result_resetter)]
def olympics_reset_running__results(evt : EventGameTrigger;
                                    game_trigger_processor__onTriggerHash : int)
  if evt.triggerHash != game_trigger_processor__onTriggerHash
    return

  find_query() <| $ [es] (var running_olympics__results : Array)
    clear(running_olympics__results)
    return true


[es(before=human_weight_influence_server_es)]
def olympics_override_runner_weight(update : UpdateStageInfoAct;
                                    running_olympics_runner__overrideWeight : float;
                                    var human_inventory__currentWeight : float&)
  human_inventory__currentWeight = running_olympics_runner__overrideWeight


[es(after=(human_weight_influence_server_es, human_injured_speed_reducer))]
def olympics_record_speed_mult(update : UpdateStageInfoAct;
                               human_net_phys : HumanActor;
                               human_net_phys__velocity : float3;
                               var running_olympics_runner__prevFrameSpeed : float&;
                               var running_olympics_runner__prevFrameSpeedMult : float&)
  running_olympics_runner__prevFrameSpeedMult = human_net_phys.phys.currentState.moveSpeedMult
  running_olympics_runner__prevFrameSpeed = length(human_net_phys__velocity)


[es(after=olympics_record_speed_mult, tag=dev)]
def olympics_display_runners_stats(update : UpdateStageInfoAct;
                                   transform : float3x4;
                                   running_olympics_runner__overrideWeight : float;
                                   running_olympics_runner__prevFrameSpeedMult : float;
                                   running_olympics_runner__prevFrameSpeed : float;
                                   human_net_phys : HumanActor)
  let drawPoint = transform[3] + float3(0.0, 2.0, 0.0)
  let weightText = "weight: " + fmt(":.2f", running_olympics_runner__overrideWeight)
  let speedMultText = "speedMult: " + fmt(":.2f", running_olympics_runner__prevFrameSpeedMult)
  let speedText = "speed: " + fmt(":.2f", running_olympics_runner__prevFrameSpeed)
  let staminaText = "stamina: " + fmt(":.1f", human_net_phys.phys.currentState.stamina)
  let text = "{weightText} ;; {speedMultText} ;; {speedText} ;; {staminaText}"
  add_debug_text_mark(drawPoint, text, -1, 0., E3DCOLOR(0xffcccccc))


[es(no_order, tag=dev)]
def olympics_display_runners_results(update : UpdateStageInfoAct;
                                     transform : float3x4;
                                     running_olympics__results : Array)
  var offset = float3(0.0, 0.0, 0.0)
  let oddColor = E3DCOLOR(0xffbbffbb)
  let evenColor = E3DCOLOR(0xffffbbff)
  var index = 0
  for res in running_olympics__results
    let obj = res as Object
    let weight = obj?.weight ?? -1.0
    let time = obj?.time ?? -1.0
    let stamina = obj?.stamina ?? -1.0
    let drawPoint = transform[3] + offset
    let weightText = "weight: " + fmt(":.2f", weight)
    let timeText = "time: " + fmt(":.2f", time)
    let staminaText = "stamina: " + fmt(":.3f", stamina)
    add_debug_text_mark(drawPoint, "{weightText} ;; {timeText} ;; {staminaText}", -1, 0., index % 2 == 0 ? evenColor : oddColor)
    offset += float3(0.0, 0.2, 0.0)
    index++