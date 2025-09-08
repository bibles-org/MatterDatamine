require ecs
require ecs.ecs_quirrel
require game.es.level_common


[quirrel_bind(module_name="das.level")]
def generate_level_evnironment_index(cur_time_seconds : int;
                                     interval_seconds : int;
                                     indices_count : int;
                                     chain_segments : int;
                                     seed : int)
  return level_common::generate_level_evnironment_index(cur_time_seconds, interval_seconds, indices_count, chain_segments, seed)


[quirrel_bind(module_name="das.level")]
def parse_level_weather_and_time_from_scene(scene_path : string;
                                            var out_result : Object)
  return level_common::parse_level_weather_and_time_from_scene(scene_path) <| $(level__weatherChoice : Object;
                                                                                level__timeVec : Array;
                                                                                level_synced_environment__timeOfDayChangeInterval : int;
                                                                                level_synced_environment__timeOfDayChainSegments : int;
                                                                                level_synced_environment__timeOfDaySeed : int;
                                                                                level_synced_environment__weatherChangeInterval : int;
                                                                                level_synced_environment__weatherChainSegments : int;
                                                                                level_synced_environment__weatherSeed : int)
    using() <| $(var weatherChoiseArray : Array)
      for it in level__weatherChoice
        weatherChoiseArray |> push(it.key)
      out_result |> set("level__weatherChoice", weatherChoiseArray)

    out_result |> set("level__timeVec", level__timeVec)
    out_result |> set("level_synced_environment__timeOfDayChangeInterval", level_synced_environment__timeOfDayChangeInterval)
    out_result |> set("level_synced_environment__timeOfDayChainSegments", level_synced_environment__timeOfDayChainSegments)
    out_result |> set("level_synced_environment__timeOfDaySeed", level_synced_environment__timeOfDaySeed)
    out_result |> set("level_synced_environment__weatherChangeInterval", level_synced_environment__weatherChangeInterval)
    out_result |> set("level_synced_environment__weatherChainSegments", level_synced_environment__weatherChainSegments)
    out_result |> set("level_synced_environment__weatherSeed", level_synced_environment__weatherSeed)
