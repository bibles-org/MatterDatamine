from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkFlexInfoTxt, mkTextArea } = require("%ui/components/commonComponents.nut")
let { getSlotAvailableMods } = require("%ui/hud/state/item_info.nut")
let { getDamageTypeStr } = require("%ui/hud/state/human_damage_model_state.nut")
let { ceil_volume } = require("das.inventory")
let { getRarityColor } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let colorize = require("%ui/components/colorize.nut")

function getBoxedAmmoName(templateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let ammoName = template?.getCompValNullable("boxed_item__itemName")
  if (ammoName)
    return loc(ammoName)
  if (template?.getCompValNullable("boxedItem"))
    return loc(template.getCompValNullable("item__name"))
  return null
}

function getMagazineCaliber(template) {
  let ammoHolder = template?.getCompValNullable("item_holder__boxedItemTemplate") ?? ""

  if (ammoHolder != "") {
    let ammoName = getBoxedAmmoName(ammoHolder)
    if (ammoName)
      return ammoName
  }
  return null
}

function getWeaponAmmo(template) {
  let modsSlots = template?.getCompValNullable("gun_mods__slots")
  let ammo = {}
  let magazineSlotTemplateName = modsSlots?.magazine ?? ""
  if (magazineSlotTemplateName != "") {

    let magazines = getSlotAvailableMods(magazineSlotTemplateName)
    foreach(k in magazines) {
      let magazineTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(k)
      let ammoName = getMagazineCaliber(magazineTemplate)
      if (ammoName)
        ammo[ammoName] <- null
    }
  }
  let ammoHolders = template?.getCompValNullable("gun__ammoHolders")
  foreach(v in ammoHolders ?? []) {
    let ammoName = getBoxedAmmoName(v)
    if (ammoName)
      ammo[ammoName] <- null
  }
  return ammo.keys()
}

function getWeaponDesc(template, style=null) {
  let recoil = template?.getCompValNullable("gun__recoilAmount")
  let deviation = template?.getCompValNullable("gun_deviation__maxDeviation")
  let shotFreq = template?.getCompValNullable("gun__shotFreq")
  let caliber = getWeaponAmmo(template)
  let firingModeArr = template.getCompValNullable("gun__firingModeNames")

  let firingModes = []
  foreach(_k, v in (firingModeArr ?? [])) {
    firingModes.append(loc($"firing_mode/{v}"))
  }

  return [
    recoil ? mkFlexInfoTxt(loc("desc/recoil"), recoil, style) : null
    deviation ? mkFlexInfoTxt(loc("desc/deviation"), deviation, style) : null
    shotFreq ? mkFlexInfoTxt(loc("desc/shotFreq"), shotFreq, style) : null
    caliber.len() ? mkFlexInfoTxt(loc("desc/ammo"), ", ".join(caliber), style) : null
    firingModeArr ? mkFlexInfoTxt(loc("desc/firingModes"), ", ".join(firingModes), style) : null
  ]
}

function getCommonItemDesc(template, style=null) {
  local volume = null
  local weight = null
  if (template?.getCompValNullable("boxedItem")) {
    volume = template?.getCompValNullable("item__volumePerStack")
    weight = template?.getCompValNullable("item__weightPerStack")
  }
  else {
    volume = template?.getCompValNullable("item__volume")

    let w = template?.getCompValNullable("item__baseWeight") ?? 0
    weight = w > 0 ? w : template?.getCompValNullable("item__weight")
  }

  let useTime = template?.getCompValNullable("item__useTime")

  return [
    volume ? mkFlexInfoTxt(loc("desc/volume"), ceil_volume(volume), style) : null
    weight ? mkFlexInfoTxt(loc("desc/weight"), weight, style) : null
    useTime ? mkFlexInfoTxt(loc("desc/useTime"), useTime, style) : null
  ]
}

function getGunModSlotTypeLocs(gunmod_slot_template_name) {
  local result = []

  let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(gunmod_slot_template_name)
  if (slotTemplate == null)
    return null
  else {
    let typeLocs = slotTemplate?.getCompValNullable("mod_slot__typeLocs")

    if (typeLocs != null) {
      foreach (typeLoc in typeLocs) {
        result.append(typeLoc)
      }
    }
  }

  return result
}

function getScopeDesc(template, style=null) {
  let zoomFactor = template?.getCompValNullable("gunmod__zoomFactor")
  let scopeMounting = template?.getCompValNullable("gunmod__slots").getAll() ?? []
  local typeLocs = []
  foreach (slot in scopeMounting) {
    foreach (typeLoc in getGunModSlotTypeLocs(slot ?? "")) {
      if (!typeLocs.contains(typeLoc))
        typeLocs.append(typeLoc)
    }
  }

  let localizedSlots = ",".join(typeLocs.map(@(str) loc(str)))

  return [
    zoomFactor ? mkFlexInfoTxt(loc("desc/zoomFactor"), zoomFactor, style) : null
    localizedSlots != "" ? mkFlexInfoTxt(loc("desc/mountingType"), localizedSlots, style) : null
  ]
}

