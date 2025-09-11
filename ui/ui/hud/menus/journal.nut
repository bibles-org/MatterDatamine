from "%ui/components/commonComponents.nut" import mkConsoleScreen, mkTabs
from "%ui/mainMenu/notificationMark.nut" import mkNotificationMark
from "%ui/fonts_style.nut" import body_txt

from "%ui/ui_library.nut" import *

from "%ui/hud/menus/notes/notes.nut" import mkNoteTab, unreadCount
from "%ui/hud/menus/notes/story_contracts.nut" import mkStoryContractsTab
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/hud/menus/notes/player_progression.nut" import playerProgression
import "%ui/hud/menus/notes/career.nut" as careerTab
import "%ui/hud/menus/notes/battle_results.nut" as mkBattleResultsTab

let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

const JournalMenuId = "journalMenu"
let journalWindowName = loc("journalMenu/title")

function notesTabConstr(params) {
  return @(){
    flow = FLOW_HORIZONTAL
    watch = unreadCount
    margin = static [fsh(1), fsh(2)]
    children = [
      {
        rendObj = ROBJ_TEXT
        text = loc("notesMenu")
      }.__update(body_txt).__update(params)
      mkNotificationMark(unreadCount)
    ]
  }
}


let tabsList = static [
  { id = "player_progression" text = loc("profile/playerProgression") getContent = playerProgression, filters = { isOnPlayerBase = true }},
  { id = "career" text = loc("statisticsMenu") content = careerTab, filters = {isOnboarding = false, isOnPlayerBase = true} },
  { id = "notes" childrenConstr=notesTabConstr getContent=mkNoteTab },
  { id = "story_contracts" text=loc("journal/storyContracts") getContent = mkStoryContractsTab },
  { id = "battle_results" text=loc("battleResultsMenu") getContent = mkBattleResultsTab, filters={isOnPlayerBase = true}}
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
      tabContent ?? getCurTabContent("notes")
    ]
  }
}
let journalMenuUi = wrapInStdPanel(JournalMenuId, mkConsoleScreen(content), journalWindowName)
let journalNotifications = Computed(function() {
  local notificationsCount = unreadCount.get()
  local notificationsType = "reward"

  return {
    notificationsCount
    notificationsType
  }
})
return {
  JournalMenuId
  journalMenuUi
  journalCurrentTab = currentTab
  journalNotifications
}
