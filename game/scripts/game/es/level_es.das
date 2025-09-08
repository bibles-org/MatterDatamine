require ecs
require ecs.safe
require app
require level
require rapidjson
require DngNet
require game.es.level_common
require game.es.ecs_common
require DagorSystem
require strings


[es(on_event=EventLevelLoaded)]
def level_loaded_es(evt : Event;
                    var level__loadedAtTime : float&)
  level__loadedAtTime = get_sync_time()

[es(tag=server, on_appear, REQUIRE=level_synced_environment)]
def level_synced_environment_init_delayed_server(evt : Event;
                                                 eid : EntityId;
                                                 level_synced_environment__delayedSetup : float)
  let curTime = get_sync_time()
  let setupAt = curTime + level_synced_environment__delayedSetup
  level_environment_print_log("Delayed setup will be invoked at {setupAt}. Curtime={curTime}")
  addSubTemplate(eid, "level_synced_environment_delayed") <| $(var init)
    init |> set("level_synced_environment__delayedSetupAt", setupAt)

def getDebugTimeOfTheDay()
  let arg = dgs_get_argv("time_of_the_day")
  if arg == ""
    return -1.0

  var res : ConversionResult
  var ofs : int
  let input = float(arg, res, ofs)
  if res == ConversionResult.ok && ofs == length(arg)
    level_environment_print_log("Read time of the day from `time_of_the_day` commandline argument: {input}")
    return input
  logerr("Failed to parse time_of_the argument: '{arg}'")
  return -1.0

def getDebugWeatherName()
  let arg = dgs_get_argv("weather_name")
  if arg == ""
    return ""
  level_environment_print_log("Read index of weather from `weather_name` commandline argument: {arg}")
  return arg

[es(tag=server, REQUIRE=level_synced_environment, no_order)]
def level_synced_environment_init_server(info : UpdateStageInfoAct;
                                         eid : EntityId;
                                         level__timeVec : Array;
                                         level__weatherChoice : Object;
                                         level_synced_environment__timeOfDayChangeInterval : int;
                                         level_synced_environment__timeOfDayChainSegments : int;
                                         level_synced_environment__timeOfDaySeed : int;
                                         level_synced_environment__weatherChangeInterval : int;
                                         level_synced_environment__weatherChainSegments : int;
                                         level_synced_environment__weatherSeed : int;
                                         var level__timeOfDay : float&;
                                         var level_synced_environment__unixTime : int&;
                                         var level_synced_environment__delayedSetupAt : float&)
  if level_synced_environment__delayedSetupAt >= 0.0 && info.curTime < level_synced_environment__delayedSetupAt
    return

  level_synced_environment__delayedSetupAt = -1.0
  level_environment_print_log("Delayed setup has been invoked at {info.curTime}")
  if !get_matching_invite_data().IsNull
    level_synced_environment__unixTime = json_get_or(get_matching_invite_data(), "startTimestamp", 0)
    level_environment_print_log("level_synced_environment__unixTime SET: {level_synced_environment__unixTime}.")
  else
    level_environment_print_log("level_synced_environment__unixTime ISN'T SET because inviteData is null.")

  // Time of day
  let debugTimeOfTheDay = getDebugTimeOfTheDay()
  if debugTimeOfTheDay >= 0.0
    level__timeOfDay = float(debugTimeOfTheDay)

  else
    let timeOfDayIndex = generate_level_evnironment_index(level_synced_environment__unixTime,
                         level_synced_environment__timeOfDayChangeInterval, length(level__timeVec),
                         level_synced_environment__timeOfDayChainSegments, level_synced_environment__timeOfDaySeed)
    let defTimeOfDay = 9.0
    if timeOfDayIndex >= int(level__timeVec.size) || timeOfDayIndex < 0
      level_environment_print_log("timeOfDayIndex = {timeOfDayIndex} not in level__timeVec. Going to use default time of day: {defTimeOfDay}")
      level__timeOfDay = defTimeOfDay
    else
      let timeOfDay = level__timeVec?[timeOfDayIndex] ?? defTimeOfDay
      level__timeOfDay = timeOfDay
      level_environment_print_log("timeOfDayIndex={timeOfDayIndex}, level__timeOfDay={level__timeOfDay}")

  // Weather
  let debugWeatherName = getDebugWeatherName()

  if debugWeatherName != ""
    if get_float(level__weatherChoice, "debugWeatherName") != null
      select_weather_preset(debugWeatherName)
    else
      level_environment_print_log("debugWeatherName={debugWeatherName} not found in weather presets")
  else
    let weatherIndex = generate_level_evnironment_index(
                           level_synced_environment__unixTime, level_synced_environment__weatherChangeInterval,
                           length(level__weatherChoice), level_synced_environment__weatherChainSegments,
                           level_synced_environment__weatherSeed)
    for i, val in iter_range(level__weatherChoice), level__weatherChoice
      if i == weatherIndex
        level_environment_print_log("weatherIndex={weatherIndex}, weather={val.key}")
        select_weather_preset(val.key)
        break

  removeSubTemplate(eid, "level_synced_environment_delayed")

[es(tag=server, on_appear, REQUIRE=ri_extra_gen__blk)]
def ri_extra_gen_on_appear(evt : Event;
                           eid : EntityId)
  // Debug log to mark ri_extra_gen appear moment
  print("ri_extra_gen_on_appear: {get_entity_info(eid)}")


[es(tag=server, on_event=EventLevelLoaded, after=ri_extra_gen_blk_es, REQUIRE=ri_extra_gen__blk)]
def ri_extra_gen_on_level_loaded(evt : Event;
                                 eid : EntityId)
  // Debug log to mark ri_extra_gen on level loaded moment
  print("ri_extra_gen_on_level_loaded: {get_entity_info(eid)}")