options no_aot
require ecs
require DagorConsole
require DagorSystem
require game.utils.net_utils
require game.es.net_console_macro
require DngNet
require DngActor
require DngHuman

[net_console_cmd(name="walkerphys.max_vertical_dir_change_cosine")]
def console_max_vertical_dir_change_cosine(value = -10.0; @net_hero eid : EntityId)
  query(eid) <| $ [es] (var human_net_phys : HumanActor)
    if value == -10.0
      console_print("{human_net_phys.phys.maxVerticalDirChangeCosine}")
    else
      human_net_phys.phys.maxVerticalDirChangeCosine = value

[net_console_cmd(name="walkerphys.vert_dir_change_tau")]
def console_vert_dir_change_tau(value = 10.0; @net_hero eid : EntityId)
  query(eid) <| $ [es] (var human_net_phys : HumanActor)
    if value == 10.0
      console_print("{human_net_phys.phys.vertDirChangeTau}")
    else
      human_net_phys.phys.vertDirChangeTau = value