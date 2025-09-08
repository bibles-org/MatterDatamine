module status_tip_common shared
require ecs
require app
require ecs.safe
require DagorSystem


def create_status_tip(tip_template_name : string; increase_time_if_exist = true; tip_data : Object const? = null)
  let templ = getOrBuildTemplateByName(tip_template_name)
  if templ == null
    logerr("[STATUS TIP] Can't find template for tip: <{tip_template_name}>")
    return
  let tipTextName = getTemplateComponent(*templ, "status_tip__text") ?? ""
  if empty(tipTextName)
    logerr("[STATUS TIP] Can't find 'status_tip__text' component in tip: <{tip_template_name}>")
    return
  let tipAlreadyExist = find_query() <| $ [es] (status_tip__text : string;
                                                game_effect__timeToDestroy : float;
                                                var game_effect__clientDestroyAt : float&)
    if status_tip__text != tipTextName
      return false
    if increase_time_if_exist
      game_effect__clientDestroyAt = get_sync_time() + game_effect__timeToDestroy
    return true
  if !tipAlreadyExist
    createEntity(tip_template_name) <| $(var init)
      if tip_data != null
        set(init, "status_tip__data", *tip_data)