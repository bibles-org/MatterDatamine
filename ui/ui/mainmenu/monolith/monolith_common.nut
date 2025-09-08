from "%ui/ui_library.nut" import *
let { currencyMap } = require("%ui/mainMenu/currencyIcons.nut")
let { marketItems, playerBaseState } = require("%ui/profile/profileState.nut")

let MT = currencyMap["MT"]
const MonolithMenuId = "monolithAccessWnd"
let monolithSelectedLevel = Watched(0)
let selectedMonolithUnlock = Watched("")
let monolithSectionToReturn = Watched(null)

let monolithLevelOffers = Computed(function() {
  let monolithLelvels = marketItems.get().filter(@(v) v?.children.baseUpgrades.contains("MonolithAccessLevel"))
  return monolithLelvels.map(@(v, k) v.__merge( {offerId = k} )).values().sort(@(a, b) a?.requirements.monolithAccessLevel <=> b?.requirements.monolithAccessLevel)
})

let currentMonolithLevel = Computed(@() playerBaseState.get()?.monolithAccessLevel ?? 0)

return {
  MT
  MonolithMenuId
  monolithSelectedLevel
  monolithLevelOffers
  selectedMonolithUnlock
  currentMonolithLevel
  monolithSectionToReturn
}