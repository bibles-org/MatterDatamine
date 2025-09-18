from "%dngscripts/sound_system.nut" import sound_play

from "%ui/mainMenu/craftIcons.nut" import getRecipeIcon, mkResearchTooltip, getNodeName

from "%ui/fonts_style.nut" import h1_txt, body_txt
from "%ui/mainMenu/rewardPanel.nut" import mkReceivedPanel, mkInitialItemPanel
from "%ui/mainMenu/stashSpaceMsgbox.nut" import showNoEnoughStashSpaceMsgbox
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "%ui/components/msgbox.nut" import showMessageWithContent
from "%ui/components/colors.nut" import InfoTextValueColor
import "%ui/components/faComp.nut" as faComp
from "%ui/components/mkDotPaginatorList.nut" import mkHorizPaginatorList
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/mainMenu/currencyIcons.nut" import currencyPile, monolithTokensPile, chronotracesPile, premiumCreditsPile
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkAlterIconParams
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneImage

let { playerProfileAllResearchNodes } = require("%ui/profile/profileState.nut")
let { researchOpenedMarker } = require("%ui/mainMenu/craftIcons.nut")

#allow-auto-freeze

let iconSize = hdpx(200)
let smallIconSize = hdpx(75)
let curPage = Watched(0)

let mkSuitIconParams = @(width) {
  width
  height = width / 2 * 3
  slotSize = [width, width]
}

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
  #forbid-auto-freeze
  let researchCards = []
  foreach(research in researchBlock) {
    let node = playerProfileAllResearchNodes.get()[research.prototypeId]
    let icon = {
      size = iconSize
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

  #forbid-auto-freeze
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
  let itemsList = uniqueItems.values().map(function(v) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(v.templateName)
    let isAlter = template?.getCompValNullable("item__filterType") == "alters"
    #forbid-auto-freeze
    let attachmentsToUse = (v?.attachments ?? {})
    let altersOverride = {}
    if (isAlter) {
      let { attachments, alterIconParams } = mkAlterIconParams(v.templateName, template)
      attachmentsToUse.__update(attachments)
      altersOverride.__update(alterIconParams.__merge({ iconScale = (alterIconParams?.iconScale ?? 1) * 0.7 } ))
    }
    return mkFakeItem(v.templateName, { count = v?.count ?? 1 }.__merge(altersOverride), attachmentsToUse)
  })
  let listToShow = mergeNonUniqueItems(itemsList)
  foreach(item in listToShow) {
    local icon = null
    if (item?.filterType == "alters")
      icon = inventoryItemImage(item, mkSuitIconParams(isReceived ? iconSize : smallIconSize), { clipChildren = true })
    else if(item?.filterType == "chronogene") {
      let sz = isReceived ? iconSize : smallIconSize
      icon = mkChronogeneImage(item, {
        width = sz,
        height = sz,
        shading = "full"
        slotSize = [sz, sz]
      })
    }
    else
      icon = itemIconNoBorder(item.templateName, {
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

  #forbid-auto-freeze
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
  #forbid-auto-freeze
  local result = []
  if (currencyBlock.premiumCredits != null) {
    let premiumCreditsIcon = premiumCreditsPile(iconSize, iconSize, {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    })
    result.append(
      mkReceivedPanel(premiumCreditsIcon, loc("premiumCredits"), loc("balance"), currencyBlock.premiumCredits, loc("premiumCredits/desc")))
  }
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
  #forbid-auto-freeze
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
  #forbid-auto-freeze
  let unlockIcons = []
  foreach (v in unlocksBlock) {
    let unl = {
      size = iconSize
      fillColor = Color(100, 100, 100)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = faComp("star", {
        size = iconSize
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
  size = FLEX_V
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    mkText($"+{count}", {
      vplace = ALIGN_TOP
      margin = static [hdpx(15), 0,0,0]
    }.__update(h1_txt))
    mkText(loc("amClean/andMore"), body_txt)
  ]
}

let mkHeader = @(header) {
  rendObj = ROBJ_SOLID
  size = FLEX_H
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
    size = FLEX_H
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
    getCurrency({
      credits = result?.currency,
      premiumCredits = result?.premiumCurrency,
      monolithTokens = result?.monolithTokens,
      chronotraces = result?.chronotraces
    })
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
    size = static [sw(100), SIZE_TO_CONTENT]
    onDetach = function() {
      curPage.set(0)
      sound_play("ui_sounds/button_ok_reward")
    }
    halign = ALIGN_CENTER
    margin = static [0, 0, hdpx(40), 0]
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