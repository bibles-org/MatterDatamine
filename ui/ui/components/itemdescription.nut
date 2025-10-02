from "%sqstd/math.nut" import round_by_value
from "%ui/components/commonComponents.nut" import mkFlexInfoTxt, mkTextArea
from "%ui/hud/state/item_info.nut" import getSlotAvailableMods
from "%ui/hud/state/human_damage_model_state.nut" import getDamageTypeStr
from "%ui/hud/menus/components/inventoryItemRarity.nut" import getRarityColor
import "%ui/components/colorize.nut" as colorize
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/components/colors.nut" import TextNormal, RedWarningColor, GreenSuccessColor, InfoTextValueColor

#allow-auto-freeze

let shootNoiseTbl = freeze([
  { limit = 110, locId = "desc/shotLoudReduced" }
])

let deviationTbl = freeze([
  { limit = 0.74, locId = "desc/deviationHigh" }
  { limit = 0.79, locId = "desc/deviationMedium" }
  { locId = "desc/deviationLow" }
])

let recoilTbl = freeze([
  { limit = 9, locId = "desc/recoilLow" }
  { limit = 15, locId = "desc/recoilMedium" }
  { locId = "desc/recoilHigh" }
])


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
  #forbid-auto-freeze
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

let semiAutoBursts = freeze({
  semi_auto_2_shots = true
  semi_auto_3_shots = true
})

let getTimeBetweenShots = @(template) round_by_value(1.0 / (template?.getCompValNullable("gun__shotFreq") ?? 1), 0.1)

function fillWeaponFiringModes(template, modsArr, resDataArr) {
  foreach(v in (modsArr ?? [])) {
    if (v == "full_auto") {
      let rpm = round_by_value((template.getCompValNullable("gun__shotFreq") ?? 0.0) * 60.0, 0.1)
      resDataArr.append({
        firing = loc($"firing_mode/{v}")
        title = loc("desc/rpm")
        val = $"{rpm} {loc("desc/rpm_units")}"
      })
    }
    else if (v in semiAutoBursts) {
      let time = getTimeBetweenShots(template)
      let idxToEnd = v.indexof("_shot")
      if (idxToEnd != null) {
        let burstCount = v.slice(idxToEnd - 1, idxToEnd)
        let burstDuration = time * burstCount.tointeger()
        let shotsPerTime = $"{burstCount} {loc("desc/shots")} {loc("desc/in")} {burstDuration} {loc("desc/seconds")}"
        resDataArr.append({
          firing = loc($"firing_mode/{v}")
          title = loc("desc/burstSpeed")
          val = shotsPerTime
        })
      }
      resDataArr.append({
        title = loc("desc/timeBetweenBursts")
        val = $"{time} {loc("desc/seconds")}"
      })
    }
    else {
      let time = getTimeBetweenShots(template)
      resDataArr.append({
        firing = loc($"firing_mode/{v}")
        title = loc("desc/timeBetweenShots")
        val = $"{time} {loc("desc/seconds")}"
      })
    }
  }
}

function getLocByLimit(value, limitsTbl) {
  for (local i = 0; i < limitsTbl.len(); ++i) {
    let { limit = null, locId } = limitsTbl[i]
    if (limit == null || value <= limit)
      return loc(locId)
  }

  return null
}

function getShootNoise(template) {
  let shootNoise = template?.getCompValNullable("loud_noise__noisePerShot") ?? template?.loud_noise__noisePerShot
  if (shootNoise == null)
    return null

  let mult = template?.getCompValNullable("gun_entity_mods__loudNoisePerShotMult") ?? template?.gun_entity_mods__loudNoisePerShotMult
  return getLocByLimit(shootNoise * (mult ?? 1.0), shootNoiseTbl)
}

function getDeviation(template) {
  let v = template?.getCompValNullable("gun__recoilDirAmount") ?? template?.gun__recoilDirAmount
  return v == null ? null
    : { value = round_by_value(v, 0.01), desc = getLocByLimit(v, deviationTbl) }
}

function getRecoil(template, isShopDesc = false) {
  let recoil = template?.getCompValNullable("gun__recoilAmount") ?? template?.gun__recoilAmount
  if (recoil == null)
    return null

  let mul = template?.getCompValNullable("gun_entity_mods__recoilMult") ?? template?.gun_entity_mods__recoilMult ?? 1
  let v = round_by_value((recoil ?? 0.0) * (mul ?? 1.0) * 100, 0.01)
  let color = mul < 1.0 ? GreenSuccessColor
    : mul > 1.0 ? RedWarningColor
    : isShopDesc ? InfoTextValueColor
    : TextNormal
  return { value = colorize(color, v), desc = getLocByLimit(v, recoilTbl) }
}

