from "%ui/ui_library.nut" import *
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
import "%ui/hud/menus/notes/career.nut" as careerTab

let { mkConsoleScreen, mkTabs } = require("%ui/components/commonComponents.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { playerProgression } = require("%ui/hud/menus/notes/player_progression.nut")

const PLAYER_PROFILE_ID = "playerProfileId"
let profileWindowName = loc("player/profileTitle")

let tabsList = const [
  { id = "player_progression" text = loc("profile/playerProgression") getContent = playerProgression },
  { id = "career" text = loc("statisticsMenu") content = careerTab, filters = {isOnboarding = false}},
]

let currentTab = mkWatched(persist, "currentTab", "player_progression")

let content = function(){
  let filters = {isOnPlayerBase= isOnPlayerBase.get(), isOnboarding=isOnboarding.get()}
  let tabs = tabsList.filter(function(tab){
    if ("filters" not in tab)
      return true
    foreach (name, v in tab.filters){
      if (name in filters && v!=filters[name])
        return false
    }
    return true
  })

  let getValidTab = @(tabId) tabs.findvalue(@(v) v.id == tabId && (v?.isAvailable.get() ?? true))
  let getCurTabContent = function(tabId) {
    let tab = getValidTab(tabId)
    return tab?.getContent?() ?? tab?.content
  }
  let cTabId = getValidTab(currentTab.get())?.id ?? tabs?[0].id
  let tabsUi = mkTabs({
    tabs
    currentTab = cTabId
    onChange = @(tab) currentTab.set(tab.id)
  })
  let tabContent = getCurTabContent(currentTab.get())
  return {
    watch = [currentTab, isOnPlayerBase, isOnboarding]
    size = flex()
    flow = FLOW_VERTICAL
    onAttach = function() {
      if (getValidTab(currentTab.get())==null)
        currentTab.set(tabs?[0].id)
    }
    gap = hdpx(10)
    children = [
      tabsUi,
      tabContent ?? getCurTabContent("player_progression")
    ]
  }
}
let profileMenuUi = wrapInStdPanel(PLAYER_PROFILE_ID, mkConsoleScreen(content), profileWindowName)

return {
  PLAYER_PROFILE_ID
  profileMenuUi
}
