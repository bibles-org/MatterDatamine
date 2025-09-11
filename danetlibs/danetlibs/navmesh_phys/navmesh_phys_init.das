options no_aot

require ecs
require ecs.fs
require ECSGlobalTags
require RenderLibsAllowed


[export]
def load_navmesh_phys(base_path : string) : bool
  if !is_render_lib_allowed("navmesh_phys")
    return true

  var ok = true

  ok = load_sub_folder(base_path, "main") && ok
  ok = load_sub_folder(base_path, "main/ai") && ok

  return ok



