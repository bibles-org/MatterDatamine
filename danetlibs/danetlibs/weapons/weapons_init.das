options no_aot

require ecs
require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed

[export]
def load_weapons(base_path : string) : bool
  if !is_render_lib_allowed("weapons")
    return true

  var ok = true

  ok = load_sub_folder(base_path, "main") && ok
  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "fx") && ok

  return ok


