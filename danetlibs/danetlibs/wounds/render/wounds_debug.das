options no_aot
require ecs
require DagorConsole
require DagorShaders

enum DebugMode : int
  DISABLE = 0
  COLORMAP = 1

[console_cmd(name="wounds.debug_torn_wounds_mode", hint="<mode 0 - disable, 1 - colorMap>")]
def apply_torn_wounds_debug_mode_cmd(mode : int)
  let debug_torn_woundsVarId = get_shader_variable_id("debug_torn_wounds")
  if (mode == int(DebugMode.DISABLE))
    DagorShaders::set_int(debug_torn_woundsVarId, 0)
  else
    DagorShaders::set_int(debug_torn_woundsVarId, 1)
