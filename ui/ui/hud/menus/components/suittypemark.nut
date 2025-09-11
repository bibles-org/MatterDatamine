from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/components/cursors.nut" import setTooltip

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { equipment } = require("%ui/hud/state/equipment.nut")

#allow-auto-freeze

let itemTooltipNameColor = Color(178,178,250)
let itemTooltipDescColor = Color(180,180,180)
let itemTooltipHelpColor = Color(225,180,140)


let suitTypeMarkSuitQuery = ecs.SqQuery("suitTypeMarkSuitQuery",
{
  comps_ro=[
    ["suit__raidIcon", ecs.TYPE_STRING]
  ]
})


function buildSuitTypeMarkTooltip() {
  let suit = equipment.get()?["chronogene_primary_1"]

  if (suit != null) {
    let name = loc(suit?.itemName, "") ?? ""
    let itemName = suit?.itemDescription == null ? loc("{0}/desc".subst(suit?.itemName ?? ""), "") : loc(suit?.itemDescription, "")
    let help = loc("{0}/help".subst(suit?.itemName ?? ""), "") ?? ""

    local tooltip = name != "" ? $"<color={itemTooltipNameColor}>{name}</color>" : ""
    if (itemName != "")
      tooltip = $"{tooltip}\n\n<color={itemTooltipDescColor}>{itemName}</color>"
    if (help != "")
      tooltip = $"{tooltip}\n\n<color={itemTooltipHelpColor}>{help}</color>"

    return tooltip
  }

  return "unknown"
}

function suitTypeMark() {

  let suit = equipment.get()?["chronogene_primary_1"]
  local icon = "!ui/skin#raid_info/turned.svg"

  if (suit != null) {
    let comps = suitTypeMarkSuitQuery.perform(
      suit?.eid ?? ecs.INVALID_ENTITY_ID,
      @(_eid, comp) comp)

    let suitIcon = comps?.suit__raidIcon ?? ""
    if (suitIcon != "")
      icon = suitIcon
  }

  return {
    watch = equipment
    rendObj = ROBJ_IMAGE
    size = [itemHeight, itemHeight]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
    behavior = Behaviors.Button
    onHover = function(on) {
      if (on) {
        let tooltip = buildSuitTypeMarkTooltip()
        setTooltip(tooltip)
      }
      else {
        setTooltip(null)
      }
    }
    color = Color(255, 255, 255, 80)
    image = Picture($"{icon}:{itemHeight}:{itemHeight}:K")
  }
}

return {
  suitTypeMark
}
