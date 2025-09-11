options no_aot

require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed


[export]
def load_animchar_attach(base_path : string) : bool
  if !is_render_lib_allowed("animchar_attach")
    return true

  var ok = true

  ok = load_sub_folder(base_path, "main") && ok

  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok

  return ok