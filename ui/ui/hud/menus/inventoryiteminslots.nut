
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { inventoryItemImage, inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { slotWithItemOpacity, slotEmptyOpacity } = require("%ui/hud/state/inventory_state.nut")


let brokenTemplateVisuals = {
  
  recognizeTime = 1.0
  recognizeTimeLeft = 1.0
  syncTime = 0.0
}

function getTemplateVisuals(templateName) {
  if (!templateName)
    return brokenTemplateVisuals
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (!template)
    return brokenTemplateVisuals

  let iconOffs = template.getCompValNullable("item__iconOffset") ?? { x=0, y=0 }
  return {
    itemName = template.getCompValNullable("item__name") ?? ""
    iconName = template.getCompValNullable("animchar__res") ?? ""
    objTexReplace = template.getCompValNullable("animchar__objTexReplace")?.getAll()
    iconYaw = template.getCompValNullable("item__iconYaw") ?? 0
    iconPitch = template.getCompValNullable("item__iconPitch") ?? 0
    iconRoll = template.getCompValNullable("item__iconRoll") ?? 0
    iconScale = template.getCompValNullable("item__iconScale") ?? 1
    iconRecalcAnimation = template.getCompValNullable("item__iconRecalcAnimation") ?? false
    iconOffsX = iconOffs.x
    iconOffsY = iconOffs.y
    name = template.getCompValNullable("item__name") ?? ""
    itemSlots = template.getCompValNullable("gun_mods__slots")?.getAll() ?? template.getCompValNullable("equipment_mods__slots")?.getAll()
    itemTemplate = templateName
  }
}

function equipmentWidgetByTemplateName(templateName, slot=null, params={}, iconParams=inventoryImageParams) {
  local itemDummy = templateName ? getTemplateVisuals(templateName) : null
  let isEmpty = itemDummy == null
  if (!itemDummy) {
    let defaultSlot = humanEquipmentSlots?[slot] ?? {}
    local defaultIcon = defaultSlot?.defaultIcon
    local slotTooltip = defaultSlot?.slotTooltip

    if (!defaultIcon || !slotTooltip) {
      let slotTemplate = slot ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slot) : null
      if (slotTemplate) {
        defaultIcon = slotTemplate?.getCompValNullable("mod_slot__icon") ?? ""
        slotTooltip = slotTemplate?.getCompValNullable("mod_slot__tooltip") ?? ""
      }
    }

    itemDummy = {
      defaultIcon
      slotTooltip
    }
  }

  return {
    size = [fsh(8),fsh(8)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      opacity = isEmpty ? slotEmptyOpacity : slotWithItemOpacity
      children = inventoryItemImage(itemDummy, iconParams)
    }
  }.__merge(params)
}

return {
  getTemplateVisuals
  equipmentWidgetByTemplateName
}