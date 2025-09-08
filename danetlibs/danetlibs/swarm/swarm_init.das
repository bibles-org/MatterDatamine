options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_swarm(base_path : string) : bool
  var ok = true

  if ecs_has_tag("input") || is_in_aot() // check input as real game client tag, netClient is unset on game start
    ok = load_sub_folder(base_path, "main") && ok

  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok

  return ok



