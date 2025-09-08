options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_weaponry_hit_fx(base_path : string) : bool
  var ok = true

  ok = load_sub_folder(base_path, "main") && ok

  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok

  return ok


