from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h1_txt, body_txt } = require("%ui/fonts_style.nut")
let { mkReceivedPanel, mkInitialItemPanel } = require("%ui/mainMenu/rewardPanel.nut")
let { playerProfileAllResearchNodes } = require("%ui/profile/profileState.nut")
let { getRecipeIcon, researchOpenedMarker, mkResearchTooltip, getNodeName
} = require("%ui/mainMenu/craftIcons.nut")
let { showNoEnoughStashSpaceMsgbox } = require("%ui/mainMenu/stashSpaceMsgbox.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { mkText, mkTextArea } = require("%ui/components/commonComponents.nut")
let { showMessageWithContent } = require("%ui/components/msgbox.nut")
let { InfoTextValueColor } = require("%ui/components/colors.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkHorizPaginatorList } = require("%ui/components/mkDotPaginatorList.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { currencyPile, monolithTokensPile, chronotracesPile } = require("%ui/mainMenu/currencyIcons.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")

let iconSize = hdpx(200)
let smallIconSize = hdpx(75)
let curPage = Watched(0)
const MAX_INITIAL_ITEMS = 8
const MAX_RECEIVED_ITEMS = 6

let paginatorListStyle = {
  flow = FLOW_HORIZONTAL
  halign = ALIGN_CENTER
  gap = hdpx(20)
}

function getResearch(researchBlock) {
  if (!researchBlock)
    return []

  let researchCards = []
  foreach(research in researchBlock) {
    let node = playerProfileAllResearchNodes.get()[research.prototypeId]
    let icon = {
      size = [ iconSize, iconSize ]
      children = [
        getRecipeIcon(node.containsRecipe, [iconSize, iconSize], 0)
        research?.newResearch ? researchOpenedMarker.__merge({ margin = hdpx(9), borderWidth = hdpx(5) }) : null
      ]
    }
    let pointsCount = research.researchPointsDiff
    let tooltip = mkResearchTooltip(research.prototypeId, loc(getNodeName(node)))
    researchCards.append(mkReceivedPanel(icon, loc(getNodeName(node)), research?.newResearch ? loc("researchBlueprintUnlocked") : loc("researchPoint"), pointsCount, tooltip))
  }

  return researchCards
}

function getItems(result, isReceived = true) {
  if (!result)
    return []
  let rawList = result?.itemsAdd ?? []
  let itemIcons = []
  let uniqueItems = {}
  let sorted = rawList.sort(@(a, b) a?.parentItemId <=> b?.parentItemId)
  foreach (item in sorted) {
    let { templateName = null, itemId = null, parentItemId = "0" } = item
    if (templateName == null || itemId == null)
      continue
    if (parentItemId != "0" && parentItemId in uniqueItems) {
      uniqueItems[parentItemId].__update({
        attachments = (uniqueItems[parentItemId]?.attachments ?? []).append(templateName) }) 
    }
    else
    uniqueItems[itemId] <- { templateName }
  }

  foreach(item in result?.itemsUpdate ?? []) {
    uniqueItems[item.itemId] <- {
      count = item.countAdded
      templateName = item.templateName
    }
  }
  let ctor = isReceived ? mkReceivedPanel : mkInitialItemPanel
  let itemsList = uniqueItems.values().map(@(v) mkFakeItem(v.templateName, { count = v?.count ?? 1 }, v?.attachments ?? []))
  let listToShow = mergeNonUniqueItems(itemsList)
  foreach(item in listToShow) {
    let icon = itemIconNoBorder(item.templateName, {
      width = isReceived ? iconSize : smallIconSize,
      height = isReceived ? iconSize : smallIconSize,
      shading = "full"
    }, item?.iconAttachments ?? [])
    let itemLoc = loc(item?.itemName ?? "unknown")
    let tooltip = buildInventoryItemTooltip(item)
    itemIcons.append(ctor(icon, itemLoc, loc("item"), item.count, tooltip))
  }

  return itemIcons
}

function getNewFuseBox(fuseBoxes) {
  if (fuseBoxes == null)
    return []
  let itemIcons = []
  foreach (box in fuseBoxes) {
    let icon = itemIconNoBorder(box.templateName, {
      width = iconSize
      height = iconSize
      shading = "full"
    })
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(box.templateName)
    let itemLoc = loc(template.getCompValNullable("item__name"))

    itemIcons.append(
      mkReceivedPanel(icon, itemLoc, loc("fuse_result/new_lootbox_opened"), null, loc("fuse_result/new_lootbox_opened/tooltip"))
    )
  }
  return itemIcons
}

let getReceivedItems = @(items) getItems(items)
let getInitialItems = @(items) getItems(items, false)

function getCurrency(currencyBlock) {
  local result = []
  if (currencyBlock.monolithTokens != null) {
    let currencyIcon = monolithTokensPile(iconSize, iconSize, {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    })
    result.append(
      mkReceivedPanel(currencyIcon, loc("monolithTokens"), loc("balance"), currencyBlock.monolithTokens, loc("monolithTokens/desc")))
  }
  if (currencyBlock.credits != null) {
    let currencyIcon = currencyPile(iconSize, iconSize, {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    })
    result.append(
      mkReceivedPanel(currencyIcon, loc("credits"), loc("balance"), currencyBlock.credits, loc("currency/desc")))
  }
  if (currencyBlock.chronotraces != null) {
    let currencyIcon = chronotracesPile(iconSize, iconSize, {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    })
    result.append(
      mkReceivedPanel(currencyIcon, loc("chronotraces"), loc("balance"), currencyBlock.chronotraces, loc("chronotraces/desc")))
  }
  return result
}

function getBaseUpgrade(baseUpgradeBlock) {
  if (!baseUpgradeBlock)
    return []

  let itemIcons = []
  foreach(baseUpdate in baseUpgradeBlock) {
    let icon = itemIconNoBorder($"base_upgrade_{baseUpdate.name}", {
      width = iconSize,
      height = iconSize
    })
    let baseUpdateLoc = loc($"playerBaseUpgrade/{baseUpdate.name}")
    let tooltip = loc($"playerBaseUpgrade/{baseUpdate.name}/desc")
    itemIcons.append(mkReceivedPanel(icon, baseUpdateLoc, loc("baseUpgrade"), baseUpdate.count, tooltip))
  }
  return itemIcons
}

function getUnlocks(unlocksBlock) {
  if (!unlocksBlock)
    return []

  let unlockIcons = []
  foreach (v in unlocksBlock) {
    let unl = {
      size = [ iconSize, iconSize ]
      fillColor = Color(100, 100, 100)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = faComp("star", {
        size = [ iconSize, iconSize ]
        fontSize = iconSize / 2
        color = InfoTextValueColor
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
      })
    }
    let tooltip = loc($"stats/{v}/desc")
    let panel = mkReceivedPanel(unl, loc($"stats/{v}"), loc("stats/unlocks"), 0, tooltip)
    unlockIcons.append(panel)
  }
  return unlockIcons
}

let mkAndMoreBlock = @(count) {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    mkText($"+{count}", {
      vplace = ALIGN_TOP
      margin = [hdpx(15), 0,0,0]
    }.__update(h1_txt))
    mkText(loc("amClean/andMore"), body_txt)
  ]
}

let mkHeader = @(header) {
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  padding = hdpx(10)
  color = Color(10,10,10,60)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = header
}

function mkInitialItemsBlock(initialItems) {
  let itemsToShow = initialItems.len() <= MAX_INITIAL_ITEMS ? initialItems
    : initialItems.slice(0, MAX_INITIAL_ITEMS).append(mkAndMoreBlock(initialItems.len() - MAX_INITIAL_ITEMS))
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    hplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      mkHeader(mkText(loc("amClean/initialIinput"), h1_txt))
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        valign = ALIGN_BOTTOM
        children = itemsToShow
      }
    ]
  }
}

