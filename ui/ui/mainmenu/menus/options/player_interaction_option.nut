from "settings" import get_setting_by_blk_path
from "%ui/mainMenu/menus/options/options_lib.nut" import getOnlineSaveData, optionCheckBox, optionCtor
import "%ui/charClient/charClient.nut" as char
from "dagor.random" import rnd_int
from "%dngscripts/globalState.nut" import nestWatched

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

const FRIENDS_INVITATION_OPTIONS = "gameplay/ignore_friend_requests"
const STREAMER_MODE_OPTIONS = "option/streamerMode"

let friendsInvitationSave = getOnlineSaveData(FRIENDS_INVITATION_OPTIONS, @() false)
let streamerModeSave = getOnlineSaveData(STREAMER_MODE_OPTIONS, @() false)

let friendsInvitationOption = optionCtor({
  name = loc("gameplay/ignore_friend_requests")
  setValue = @(_v) char?.contacts_can_add_setting(friendsInvitationSave.watch.get(), @(v) friendsInvitationSave.setValue(v))
  var = friendsInvitationSave.watch
  defVal = false
  widgetCtor = optionCheckBox
  restart = false
  tab = "Game"
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})

let playerRandName = nestWatched("playerRandName", $"{loc("player")}_{rnd_int(1, 9999)}", null)

let streamerModeOption = optionCtor({
  name = loc("option/streamerMode")
  var = streamerModeSave.watch
  setValue = function(v) {
    if (playerRandName.get() != null)
      playerRandName.set($"{loc("player")}_{rnd_int(1, 9999)}")
    streamerModeSave.setValue(v)
  }
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  tab = "Game"
  hint = loc("option/streamerModeDesc")
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})


return {
  friendsInvitationOption
  streamerModeOption
  isStreamerMode = streamerModeSave.watch
  playerRandName
}