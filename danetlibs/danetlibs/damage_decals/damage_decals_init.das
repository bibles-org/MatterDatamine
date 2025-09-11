options no_aot

require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed

[export]
def load_damage_decals(base_path : string) : bool
  if !is_render_lib_allowed("damage_decals")
    return true
  var ok = true
  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok

  return ok


