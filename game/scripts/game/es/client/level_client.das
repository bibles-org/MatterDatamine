require ecs
require ecs.safe
require app
require level
require game.es.level_common
require daSkies

[es(tag=gameClient, on_appear, REQUIRE=level_synced_environment)]
def level_synced_environment_init_client(evt : Event;
                                         level__timeVec : Array;
                                         level_synced_environment__unixTime : int;
                                         level_synced_environment__timeOfDayChangeInterval : int;
                                         level_synced_environment__timeOfDayChainSegments : int;
                                         level_synced_environment__timeOfDaySeed : int;
                                         var level__timeOfDay : float&)
  level_environment_print_log("level_synced_environment__unixTime={level_synced_environment__unixTime}")

  // Time of day
  let timeOfDayIndex = generate_level_evnironment_index(level_synced_environment__unixTime, level_synced_environment__timeOfDayChangeInterval,
                                                        length(level__timeVec), level_synced_environment__timeOfDayChainSegments,
                                                        level_synced_environment__timeOfDaySeed)
  let timeOfDay = level__timeVec?[timeOfDayIndex] ?? 12.0
  level__timeOfDay = timeOfDay
  level_environment_print_log("timeOfDayIndex={timeOfDayIndex}, level__timeOfDay={level__timeOfDay}")
  set_daskies_time(timeOfDay)
