options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_package_helicopter(base_path : string) : bool
  var ok = true

  if ecs_has_tag("input") || is_in_aot()
    ok = load_sub_folder(base_path, "input") && ok

  return ok