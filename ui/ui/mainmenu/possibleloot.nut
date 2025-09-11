from "%ui/helpers/parseSceneBlk.nut" import get_possible_loot
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem, mkFakeAttachments
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/components/commonComponents.nut" import mkTooltiped, mkText
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/components/colors.nut" import ItemBgColor
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByTemplateName
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs




let forbiddenItemComponents = [
  "key__tags",
  "lootableRendinst",
  "item__am"
]

let requiredItemComponents = [
  "item__name"
]

function filter_possible_loot(item) {
  let itemTemplateName = item.itemTemplate
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplateName)
  if (template == null) {
    error($"failed to create info for template \"{itemTemplateName}\"")
    return false
  }
  foreach (compName in forbiddenItemComponents) {
    if (template.hasComponent(compName)) {
      return false
    }
  }
  foreach(compName in requiredItemComponents) {
    if (!template.hasComponent(compName)) {
      return false
    }
  }
  return true
}

let itemTypeSortValue = {
  "other" : 0,
  "ammo" : 1,
  "artifact" : 2,
  "grenade" : 3,
  "equipment" : 4,
  "special" : 5,
  "weapon" : 6
}
let raritySortValue = {
  "common": 0,
  "uncommon": 1,
  "rare": 2,
  "epic": 3,
  "legendary": 4
}

function sort_possible_loot(first, second) {
  return (
    (raritySortValue?[second.itemRarity] ?? -1) <=> (raritySortValue?[first.itemRarity] ?? -1) ||
    (itemTypeSortValue?[second.itemType] ?? -1) <=> (itemTypeSortValue?[first.itemType] ?? -1) ||
    (first.itemTemplate <=> second.itemTemplate)
  )
}

function sort_shown_loot(first, second) {
  return (
    (itemTypeSortValue?[second.itemType] ?? -1) <=> (itemTypeSortValue?[first.itemType] ?? -1) ||
    (raritySortValue?[second.itemRarity] ?? -1) <=> (raritySortValue?[first.itemRarity] ?? -1) ||
    (second.itemTemplate <=> first.itemTemplate)
  )
}

let iconSize = hdpx(76)
let itemIconSize = [ iconSize, iconSize ]
let iconParams = { width=itemIconSize[0], height=itemIconSize[1], shading = "full" }

function makeFakeItemAttachments(templateName) {
  let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let magazineSlot = templ?.getCompValNullable("gun_mods__slots")?.magazine
  if (magazineSlot == null) {
    return []
  }
  let magazineSlotTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(magazineSlot)
  let magazine = magazineSlotTempl?.getCompValNullable("slot_holder__availableItems")?.getAll()?[0]

  if (magazine == null) {
    return []
  } else {
    return mkFakeAttachments([magazine])
  }
}

function possibleLootItemComp(fakeItem) {
  let itemTooltip = buildInventoryItemTooltip(fakeItem)
  let tooltipedIcon = mkTooltiped({
    rendObj = ROBJ_BOX
    fillColor = Color(30, 30, 30, 20)
    children = [
      itemIconNoBorder(fakeItem.itemTemplate, iconParams, makeFakeItemAttachments(fakeItem.itemTemplate))
      mkRarityIconByTemplateName(fakeItem.itemTemplate)
    ]
  }, itemTooltip)
  return {
    size = itemIconSize
    color = ItemBgColor
    valign = ALIGN_BOTTOM
    halign = ALIGN_CENTER
    children = tooltipedIcon
  }
}

function lineFromComps(comps) {
  return {
    flow = FLOW_HORIZONTAL
    gap = hdpx(3)
    valign = ALIGN_CENTER
    halign = ALIGN_LEFT
    size = FLEX_H
    children = comps
  }
}

function mkPossibleLootBlock(scene, description, params) {
  let {
    num_in_row,
    total_items
  } = params

  let parsedPossibleItems = get_possible_loot(scene).keys()
    .map(@(v) mkFakeItem(v))
    .filter(filter_possible_loot)
    .sort(sort_possible_loot)
  let itemsToShow = (description?.possibleLoot.map(@(v) mkFakeItem(v)) ?? parsedPossibleItems).slice(0, total_items).sort(sort_shown_loot)

  let notShownItemsNum = max((description?.overrideMoreLootNum ?? 0), parsedPossibleItems.len() - itemsToShow.len())
  
  
  let moreButton = notShownItemsNum <= 1 ? null : {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    rendObj = ROBJ_BOX
    
    size = itemIconSize
    children = [
      mkText(loc("possibleLoot/more"))
      mkText($"({notShownItemsNum})")
    ]
  }

  let possibleLootComps = itemsToShow.map(possibleLootItemComp).append(moreButton)

  let lines = []
  for (local i = 0; i < possibleLootComps.len(); i += num_in_row) {
    if (i >= total_items)
      break
    lines.append(lineFromComps(possibleLootComps.slice(i, min(i + num_in_row, possibleLootComps.len()))))
  }

  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    valign = ALIGN_CENTER
    gap = hdpx(4)
    children = [
      {
        size = FLEX_H
        halign = ALIGN_LEFT
        children = mkText(loc("possibleLoot/title"))
      }
    ].extend(lines)
  }
}

return {
  mkPossibleLootBlock
}
