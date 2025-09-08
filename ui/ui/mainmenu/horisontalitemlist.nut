from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { body_txt } = require("%ui/fonts_style.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { playerProfileAllResearchNodes, playerProfileOpenedNodes, playerProfileOpenedRecipes
} = require("%ui/profile/profileState.nut")
let { DEBRIEFING_ITEM } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { mkHorizPaginatorList } = require("%ui/components/mkDotPaginatorList.nut")
let { inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { getRecipeIcon, mkResearchTooltip, getNodeName } = require("%ui/mainMenu/craftIcons.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")

const MAX_RECEIVED_ITEMS = 6
let cuItemsPage = Watched(0)
let cuCronotracePage = Watched(0)

let paginatorListStyle = {
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
}

let mkChronotraceProgress = @(data) (data?.v ?? {}).len() <= 0 ? null : {
  rendObj = ROBJ_BOX
  fillColor = Color(67, 67, 67)
  borderRadius = [0, 0, hdpx(5), 0]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = const hdpx(3)
  gap = const hdpx(2)
  behavior = Behaviors.Button
  onHover = function(on) {
    let tooltip = data.v.reduce(@(res, count, id) res.append({
      size = const [hdpx(200), SIZE_TO_CONTENT]
      children = mkText(loc($"chronotraceIncome/{id}", { count }))
    }), [])
    setTooltip(on ? tooltipBox({
      flow = FLOW_VERTICAL
      children = [mkText(loc("chronotrace/source"), body_txt)]
        .extend(tooltip)
    }) : null)
  }
  children = [
    mkText(loc("ui/multiply"))
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
  let isOpenedRecipe = playerProfileOpenedRecipes.get().findvalue(@(v) v.prototypeId == node.containsRecipe) != null
  let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == id)
  let needResearchPoints = node?.requireResearchPointsToComplete ?? -1
  let currentResearchPoints = playerResearch?.currentResearchPoints ?? 0

  let icon = {
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on && tooltip != null && tooltip != "" ? tooltip : null)
    children = [
      getRecipeIcon(node.containsRecipe, const [hdpxi(76), hdpxi(76)],
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
      isFoundInRaid = true, isCorrupted = false } = item
    if (!isFoundInRaid)
      return res
    let dataToSend = { charges, eid, isDragAndDropAvailable, isFoundInRaid, isCorrupted }
      .__update(charges > 0 ? { charges } : { charges = null })
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