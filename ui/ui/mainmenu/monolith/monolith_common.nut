from "%ui/ui_library.nut" import *
let { marketItems, playerBaseState } = require("%ui/profile/profileState.nut")

const MonolithMenuId = "monolithAccessWnd"
let currentTab = Watched("monolithLevelId")
let monolithSelectedLevel = Watched(1)
let selectedMonolithUnlock = Watched("")
let monolithSectionToReturn = Watched(null)

let monolithLevelOffers = Computed(function() {
  let monolithLelvels = marketItems.get().filter(@(v) v?.children.baseUpgrades.contains("MonolithAccessLevel"))
  return monolithLelvels.map(@(v, k) v.__merge( {offerId = k} )).values().sort(@(a, b) a?.requirements.monolithAccessLevel <=> b?.requirements.monolithAccessLevel)
})

let permanentMonolithLevelOffers = Computed(function() {
  let permanentLevelId = marketItems.get().findindex(@(v) v?.isPermanent)
  if (permanentLevelId == null)
    return []
  return [marketItems.get()[permanentLevelId].__merge({ offerId = permanentLevelId })]
})

let currentMonolithLevel = Computed(@() playerBaseState.get()?.monolithAccessLevel ?? 0)

return {
  MonolithMenuId
  monolithSelectedLevel
  monolithLevelOffers
  permanentMonolithLevelOffers
  selectedMonolithUnlock
  currentMonolithLevel
  monolithSectionToReturn
  currentTab
}