function showMsgBoxResult(headerName, result, initialIinput = null, cb = @() null) {
  if (result?.need_more_space) {
    showNoEnoughStashSpaceMsgbox(result?.need_more_space)
    cb()
    return
  }

  let header = mkTextArea(loc(headerName), {
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    color = InfoTextValueColor
  }.__update(h1_txt))

  let itemIcons = [].extend(
    getCurrency({ credits = result?.currency, monolithTokens = result?.monolithTokens, chronotraces = result?.chronotraces })
    getBaseUpgrade(result?.baseUpdates)
    getUnlocks(result?.unlocks)
    getResearch(result?.researches)
    getReceivedItems(result)
    getNewFuseBox(result?.newFuseBox)
  )

  if (itemIcons.len() == 0)
    return

  let initialItems = getInitialItems(initialIinput)

  let content = {
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    size = [sw(100), SIZE_TO_CONTENT]
    onDetach = function() {
      curPage.set(0)
      sound_play("ui_sounds/button_ok_reward")
    }
    halign = ALIGN_CENTER
    margin = [0, 0, hdpx(40), 0]
    children = [
      initialItems.len() > 0 ? mkInitialItemsBlock(initialItems) : null
      mkHeader(header)
      mkHorizPaginatorList(itemIcons, MAX_RECEIVED_ITEMS, curPage, paginatorListStyle)
    ]
  }

  showMessageWithContent({
    content
    buttons = [
      {
        text = loc("rewards/collect")
        isCancel = true
        action = cb
        sound = {
          click  = "ui_sounds/button_ok"
          hover  = "ui_sounds/button_highlight"
        }
        customStyle = accentButtonStyle
      }
    ]
  })
}

return {
  showMsgBoxResult
}