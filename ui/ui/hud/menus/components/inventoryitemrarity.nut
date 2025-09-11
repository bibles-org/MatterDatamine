from "dagor.debug" import logerr
from "%ui/components/colors.nut" import RarityCommon, RarityUncommon, RarityRare, RarityEpic

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

#allow-auto-freeze

let rarityCornerSize = hdpx(20)
let mkRarityCorner = @(color, override = {}) color == null ? null : {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [ rarityCornerSize, rarityCornerSize ]
  commands = [
    [VECTOR_WIDTH, 0],
    [VECTOR_FILL_COLOR, mul_color(color, 127.0/255.0)],
    [VECTOR_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_POLY, 100,100, 100,0, 0,100],
  ]
}.__update(override)

let rarityColorTable = static {
  common = RarityCommon
  uncommon = RarityUncommon
  rare = RarityRare
  epic = RarityEpic
}

function getRarityColor(rarity, templateName=null) {
  let rarityColor = rarityColorTable?[rarity]
  if (rarityColor == null )
    logerr($"[Rarity] Template: <{templateName}> has unknown rarity <{rarity}>")
  return rarityColor
}

function mkRarityIconByColor(rarityColor) {
  if (rarityColor==null || rarityColor==RarityCommon)
    return null
  return {
    size = flex()
    halign = ALIGN_RIGHT
    valign = ALIGN_BOTTOM
    children = mkRarityCorner(rarityColor)
  }
}

function mkRarityIconByItem(item) {
  if (item?.itemRarity == null)
    return null
  return mkRarityIconByColor(getRarityColor(item.itemRarity, item))
}

function mkRarityIconByTemplateName(templateName) {
  let itemRarity = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)?.getCompValNullable("item__rarity")
  if (itemRarity == null)
    return null
  return mkRarityIconByColor(getRarityColor(itemRarity, templateName))
}

return {
  mkRarityIconByItem
  mkRarityIconByTemplateName
  rarityColorTable
  getRarityColor
  mkRarityCorner
  mkRarityIconByColor
}