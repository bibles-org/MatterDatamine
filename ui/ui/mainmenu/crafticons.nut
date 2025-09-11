from "%sqstd/string.nut" import toIntegerSafe

from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/hud/state/item_info.nut" import mkAttachedChar
from "%ui/components/colors.nut" import BtnBgActive, InfoTextValueColor, InfoTextDescColor
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/inventoryItemsList.nut" import inventoryItemSorting
from "%ui/hud/menus/components/inventoryItem.nut" import chocolateInventoryItem
from "%ui/helpers/time.nut" import secondsToStringLoc
from "dagor.localize" import doesLocTextExist
import "%ui/components/colorize.nut" as colorize
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByItem

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { allRecipes } = require("%ui/profile/profileState.nut")

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

let addAttachmentsInList = @(scheme) scheme == null ? null
  : scheme.reduce(function(result, slot, item_template) {
      if (slot.len() != 0) {
        let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item_template)
        let animchar = template.getCompValNullable("item__animcharInInventoryName") ?? template.getCompValNullable("animchar__res")
        result.append(mkAttachedChar(slot, animchar))
      }
      return result
    }, [])

function getRecipeIcon(recipe_id, size, progress = 1.0, shading="silhouette", bgSize = null) {
  if (recipe_id in overridedIcons) {
    return {
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children = [
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

  let recipe = allRecipes.get()[recipe_id]
  let fuseTemplateName = $"fuse_result_{recipe.name}"
  let isFuseRecipe = recipe.name != ""
  let templateName = isFuseRecipe ? fuseTemplateName : recipe.results?[0].reduce(@(a,v,k) v.len() == 0 ? k : a, "")
  return {
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      blueprintBackground(bgSize ?? size, progress)
      itemIconNoBorder(templateName,
        {
          width=(size[0] * itemIconPadding).tointeger(),
          height=(size[1] * itemIconPadding).tointeger(),
          shading
          keepAspect = true
          silhouetteHasShadow = true
          silhouetteMinShadow = 0.15
        }, addAttachmentsInList(recipe.results?[0])
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

function getCraftResultItems(results) {
  return results.map(function(result) {
    let itemTemplateName = result.reduce(@(a,v,k) v.len() == 0 ? k : a, "")
    let attachments = result.reduce(function(acc, slot_name, item_name) {
      if (slot_name.len() != 0)
        acc.append(item_name)
      return acc
    }, [])
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

  let recipe = allRecipes.get()?[node.containsRecipe]
  if (recipe == null)
    return "Unknown"

  let templateName = recipe.results?[0].reduce(@(a,v,k) v.len() == 0 ? k : a, "")
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template.getCompValNullable("item__name")
  return useShortLocs && doesLocTextExist($"{itemName}/short") ? loc($"{itemName}/short") : itemName
}

function mkResearchTooltip(prototype_id, name, additionalData = []) {
  let recipe = allRecipes.get()?[prototype_id]
  if (recipe == null)
    return ""
  let recipeName = [$"{colorize(InfoTextDescColor, loc("research/craftRecipe"))} {colorize(InfoTextValueColor, name)}"]
  let craftTime = [$"{colorize(InfoTextDescColor, loc("research/craftTime"))} {colorize(InfoTextDescColor, secondsToStringLoc(recipe.craftTime))}"]
  let refinerTooltip = [loc("research/craftUse")]
  let additionalText = "\n".join(additionalData,  @(v) v.len() > 0)
  return "\n\n".join([
    "\n".join(recipeName),
    "\n".join(craftTime),
    "\n".join(refinerTooltip),
    additionalText
  ], @(v) v.len() > 0)
}

return freeze({
  getRecipeIcon
  researchOpenedMarker
  researchSelectedMarker
  getCraftResultItems
  mkCraftResultsItems
  getNodeName
  mkResearchTooltip
})