from "%ui/components/commonComponents.nut" import mkTabs, mkConsoleScreen
from "%ui/mainMenu/notificationMark.nut" import mkNotificationMark
from "%ui/fonts_style.nut" import body_txt
from "%sqstd/string.nut" import utf8ToUpper
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel

from "%ui/ui_library.nut" import *

let { musicPlayerTab, unseenTracksCount, MUSIC_PLAYER_ID } = require("%ui/mainMenu/audioModule/music_player.nut")
let { settingsTabUi, SETTINGS_TAB_ID } = require("%ui/mainMenu/audioModule/audio_settings.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

const AudioModuleId = "audioModule"

let audioModuleName = loc("audiomodule")
let audioModuleTitle = utf8ToUpper(loc("audiomodule/title"))

let audioTabConstr = @(params) @() {
  watch = unseenTracksCount
  flow = FLOW_HORIZONTAL
  margin = static [fsh(1), fsh(2)]
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("musicPlayer")
    }.__update(body_txt).__update(params)
    mkNotificationMark(unseenTracksCount)
  ]
}

let tabsList = [
  { id = MUSIC_PLAYER_ID, childrenConstr = audioTabConstr, content = musicPlayerTab }
  { id = SETTINGS_TAB_ID, text = loc("audiomodule/settings"), content = settingsTabUi }
]

let currentTab = Watched(MUSIC_PLAYER_ID)

let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

let content = function(){
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = currentTab.get()
    onChange = @(tab) currentTab.set(tab.id)
  })
  let tabContent = getCurTabContent(currentTab.get())
  return {
    watch = currentTab
    size = flex()
    flow = FLOW_VERTICAL
    children = [
      tabsUi,
      tabContent ?? getCurTabContent(MUSIC_PLAYER_ID)
    ]
  }
}

let audioModuleUi = wrapInStdPanel(AudioModuleId, mkConsoleScreen(content), audioModuleTitle)

let audioNotifications = Computed(function() {
  local notificationsCount = unseenTracksCount.get()
  local notificationsType = "reward"

  return {
    notificationsCount
    notificationsType
  }
})

return freeze({
  AudioModuleId
  audioModuleUi
  audioModuleName
  audioNotifications
  audioModuleIsAvailable = Computed(@() !isOnboarding.get())
})