function getAmmoDesc(template, style=null) {
  let ammoCount = template?.getCompValNullable("item__countPerStack") ?? template?.getCompValNullable("item_holder__maxItemCount")
  let ammoCaliber = getMagazineCaliber(template)
  let isHealkit = template?.getCompValNullable("item__filterType") == "medicines"
  let canLoadOnlyOnBase = template?.getCompValiNullable("item_holder__canLoadOnlyOnBase") != null

  return [
    ammoCaliber != null ? mkFlexInfoTxt(loc(isHealkit ? "desc/healing_ampoule_ammo" : "desc/ammo"), ammoCaliber, style) : null
    ammoCount ? mkFlexInfoTxt(loc(isHealkit ? "desc/healing_ampoule_ammoCount" : "desc/ammoCount"), ammoCount, style) : null
    canLoadOnlyOnBase ? loc("desc/item_holder_can_load_only_on_base") : null
  ]
}

function getHealkitDesc(template, style=null) {
  let result = []
  let healStreaming = template?.getCompValNullable("item_heal_stream") != null
  let healTemplName = template?.getCompValNullable("item__healTemplateName") ?? ""
  if (healStreaming) {
    let healAmount = template?.getCompValNullable("item__maxAmount") ?? 0
    let healTick = template?.getCompValNullable("item_heal__healTick") ?? 0
    let healPerTick = template?.getCompValNullable("item_heal__healPerTick") ?? 0
    let healTime = healAmount / (1 / healTick * healPerTick)
    result.append(mkFlexInfoTxt(loc("desc/healAmount"), healAmount, style))
    result.append(mkFlexInfoTxt(loc("desc/healTicks"), healTime, style))
  }
  else if (healTemplName != "") {
    let healTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(healTemplName)
    let healAmount = healTempl?.getCompValNullable("healing_effect__healAmount") ?? 0.0
    if (healAmount > 0.0)
      result.append(mkFlexInfoTxt(loc("desc/healAmount"), healAmount, style))

    let healByTickAmount = healTempl?.getCompValNullable("healing_effect__healByTickAmount") ?? 0.0
    let healTicksCount = healTempl?.getCompValNullable("healing_effect__healTicksCount") ?? 0
    let healTick = healTempl?.getCompValNullable("healing_effect__healTick") ?? 0.0
    if (healTicksCount > 0 && healTick > 0 && healByTickAmount > 0.0){
      result.append(mkFlexInfoTxt(loc("desc/healAmount"), healByTickAmount * healTicksCount, style))
      result.append(mkFlexInfoTxt(loc("desc/healTicks"), healTicksCount * healTick, style))
    }
  }
  return result
}

function getBackpacksDesc(template, style=null) {
  let inventoryExtension = template?.getCompValNullable("item__inventoryExtension")
  let inventorySize = template?.getCompValNullable("human_inventory__maxVolume")

  return [
    inventoryExtension ? mkFlexInfoTxt(loc("desc/inventoryExtension"), inventoryExtension, style) : null
    inventorySize ? mkFlexInfoTxt(loc("desc/inventorySize"), inventorySize, style) : null
  ]
}

function getArmorDesc(template, style=null) {
  let durability = template?.getCompValNullable("item__maxHp")
  let protection = template?.getCompValNullable("dm_part_armor__protection")?.getAll() ?? []

  return [
    durability ? mkFlexInfoTxt(loc("desc/durability"), durability, style) : null
  ].extend(protection.map(@(val, idx) val <= 0 ? null
      : mkFlexInfoTxt(loc($"desc/{getDamageTypeStr(idx)}_damage_protection"), $"{val * 100}%", style)))
}

function getItemRarity(template, templateName, style=null) {
  let rarity = template?.getCompValNullable("item__rarity")
  if (rarity == null)
    return []
  let color = getRarityColor(rarity, templateName)
  return [mkFlexInfoTxt(loc("desc/rarity"), colorize(color, loc($"item/rarity/{rarity}")), style)]
}

function getWeaponType(template, style=null) {
  let weapType = template?.getCompValNullable("item__weapType")
  if (weapType == null)
    return []
  return [mkFlexInfoTxt(loc("desc/weapType"), loc($"items/types/{weapType}"), style)]
}

function getItemDescription(template, style=null) {
  local descriptionStr = loc(template?.getCompValNullable("item__desc"), "")
  if (descriptionStr == null) {
    let itemName = template?.getCompValNullable("item__name")
    if (itemName) {
      descriptionStr = loc($"{itemName}/desc", "")
    }
  }
  return descriptionStr == "" ? [] : [mkTextArea($"{descriptionStr}\n", style)] 
}

function itemDescriptionStrings(templateName, style=null) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let description = getItemDescription(template, style)
  let rarity = getItemRarity(template, templateName, style)
  let weaponType = getWeaponType(template, style)
  let common = getCommonItemDesc(template, style)
  let weapon = getWeaponDesc(template, style)
  let scope = getScopeDesc(template, style)
  let ammo = getAmmoDesc(template, style)
  let heal = getHealkitDesc(template, style)
  let backpack = getBackpacksDesc(template, style)
  let armor = getArmorDesc(template, style)

  return [].extend(description, rarity, weaponType, weapon, scope, ammo, heal, backpack, armor, common)
}

return {
  itemDescriptionStrings

  getArmorDesc
}