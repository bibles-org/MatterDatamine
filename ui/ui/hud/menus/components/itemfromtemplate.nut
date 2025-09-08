import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let slotQuery = ecs.SqQuery("slotQuery", {
  comps_ro = [
    ["uniqueId", ecs.TYPE_STRING, "0"]
  ]
})

function getSlotFromTemplate(slotTemplateName, additionalFields = {}, parentId = ecs.INVALID_ENTITY_ID) {
  let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplateName)
  local uniqueId = 0
  slotQuery.perform(parentId, function (__eid, comp) {
    uniqueId = comp["uniqueId"]
  })
  return {
    defaultIcon = slotTemplate?.getCompValNullable("mod_slot__icon") ?? ""
    slotTooltip = slotTemplate?.getCompValNullable("mod_slot__tooltip") ?? ""
    allowed_items = slotTemplate?.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []
    slotTemplateName = slotTemplateName
    iconImageColor = Color(101, 101, 101, 51)
    itemPropsId = 0
    uniqueId
  }.__merge(additionalFields)
}

return {
  getSlotFromTemplate
}