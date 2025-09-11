from "%ui/hud/state/item_info.nut" import getSlotAvailableMods
from "dagor.debug" import logerr

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { template2MarketIds } = require("%ui/mainMenu/market/inventoryToMarket.nut")

let customFilter = Watched({ filterToUse = null })

function getTemplateType(templateName) {
  let templ = templateName == null ? null
    : ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  return templ?.getCompValNullable("item__filterType") ?? "loot"
}

let getItemTemplate = @(template_name) template_name
  ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template_name) : null

function weaponRelated(item_val, item_key, relatedList, marketOffers) {
  let weaponTemplate = getItemTemplate(item_val.children.items[0]?.templateName)
  let gunMods = weaponTemplate.getCompValNullable("gun_mods__slots")?.getAll() ?? {}
  let ammoHolders = weaponTemplate.getCompValNullable("gun__ammoHolders")?.getAll() ?? []
  local relatedMods = []
  local relatedBoxedAmmo = ammoHolders.map(@(v) marketOffers.findindex(@(c) c?.children.items[0].templateName == v)).filter(@(v) v != null)

  foreach (slot, slotTemplateName in gunMods){
    let allowedMods = getSlotAvailableMods(slotTemplateName)

    relatedMods.extend((allowedMods.map(@(v) marketOffers.findindex(@(c) c?.children.items[0].templateName == v))).filter(@(v) v != null))
    if (slot != "magazine")
      continue
    foreach (m in allowedMods){
      let magazineTemplate = getItemTemplate(m)
      let boxedAmmoHolderTemplateName = magazineTemplate.getCompValNullable("item_holder__boxedItemTemplate")
      if (boxedAmmoHolderTemplateName == null)
        continue
      let boxedAmmoId = marketOffers.findindex(@(c) c?.children.items[0].templateName == boxedAmmoHolderTemplateName)
      let magazineId = marketOffers.findindex(@(c) c?.children.items[0].templateName == m)
      if (magazineId && boxedAmmoId){
        if (boxedAmmoId not in  relatedList)
          relatedList[boxedAmmoId] <- []
        if (magazineId not in  relatedList)
          relatedList[magazineId] <- []
        relatedList[boxedAmmoId].append(magazineId)
        relatedList[magazineId].append(boxedAmmoId)
        relatedBoxedAmmo.append(boxedAmmoId)
      }
    }
  }
  relatedMods.each(function(v) {
    if (v not in relatedList)
      relatedList[v] <- []
    relatedList[v].append(item_key)
  })
  if (weaponTemplate.getCompValNullable("gun__boxedAmmoHolderTemplate")){
    relatedBoxedAmmo.each(function(v) {
      if (v not in relatedList)
        relatedList[v] <- []
      relatedList[v].append(item_key)
    })
  }
  if (item_key not in relatedList)
    relatedList[item_key] <- []
  relatedList[item_key].extend(relatedMods, relatedBoxedAmmo)
}

function equipmentRelated(item_val, relatedList) {
  let templateName = item_val.children.items[0]?.templateName
  let eq = getItemTemplate(templateName)
  if (eq == null) {
    logerr($"equipmentRelated: undefined equipment template - {templateName}!")
    return
  }
  let slot = eq.getCompValNullable("slot_attach__slotName")
  if (slot == "suit") {
    let suitId = item_val?.id
    if (!suitId)
      return
    let slots = eq.getCompValNullable("equipment_mods__slots")?.getAll() ?? []
    foreach (slotTemplateName in slots) {
      let availableModTemplates = getSlotAvailableMods(slotTemplateName)

      foreach (items in availableModTemplates) {
        let suitModId = template2MarketIds.get()?[items]
        if (!suitModId)
          continue
        if (suitId not in relatedList)
          relatedList[suitId] <- []
        if (suitModId not in relatedList)
          relatedList[suitModId] <- []
        relatedList[suitId].append(suitModId)
        relatedList[suitModId].append(suitId)
      }
    }
  }
}


return {
  weaponRelated
  getItemTemplate
  equipmentRelated
  customFilter
  getTemplateType
}