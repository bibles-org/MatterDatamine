from "%ui/fonts_style.nut" import body_txt
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/mkDotPaginatorList.nut" import mkHorizPaginatorList
from "%ui/hud/menus/components/inventoryItemsList.nut" import inventoryItemSorting
from "%ui/mainMenu/craftIcons.nut" import getRecipeIcon, mkResearchTooltip, getNodeName
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { playerProfileAllResearchNodes, playerProfileOpenedNodes, allCraftRecipes
} = require("%ui/profile/profileState.nut")
let { DEBRIEFING_ITEM } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

const MAX_RECEIVED_ITEMS = 6
let cuItemsPage = Watched(0)
let cuCronotracePage = Watched(0)

let paginatorListStyle = {
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
}

let mkChronotraceProgress = @(data) (data?.v ?? {}).len() <= 0 ? null : {
  rendObj = ROBJ_BOX
  fillColor = Color(67, 67, 67, 100)
  borderRadius = static [0, 0, hdpx(5), 0]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = hdpx(3)
  gap = hdpx(2)
  behavior = Behaviors.Button
  onHover = function(on) {
    let tooltip = data.v.reduce(@(res, count, id) res.append({
      size = static [hdpx(200), SIZE_TO_CONTENT]
      children = mkText(loc($"chronotraceIncome/{id}", { count }))
    }), [])
    setTooltip(on ? tooltipBox({
      flow = FLOW_VERTICAL
      children = [mkText(loc("chronotrace/source"), body_txt)]
        .extend(tooltip)
    }) : null)
  }
  children = [
    static mkText("+")
    mkText(data.v.reduce(@(res, v) res + v, 0))
  ]
}

function mkResearchToShow(id, chronotraceProgress, curChronoProgress = null) {
  let node = playerProfileAllResearchNodes.get()?[id]
  if (node == null)
    return null
  let progress = curChronoProgress ?? chronotraceProgress.findvalue(@(trace) trace?.k == id)

  let additionalData = []
  if (progress?.v != null)
    progress.v.each(@(value, incomeId) additionalData.append(loc($"chronotraceIncome/{incomeId}", { count = value })))
  let tooltip = mkResearchTooltip(id, loc(getNodeName(node, false)), additionalData)
  let isOpenedRecipe = allCraftRecipes.get()?[node.containsRecipe].isOpened ?? false
  let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == id)
  let needResearchPoints = node?.requireResearchPointsToComplete ?? -1
  if (needResearchPoints == 0)
    return null
  let currentResearchPoints = playerResearch?.currentResearchPoints ?? 0
  let icon = {
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on && tooltip != null && tooltip != "" ? tooltip : null)
    children = [
      getRecipeIcon(node.containsRecipe, static [hdpxi(76), hdpxi(76)],
        needResearchPoints < 0 ? 0 : currentResearchPoints.tofloat() / needResearchPoints,
        isOpenedRecipe ? "full" : "silhouette")
        progress == null ? null : mkChronotraceProgress(progress)
    ]
  }
  return icon
}

function mkDebriefingItemsList(profileItems, maxCountPerPage = MAX_RECEIVED_ITEMS) {
  let width = hdpx(76) * maxCountPerPage + maxCountPerPage * hdpx(4) - hdpx(4)
  let fakeItems = profileItems.reduce(function(res, item) {
    let { templateName, charges, eid = ecs.INVALID_ENTITY_ID, isDragAndDropAvailable = false,
      isFoundInRaid = true, isCorrupted = false, killerNickname = null, ownerNickname = null, deathReason = null, killedByWeapon = null } = item
    if (!isFoundInRaid)
      return res
    let dataToSend = {
      charges
      eid
      isDragAndDropAvailable
      isFoundInRaid
      isCorrupted
      cortical_vault_inactive__killerNickname = killerNickname
      cortical_vault_inactive__killedByWeapon = killedByWeapon
      cortical_vault_inactive__deathReason = deathReason
      cortical_vault_inactive__ownerNickname = ownerNickname
    }.__update(charges > 0 ? { charges } : { charges = null })

    let itemRes = mkFakeItem(templateName, dataToSend)
    let { filterType = "" } = itemRes
    if (filterType == "chronogene" || filterType == "alters")
      return res
    return res.append(itemRes)
  }, [])
  let items = mergeNonUniqueItems(fakeItems)
    .sort(inventoryItemSorting)
    .map(@(item) inventoryItem(item, DEBRIEFING_ITEM))
  return {
    size = [width, SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    onDetach = @() cuItemsPage.set(0)
    children = mkHorizPaginatorList(items, maxCountPerPage, cuItemsPage, paginatorListStyle)
  }
}

function mkDebriefingCronotracesList(researchNodesIds, chronotraceProgress, maxCountPerPage = MAX_RECEIVED_ITEMS) {
  let width = hdpx(76) * maxCountPerPage + maxCountPerPage * hdpx(4) - hdpx(4)
  let researchNodesToShow = researchNodesIds.map(@(v) mkResearchToShow(v, chronotraceProgress))
  let chronoProgress = chronotraceProgress.filter(@(data) !researchNodesIds.contains(data.k))
    .map(@(data) mkResearchToShow(data.k, chronotraceProgress, data))
  let items = researchNodesToShow
    .filter(@(v) v != null)
    .extend(chronoProgress)
  return {
    size = [width, SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    onDetach = @() cuCronotracePage.set(0)
    children = mkHorizPaginatorList(items, maxCountPerPage, cuCronotracePage, paginatorListStyle)
  }
}

return {
  mkDebriefingItemsList
  mkDebriefingCronotracesList
}