function geMultLowNegative(template, effectName) {
  let effect = template?.getCompValNullable("gun_mod__effectTemplate") ?? template?.gun_mod__effectTemplate
  if (effect == null)
    return null

  let effectTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(effect)
  if (effectTemplate == null)
    return null

  let mul = effectTemplate?.getCompValNullable(effectName)
  if (mul == null || mul == 1)
    return  null

  let color = mul > 1.0 ? GreenSuccessColor : RedWarningColor
  let preffix = mul > 1.0 ? "-" : "+"
  return colorize(color, $"{preffix}{round_by_value((1.0 - mul) * 100.0, 0.1)}%")
}

function geMultLowPositive(template, effectName) {
  let effect = template?.getCompValNullable("gun_mod__effectTemplate") ?? template?.gun_mod__effectTemplate
  if (effect == null)
    return null

  let effectTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(effect)
  if (effectTemplate == null)
    return null

  let mul = effectTemplate?.getCompValNullable(effectName)
  if (mul == null || mul == 1)
    return  null

  let color = mul < 1.0 ? GreenSuccessColor : RedWarningColor
  let preffix = mul < 1.0 ? "-" : "+"
  return colorize(color, $"{preffix}{round_by_value((1.0 - mul) * 100.0, 0.1)}%")
}

function getReloadTime(template, maxAmmo) {
  let reloadBatchTime = template?.getCompValNullable("gun_boxed_ammo_reload__batchReloadTime") ?? 0
  let reloadLoopTime = template?.getCompValNullable("gun_boxed_ammo_reload__loadLoopTime") ?? 0
  if (reloadBatchTime > 0)
    return {
      title = loc("desc/reloadTime")
      val = $"{reloadBatchTime} {loc("desc/seconds")}"
    }
  else if (reloadLoopTime > 0 && maxAmmo > 0) {
    let prep = template?.getCompValNullable("gun_boxed_ammo_reload__loadPrepareTime") ?? 0
    let post = template?.getCompValNullable("gun_boxed_ammo_reload__loadPostTime") ?? 0
    let maxReloadTime = prep + reloadLoopTime * maxAmmo + post
    return {
      title = loc("desc/maxReloadTime")
      val = $"{maxReloadTime} {loc("desc/seconds")}"
    }
  }
  return {}
}

function getWeaponDesc(template, style=null) {
  #forbid-auto-freeze
  let recoil = getRecoil(template, true)
  let deviation = getDeviation(template)
  let caliber = getWeaponAmmo(template)
  let firingModeArr = template.getCompValNullable("gun__firingModeNames")
  let hasMagazineSlot = template?.getCompValNullable("gun_mods__slots").magazine != null
  let maxAmmo = template?.getCompValNullable("gun__maxAmmo") ?? 0
  let reloadTime = getReloadTime(template, maxAmmo)
  let shootNoise = getShootNoise(template)
  let recoilMult = geMultLowPositive(template, "gun_mod_effect__recoilMult")
  let asdSpeedMult = geMultLowNegative(template, "gun_mod_effect__adsSpeedMult")
  let noiseMult = geMultLowPositive(template, "gun_mod_effect__loudNoisePerShotMult")

  let firingModesAndReload = []
  fillWeaponFiringModes(template, firingModeArr, firingModesAndReload)
  let res = [
    caliber.len() ? mkFlexInfoTxt(loc("desc/ammo"), ", ".join(caliber), style) : null
    !hasMagazineSlot && maxAmmo > 0 ? mkFlexInfoTxt(loc("desc/gunCapacity"), maxAmmo, style) : null
  ]
  firingModesAndReload.each(@(v) res.append(
    v?.firing == null ? null : mkFlexInfoTxt(loc("desc/firingModes"), v.firing, style)
    mkFlexInfoTxt(v.title, v.val, style)))
  res.append(
    reloadTime.len() <= 0 ? null : mkFlexInfoTxt(reloadTime.title, reloadTime.val, style)
    recoil != null ? mkFlexInfoTxt(loc("desc/recoil"), loc("desc/valueWithText",
      { value = recoil.value, desc = recoil.desc }), style) : null
    deviation != null ? mkFlexInfoTxt(loc("desc/deviation"), loc("desc/valueWithText",
      { value = deviation.value, desc = deviation.desc }), style) : null
    shootNoise != null ? mkFlexInfoTxt(loc("desc/noise_per_shot"), shootNoise, style) : null
    noiseMult != null ? mkFlexInfoTxt(loc("desc/loud_noise_per_shot"), noiseMult, style) : null
    asdSpeedMult != null ? mkFlexInfoTxt(loc("desc/ads"), asdSpeedMult, style) : null
    recoilMult != null ? mkFlexInfoTxt(loc("desc/recoil"), recoilMult, style) : null
  )
  return res
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
    volume ? mkFlexInfoTxt(loc("desc/volume"), volume, style) : null
    weight ? mkFlexInfoTxt(loc("desc/weight"), weight, style) : null
    useTime ? mkFlexInfoTxt(loc("desc/useTime"), useTime, style) : null
  ]
}

function getGunModSlotTypeLocs(gunmod_slot_template_name) {
  #forbid-auto-freeze
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
  #forbid-auto-freeze
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
  #forbid-auto-freeze
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
  getDeviation
  getRecoil
  getShootNoise
}
