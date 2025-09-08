from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { toIntegerSafe } = require("%sqstd/string.nut")
let { allCraftRecipes, marketItems } = require("%ui/profile/profileState.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let { mkAttachedChar } = require("%ui/hud/state/item_info.nut")
let { BtnBgActive, InfoTextValueColor, InfoTextDescColor } = require("%ui/components/colors.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { chocolateInventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { doesLocTextExist } = require("dagor.localize")
let colorize = require("%ui/components/colorize.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { mkRarityIconByItem } = require("%ui/hud/menus/components/inventoryItemRarity.nut")

let itemIconPadding = 0.8

function blueprintBackgroundSelector(size, is_active){
  if (size[0] > hdpx(80) && is_active)
    return Picture("!ui/blueprint.avif")
  else if (size[0] > hdpx(80) && !is_active)
    return Picture("!ui/blueprint_disabled.avif")
  else if (size[0] <= hdpx(80) && is_active)
    return Picture("!ui/skin#blueprint_small.avif")
  else
    return Picture("!ui/skin#blueprint_small_disabled.avif")
}

let blueprintBackground = @(size, progress) {
  rendObj = ROBJ_IMAGE
  image = blueprintBackgroundSelector(size, progress >= 1.0)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  keepAspect = true
  size = size
  children = (progress < 1.0) ? {
    size = size
    rendObj = ROBJ_PROGRESS_CIRCULAR
    fValue = progress
    image = blueprintBackgroundSelector(size, true)
  } : null
}

let overridedIcons = {
  [20000] = "ui/skin#lootbox_icons/lootbox_weapon.svg",
  [40000] = "ui/skin#lootbox_icons/lootbox_gear.svg",
  [50000] = "ui/skin#lootbox_icons/lootbox_medicine.svg",
  [-1] = "ui/skin#question.svg"
}

function findAttachmentsInList(marketLotId) {
  local iconAttachments = []
  let items = marketLotId == 0 ? [] : marketItems.get()?[marketLotId.tostring()]?.children.items ?? []
  foreach (item in items) {
    if (item?.insertIntoIdx == 0) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
      let animchar = template.getCompValNullable("item__animcharInInventoryName") ?? template.getCompValNullable("animchar__res")
      iconAttachments.append(mkAttachedChar(item.insertIntoSlot, animchar))
    }
  }
  return iconAttachments
}

function getRecipeIcon(recipe_id, size, progress = 1.0, shading="silhouette") {
  if (recipe_id in overridedIcons) {
    return {
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children =[
        blueprintBackground(size, progress)
        {
          rendObj = ROBJ_IMAGE
          image = Picture($"{overridedIcons[recipe_id]}:{size[0]}:{size[1]}:K")
          hplace = ALIGN_CENTER
          keepAspect = KEEP_ASPECT_FILL
          vplace = ALIGN_CENTER
          size = [(size[0] * itemIconPadding).tointeger(), (size[1] * itemIconPadding).tointeger()]
        }
      ]
    }
  }

  let recipe = allCraftRecipes.get()[recipe_id]
  let results = recipe.results.keys()
  let marketLotId = toIntegerSafe(results[0], 0, false)
  return {
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      blueprintBackground(size, progress)
      itemIconNoBorder(
        marketLotId == 0 ? results[0] : marketItems.get()?[marketLotId.tostring()]?.children.items[0]?.templateName ?? "",
        {
          width=(size[0] * itemIconPadding).tointeger(),
          height=(size[1] * itemIconPadding).tointeger(),
          shading
          keepAspect = true
          silhouetteHasShadow = true
          silhouetteMinShadow = 0.15
        }, findAttachmentsInList(marketLotId)
      )
    ]
  }
}

let researchOpenedMarker = {
  size = flex()
  margin = hdpx(2)
  rendObj = ROBJ_BOX
  borderColor = Color(11, 111, 170)
  borderWidth = hdpx(2)
}

let researchSelectedMarker = {
  rendObj = ROBJ_BOX
  size = flex()
  margin = hdpx(2)
  borderColor = BtnBgActive
  borderWidth = hdpx(2)
}

function getCraftResultItems(result) {
  return result.keys().map(function(k) {
    let marketLotId = toIntegerSafe(k, 0, false)
    let marketLot = marketItems.get()?[k].children.items
    let itemTemplateName = marketLotId == 0 ? k : marketLot?[0].templateName ?? ""
    let attachments = marketLot?.slice(1).map(@(v) v.templateName) ?? []
    let item = mkFakeItem(itemTemplateName, {}, attachments)
    return item.__update(item?.charges == 0 ? { charges = null } : {})
  }).sort(inventoryItemSorting)
}

let mkCraftResultIcon = @(item) {
  behavior = Behaviors.Button
  onHover = @(on)  setTooltip(on ? buildInventoryItemTooltip(item) : null)
  children = [
    chocolateInventoryItem(item)
    mkRarityIconByItem(item)
  ]
}

function mkCraftResultsItems(items, columnsCount = 4) {
  let children = []
  local row = []
  for(local i=0; i < items.len(); i++){
    if (i != 0 && (i % columnsCount == 0)) {
      children.append({
        flow = FLOW_HORIZONTAL
        gap = hdpx(5)
        children = row
      })
      row = []
    }
    row.append(mkCraftResultIcon(items[i]))
  }
  children.append({
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = row
  })
  return {
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    hplace = ALIGN_CENTER
    children
  }
}

function getNodeName(node, useShortLocs = true) {
  if (node.name != "")
    return node.name

  let recipe = allCraftRecipes.get()?[node.containsRecipe]
  if (recipe == null)
    return "Unknown"

  let result = recipe.results.keys()[0]
  local templateName = result

  if (marketItems.get()?[result]) {
    let market = marketItems.get()[result]
    templateName = market.children.items[0].templateName
  }

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template.getCompValNullable("item__name")
  return useShortLocs && doesLocTextExist($"{itemName}/short") ? loc($"{itemName}/short") : itemName
}

function mkResearchTooltip(prototype_id, name, additionalData = []) {
  let recipe = allCraftRecipes.get()?[prototype_id]
  if (recipe == null)
    return ""
  let recipeName = [$"{colorize(InfoTextDescColor, loc("research/craftRecipe"))} {colorize(InfoTextValueColor, name)}"]
  let craftTime = [$"{colorize(InfoTextDescColor, loc("research/craftTime"))} {colorize(InfoTextDescColor, secondsToStringLoc(recipe.craftTime))}"]
  let refinerTooltip = [loc("research/craftUse")]
  return "\n\n".join([
    "\n".join(recipeName),
    "\n".join(craftTime),
    "\n".join(refinerTooltip)
  ].extend(additionalData), @(v) v.len() > 0)
}

return {
  getRecipeIcon
  researchOpenedMarker
  researchSelectedMarker
  getCraftResultItems
  mkCraftResultsItems
  getNodeName
  mkResearchTooltip
}