options no_aot
require ecs
require ecs.common
require math.base
require DagorConsole
require game.es.tweening_common
require strings
require daslib/strings_boost
require danetlibs.console_commands.main.console_common


[console_processor]
def tween_sphere_zone_radius_smooth_cmd(args : array<string>;
                                        collect : bool;
                                        var hints : ConsoleProcessorHints)
  let cmd = "tween.sphere_zone_radius_smooth"
  if collect
    let inputs <- args[0] |> split(" ")
    add_hints(fixed_array(CommandArgDesc(name = "eid", hintType = CommandArgHintType.EntityId),
                       CommandArgDesc(name = "radius", hintType = CommandArgHintType.Default),
                       CommandArgDesc(name = "time", hintType = CommandArgHintType.Default)),
              cmd, inputs, /*hints_count*/ 20, /*threshold_cam_distance_sq*/ square(50.0), hints)
  elif args[0] == cmd
    let argc = args |> length()
    let eid = EntityId(argc >= 2 ? to_uint(args[1]) : 0u)
    let radius = argc >= 3 ? to_float(args[2]) : 1.0
    let time = argc >= 4 ? to_float(args[3]) : 1.0

    tween_sphere_zone_radius_smooth(eid, radius, time)

    return true

  return false


[console_processor]
def tween_transform_scale_smooth_cmd(args : array<string>;
                                     collect : bool;
                                     var hints : ConsoleProcessorHints)
  let cmd = "tween.transform_scale_smooth"
  if collect
    let inputs <- args[0] |> split(" ")
    add_hints(fixed_array(CommandArgDesc(name = "eid", hintType = CommandArgHintType.EntityId),
                       CommandArgDesc(name = "scale_x", hintType = CommandArgHintType.Default),
                       CommandArgDesc(name = "scale_y", hintType = CommandArgHintType.Default),
                       CommandArgDesc(name = "scale_z", hintType = CommandArgHintType.Default),
                       CommandArgDesc(name = "time", hintType = CommandArgHintType.Default)),
              cmd, inputs, /*hints_count*/ 20, /*threshold_cam_distance_sq*/ square(50.0), hints)
  elif args[0] == cmd
    let argc = args |> length()
    let eid = EntityId(argc >= 2 ? to_uint(args[1]) : 0u)
    let scaleX = argc >= 3 ? to_float(args[2]) : 1.0
    let scaleY = argc >= 4 ? to_float(args[3]) : 1.0
    let scaleZ = argc >= 5 ? to_float(args[4]) : 1.0
    let time = argc >= 6 ? to_float(args[5]) : 1.0

    tween_transform_scale_smooth(eid, float3(scaleX, scaleY, scaleZ), time)

    return true

  return false