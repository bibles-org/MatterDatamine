from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkConsoleScreen, mkHelpConsoleScreen } = require("%ui/components/commonComponents.nut")
let { playerProfileOpenedRecipes, craftTasks, allCraftRecipes, playerBaseState,
      playerProfileAllResearchNodes, playerProfileOpenedNodes } = require("%ui/profile/profileState.nut")
let { wrapInStdPanel, mkHeader, mkWndTitleComp, mkHelpButton, mkCloseBtn, wrapButtons, mkBackBtn
} = require("stdPanel.nut")
let { craftsReady, mkCraftSelection, scrollToRecipe } = require("%ui/mainMenu/craftSelection.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { MonolithMenuId } = require("%ui/mainMenu/monolith/monolith_common.nut")

addTabToDevInfo("[CRAFT] playerProfileOpenedRecipes", playerProfileOpenedRecipes)
addTabToDevInfo("[CRAFT] allCraftRecipes", allCraftRecipes)
addTabToDevInfo("[CRAFT] craftTasks", craftTasks)
addTabToDevInfo("[RESEARCH] playerProfileAllResearchNodes", playerProfileAllResearchNodes)
addTabToDevInfo("[RESEARCH] playerProfileOpenedNodes", playerProfileOpenedNodes)

let help_data = {
  content = "research/helpContent"
  components = [
    "research/helpComponent1",
    "research/helpComponent2"
  ]
  footnotes = [
    "research/helpFootnote1",
    "research/helpFootnote2",
    "research/helpFootnote3",
    "research/helpFootnote4",
    "research/helpFootnote5",
    "research/helpFootnote6",
    "research/helpFootnote7",
    "research/helpFootnote8",
    "research/helpFootnote9",
    "research/helpFootnote10",
    "research/helpFootnote11",
    "research/helpFootnote12",
    "research/helpFootnote13",
    "research/helpFootnote14",
    "research/helpFootnote15",
    "research/helpFootnote16",
    "research/helpFootnote17",
    "research/helpFootnote18",
  ]
}

const CRAFT_WND_ID = "craftWindow"
let craftWndName = loc("researchAndCraft/title")

function mkCraftWnd() {
  let availableSlots = Computed(@() playerBaseState.get()?.openedReplicatorDevices ?? 0)

  let helpConsole = {
    size = flex()
    children = mkHelpConsoleScreen(Picture("ui/build_icons/replicator_device.avif:{0}:{0}:P".subst(hdpx(600))), help_data)
  }

  let chronotracesOffset = { size = [ hdpx(40), 0 ] }
  let helpBtn = @() {
    watch = availableSlots
    children = availableSlots.get() > 0 ? mkHelpButton(helpConsole, craftWndName) : null
  }
  let closeBtn = @() {
    watch = scrollToRecipe
    children = scrollToRecipe.get() != null ? mkBackBtn(MonolithMenuId, @() scrollToRecipe.set(null))
      : mkCloseBtn(CRAFT_WND_ID)
  }
  let header = mkHeader(mkWndTitleComp(craftWndName), wrapButtons(chronotracesOffset, helpBtn, closeBtn))
  let content = @() {
    size = flex()
    watch = availableSlots
    children = wrapInStdPanel(CRAFT_WND_ID, availableSlots.get() <= 0 ? helpConsole : mkConsoleScreen(mkCraftSelection),
      craftWndName, helpConsole, header)
  }

  return {
    notifications = Computed(function() {
      local notificationsCount = craftsReady.get()
      local notificationsType = "reward"

      return {
        notificationsCount
        notificationsType
      }
    })
    getContent = @() content
    id = CRAFT_WND_ID
    name = loc("researchAndCraft")
  }
}

return {
  CRAFT_WND_ID
  mkCraftWnd
  craftIsAvailable = Computed(@() (playerBaseState.get()?.openedReplicatorDevices ?? 0) > 0)
}