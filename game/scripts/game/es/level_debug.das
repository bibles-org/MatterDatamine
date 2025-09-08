options no_aot
require ecs
require ecs.safe
require math.base
require ecs.common
require daslib/strings_boost
require DagorConsole
require game.es.level_common
require game.es.random_common
require DagorTime
require math.random
require DagorDebug3D
require DagorDebug3DSolid
require DagorFiles
require danetlibs.console_commands.main.console_common


[console_cmd(name="level.indoor_pos")]
def check_is_pos_indoor(x : float?; y : float?; z : float?)
  var pos : float3
  if x != null && y != null && z != null
    pos.x = *x
    pos.y = *y
    pos.z = *z
  else
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        pos = transform[3]
      return camera__active
  let indoor = is_pos_indoor(pos)
  let msg = "position {pos} is {indoor ? "indoor" : "outdoor"}"
  console_print(msg)
  print(msg)


[console_processor]
def level_append_transform_template(args : array<string>;
                                    collect : bool;
                                    var hints : ConsoleProcessorHints)
  let cmd = "level.append_transform_template"
  let fileDefaultValue = "transforms.blk"
  if collect
    let inputs <- args[0] |> split(" ")
    add_hints(fixed_array(CommandArgDesc(name = "templ", hintType = CommandArgHintType.TemplateName, defaultValue = "am_respawn_raid"),
                       CommandArgDesc(name = "file", hintType = CommandArgHintType.Default, defaultValue = fileDefaultValue),
                       CommandArgDesc(name = "create_now", hintType = CommandArgHintType.Default, defaultValue = "1")),
              cmd, inputs, /*hints_count*/ 20, /*threshold_cam_distance_sq*/ square(0.0), hints)
  elif args[0] == cmd
    let argc = args |> length()
    let templ = argc >= 2 ? args[1] : "am_respawn_raid"
    let file = argc >= 3 ? args[2] : fileDefaultValue
    let createNow = argc >= 4 ? to_int(args[3]) != 0 : true
    find_query() <| $ [es(REQUIRE=watchedByPlr)] (transform : float3x4)
      if file != "" && file != "-"
        df_open(file, DF_WRITE | DF_APPEND) <| $(outputFile)
          outputFile |> df_puts("entity\{\n")
          outputFile |> df_puts("  _template:t=\"{templ}\"\n")
          outputFile |> df_puts("  transform:m=[[{transform[0]}] [{transform[1]}] [{transform[2]}] [{transform[3]}]]\n")
          outputFile |> df_puts("\}\n\n")
          console_print("{templ} added to {file} with transform={transform}")

      if createNow
        createEntity(templ) <| $(var init : ComponentsInitializer)
          init |> set("transform", transform)

      return true
    return true

  return false


[console_cmd(name="level.debug_custom_game_object")]
def level_debug_custom_game_object(custom_game_object_name = "")
  let isExisted = find_query() <| $ [es] (eid : EntityId; var debug_custom_game_objects__names : StringList&)
    if empty(custom_game_object_name)
      destroyEntity(eid)
    else
      let idx = debug_custom_game_objects__names |> find_index(custom_game_object_name)
      if idx == -1
        debug_custom_game_objects__names |> push(custom_game_object_name)
      else
        debug_custom_game_objects__names |> erase(idx)
    return true

  if !isExisted && !empty(custom_game_object_name)
    createEntity("debug_custom_game_objects") <| $(var init)
      using() <| $(var namesList : StringList)
        namesList |> push(custom_game_object_name)
        init |> set("debug_custom_game_objects__names", namesList)


[es(tag=dev, tag=render, no_order)]
def debug_custom_game_object(evt : UpdateStageInfoRenderDebug; debug_custom_game_objects__names : StringList)
  let lineEnd = float3(0.0, 150.0, 0.0)
  query() <| $ [es] (custom_game_object__name : string; transform : float3x4)
    if !empty(custom_game_object__name) && !has_value(debug_custom_game_objects__names, custom_game_object__name)
      return
    var seed = int(ecs_hash(custom_game_object__name))
    let color = _rnd_int(seed, int2(0, 16777215))
    draw_debug_line_buffered(transform[3], transform[3] + lineEnd, E3DCOLOR(0xFF000000 + uint(color)), 1)
    draw_debug_text_mark_buffered(transform[3] + lineEnd, custom_game_object__name, 1, E3DCOLOR(0xFF000000 + uint(color)))


[console_cmd(name="level.generate_level_evnironment_index_test")]
def generate_level_evnironment_index(seed : int = 0)
  let indicesCount = 5
  let chainSegments = 3
  let timeInterval = 5
  console_print("{generate_level_evnironment_index(get_time_msec()/1000, timeInterval, indicesCount, chainSegments, seed)}")


[console_cmd(name="level.get_level_weather_and_time")]
def console_get_level_weather_and_time(level_name : string;
                                       unix_time : int)
  parse_level_weather_and_time_from_scene("content/active_matter/gamedata/scenes/{level_name}") <| $(level__weatherChoice : Object;
                                                                                                     level__timeVec : Array;
                                                                                                     level_synced_environment__timeOfDayChangeInterval : int;
                                                                                                     level_synced_environment__timeOfDayChainSegments : int;
                                                                                                     level_synced_environment__timeOfDaySeed : int;
                                                                                                     level_synced_environment__weatherChangeInterval : int;
                                                                                                     level_synced_environment__weatherChainSegments : int;
                                                                                                     level_synced_environment__weatherSeed : int)
    let timeOfDayIndex = generate_level_evnironment_index(unix_time, level_synced_environment__timeOfDayChangeInterval,
                                                        length(level__timeVec), level_synced_environment__timeOfDayChainSegments,
                                                        level_synced_environment__timeOfDaySeed)
    console_print("time={level__timeVec[timeOfDayIndex]}")

    let weatherIndex = generate_level_evnironment_index(unix_time, level_synced_environment__weatherChangeInterval,
                                                      length(level__weatherChoice), level_synced_environment__weatherChainSegments,
                                                      level_synced_environment__weatherSeed)
    for i, val in iter_range(level__weatherChoice), level__weatherChoice
      if i == weatherIndex
        let weatherTemplate = getTemplateByName(val.key)
        if weatherTemplate != null
          let wetherLocName = getTemplateComponent(*weatherTemplate, "skies_settings__locName") ?? ""
          console_print("wetherLocName='{wetherLocName}'")
        break
