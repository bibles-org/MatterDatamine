options no_aot

require ecs
require ecs.fs
require app
require ECSGlobalTags


[export]
def load_weapons(base_path : string) : bool
  var ok = true

  ok = load_sub_folder(base_path, "main") && ok
  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "fx") && ok

  return ok


