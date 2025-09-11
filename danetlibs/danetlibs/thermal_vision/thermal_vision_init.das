options no_aot

require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed

[export]
def load_thermal_vision(base_path : string) : bool
  if !is_render_lib_allowed("thermal_vision")
    return true
  var ok = true
  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok
    // if ecs_has_tag("dev") || is_in_aot()
    //   ok = load_sub_folder(base_path, "debug") && ok
  return ok
