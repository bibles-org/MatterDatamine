module player_profile_common shared
require app
require ecs
require ecs.safe
require ecs.common
require math.base
require DagorRandom
require DagorSystem
require DagorDataBlock
require daslib/strings_boost


// ugly hack...
def get_build_id(build_name : string; all_builds : Array) : int
  for buildObj in all_builds
    let build = get_ecs_object(buildObj)
    if build != null && get_string(*build, "name", "") == build_name
      return get_int(build, "id") ?? -1
  logerr("[Profile Emulation] can't find build id <{build_name}>")
  return 0


def get_build_price(build_name : string; all_builds : Array) : int
  for buildObj in all_builds
    let build = get_ecs_object(buildObj)
    if build != null && get_string(*build, "name", "") == build_name
      return get_int(build, "reqMoney") ?? 0
  logerr("[Profile Emulation] can't find build price <{build_name}>")
  return 0


def find_item_in_array(unique_id : string; cont : Array; cb : block<(item : Object; idx : int) : void>)
  for contItem, idx in cont, iter_range(cont)
    let item = get_ecs_object(contItem)
    if item != null
      if ((*item).uniqueId ?? "0") == unique_id
        invoke(cb, *item, idx)
        return
