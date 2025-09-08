require ecs
require DagorSystem
require DagorDataBlock
require game.events.events_active_matter


[es(tag=gameClient, on_appear)]
def activity_helper_play_sound(evt : Event;
                               activity_helper_marker__ownerEid : EntityId)
  var isMuted = false
  var isSetted = false
  dgs_get_settings() |> datablock_get_block("gameplay") <| $(blk)
    isSetted = blk |> datablock_find_param("msSecondMapHelp") >= 0
    isMuted = !(blk |> datablock_getBool("msSecondMapHelp", true))

  if isSetted && isMuted
    return

  query(activity_helper_marker__ownerEid) <| $ [es] (watchedByPlr : EntityId)
    query(watchedByPlr) <| $ [es] (var activity_helper__helpsLeft : int&; is_local : bool)
      if !is_local
        return
      activity_helper__helpsLeft = isSetted ? -1 : max(-1, activity_helper__helpsLeft - 1)
      isMuted = isMuted || (!isSetted && activity_helper__helpsLeft < 0)
      if isMuted
        return

      if activity_helper__helpsLeft == 0
        sendEvent(watchedByPlr, CmdStartAssistantSpeak(scriptName = "select_search_settings", skipBeepSound = true))
      else
        sendEvent(watchedByPlr, CmdStartAssistantSpeak(scriptName = "activity_help_bark", skipBeepSound = true))
