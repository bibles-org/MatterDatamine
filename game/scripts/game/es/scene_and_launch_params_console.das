options no_aot
require ecs
require DagorDataBlock
require DagorConsole
require DagorSystem
require ecs.ecs_template


[ecs_template]
struct hero_spawned_once
  hero_spawned_once : Tag


def exec_commands_from_block_name(name : string)
  let cmds = dgs_get_settings() |> datablock_get_block_by_name(name)
  if cmds == null
    return
  for i in 0u..cmds.paramCount
    if *cmds |> datablock_getParamType(i) == int(DataBlockParamType.TYPE_STRING)
      console_command(*cmds |> datablock_getStr(int(i)))

[es(tag=dev, on_event=EventLevelLoaded)]
def exec_console_commands_on_level_load(evt : Event)
  exec_commands_from_block_name("execute_cmds_on_load")

[es(tag=dev, on_appear, REQUIRE=hero)]
def exec_console_commands_on_fisrt_player_spawn(evt : Event)
  let isFirstHeroSpawn = !(find_query() <| $ [es(REQUIRE=hero_spawned_once)] () => true)
  if !isFirstHeroSpawn
    return
  createEntity("hero_spawned_once")
  exec_commands_from_block_name("execute_cmds_on_spawn")

  query() <| $ [es] (execute_cmds_on_spawn : StringList)
    for cmd in execute_cmds_on_spawn
      console_command(string(cmd))

[es(tag=dev, on_appear)]
def exec_console_commands_from_scene_entities(evt : Event; execute_cmds_on_load : StringList)
  for cmd in execute_cmds_on_load
    console_command(string(cmd))

// rendinsts are loaded after level and we have commands which might want to run after that
[es(tag=dev, on_event=EventRendinstsLoaded)]
def exec_console_commands_from_scene_entities_on_ri_load(evt : Event; execute_cmds_on_ri_load : StringList)
  for cmd in execute_cmds_on_ri_load
    console_command(string(cmd))
