require ecs
require game.es.flashlights.flashlight_common
require game.events.events_active_matter


[es(tag=server, no_order)]
def bot_use_weapon_flashlight_handler(info : ParallelUpdateFrameDelayed;
                                      attaches_list : EidList;
                                      beh_tree__enabled : bool;
                                      militant__indoor : bool;
                                      bot_flashlight__enabled : bool = true;
                                      var bot_flashlight__nextAtTime : float&)
  if !bot_flashlight__enabled || info.curTime < bot_flashlight__nextAtTime
    return
  if beh_tree__enabled
    for attachEid in attaches_list
      query(attachEid) <| $ [es] (attached_flashlight_controller__entityEid : EntityId;
                                  flashlight_device__type : int)
        if flashlight_device__type != int(FlashlightType.DEFAULT)
          return
        query(attached_flashlight_controller__entityEid) <| $ [es] (var attached_flashlight__isOn : bool&)
          attached_flashlight__isOn = militant__indoor
  bot_flashlight__nextAtTime = info.curTime + 2.0
