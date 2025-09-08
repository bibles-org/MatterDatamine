from "%ui/ui_library.nut" import *

let { monolithGateUi, MONOLITH_LEVEL_ID, isRequirementsMet, getPriceInItems } = require("monolith_gate.nut")
let { monolithLbUi, MONOLITH_LB_ID } = require("%ui/mainMenu/monolith/monolith_lb.nut")
let { wrapInStdPanel, mkBackBtn, mkCloseBtn, mkWndTitleComp, mkHeader } = require("%ui/mainMenu/stdPanel.nut")
let { mkConsoleScreen, mkTabs } = require("%ui/components/commonComponents.nut")
let { isOnboarding, onboardingContractReported, onboardingMonolithFirstLevelUnlocked } = require("%ui/hud/state/onboarding_state.nut")
let { MonolithMenuId, monolithLevelOffers, currentMonolithLevel, monolithSectionToReturn
} = require("%ui/mainMenu/monolith/monolith_common.nut")
let { refreshMonolithLb } = require("%ui/leaderboard/lb_state_base.nut")
let { playerProfileMonolithTokensCount } = require("%ui/profile/profileState.nut")
let { stashItems, backpackItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")

let monolithAccessTitle = loc("monolith/title")
let monolithName = loc("monolith/name", "Monolith")

let currentTab = Watched(MONOLITH_LEVEL_ID)

let tabsList = [
  { id = MONOLITH_LEVEL_ID, text = loc("monolith/gateTab"), content = monolithGateUi }
  { id = MONOLITH_LB_ID, text = loc("monolith/lbTab"), content = monolithLbUi }
]

let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

function content() {
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
    onAttach = refreshMonolithLb
    children = [
      tabsUi,
      tabContent ?? getCurTabContent(MONOLITH_LEVEL_ID)
    ]
  }
}

let isMonolithMenuAvailable = Computed(@() onboardingContractReported.get() || !isOnboarding.get())

function getMonolithNotifications(){
  let notif = {
    notificationsCount = 1
    notificationsType = "action"
  }
  if (isOnboarding.get() && !onboardingMonolithFirstLevelUnlocked.get()) {
    return notif
  }
  let currentAccessLevel = currentMonolithLevel.get()
  let currentOffer = monolithLevelOffers.get().findvalue(@(v) v.requirements.monolithAccessLevel == currentAccessLevel )
  if (currentOffer == null)
    return 0

  let requirementsMet = isRequirementsMet(currentOffer)
  if (!requirementsMet)
    return 0

  let price = currentOffer?.additionalPrice.monolithTokensCount ?? 0
  let itemPrice = getPriceInItems(currentOffer, [].extend(stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()) )
  let enoughItems = itemPrice.findvalue(@(v) v.has < v.need) == null
  let notEnoughMoney = playerProfileMonolithTokensCount.get() < price || !enoughItems
  if (notEnoughMoney)
    return 0

  return notif
}

let closeBtn = mkCloseBtn(MonolithMenuId)

let monolithButtons = @() {
  watch = monolithSectionToReturn
  children = monolithSectionToReturn.get() == null ? closeBtn : mkBackBtn(monolithSectionToReturn.get())
}

let header = mkHeader(mkWndTitleComp(monolithAccessTitle), monolithButtons)

function mkMonolithMenu(){
  let monolithAccessContent = wrapInStdPanel(MonolithMenuId, mkConsoleScreen(content),
    monolithAccessTitle, null, header)
  return {
    getContent = @() {
      children = monolithAccessContent
    }
    id = MonolithMenuId
    name = monolithName
    notifications = Computed(getMonolithNotifications)
  }
}

return {
  monolithName
  mkMonolithMenu
  isMonolithMenuAvailable
  getMonolithNotifications
}

