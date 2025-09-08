from "%ui/ui_library.nut" import *

from "%ui/hud/menus/notes/notes.nut" import mkNoteTab, unreadCount
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
import "%ui/hud/menus/notes/battle_results.nut" as mkBattleResultsTab

let { mkConsoleScreen, mkTabs } = require("%ui/components/commonComponents.nut")
let { mkNotificationMark } = require("%ui/mainMenu/notificationMark.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

const JournalMenuId = "journalMenu"
let journalWindowName = loc("journalMenu/title")

function notesTabConstr(params) {
  return @(){
    flow = FLOW_HORIZONTAL
    watch = unreadCount
    margin = const [fsh(1), fsh(2)]
    children = [
      {
        rendObj = ROBJ_TEXT
        text = loc("notesMenu")
      }.__update(body_txt).__update(params)
      mkNotificationMark(unreadCount)
    ]
  }
}


let tabsList = const [
  { id="notes" childrenConstr=notesTabConstr getContent=mkNoteTab },
  { id="battle_results" text=loc("battleResultsMenu") getContent = mkBattleResultsTab, filters={isOnPlayerBase = true}},
]

let currentTab = mkWatched(persist, "currentTab", "notes")


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
