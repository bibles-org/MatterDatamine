options no_aot

require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed

[export]
def load_package_aircraft(base_path : string) : bool
  if !is_render_lib_allowed("package_aircraft")
    return true

  var ok = true

  if ecs_has_tag("input") || is_in_aot()
    ok = load_sub_folder(base_path, "input") && ok

  if typeinfo builtin_module_exists(TargetSignature)
    ok = load_sub_folder(base_path, "weapons") && ok

  ok = load_sub_folder(base_path, "es") && ok

  return ok