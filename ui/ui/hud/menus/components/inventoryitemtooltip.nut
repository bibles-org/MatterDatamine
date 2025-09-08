from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { getDamageTypeStr } = require("%ui/hud/state/human_damage_model_state.nut")
let { round_by_value, lerp, truncateToMultiple } = require("%sqstd/math.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { get_item_info, getSlotAvailableMods, chronogeneStatCustom, chronogeneStatDefault, chronogeneEffectCalc,
  get_equipped_magazine_current_ammo_count } = require("%ui/hud/state/item_info.nut")
let { playerProfileAMConvertionRate, playerProfileAllResearchNodes, playerProfileOpenedNodes,
  allCraftRecipes, marketItems } = require("%ui/profile/profileState.nut")
let { creditsTextIcon, amTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { DBGLEVEL } = require("dagor.system")
let { nestWatched } = require("%dngscripts/globalState.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { tooltipHotkeyHints } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { rarityColorTable } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { RarityCommon, corruptedItemColor } = require("%ui/components/colors.nut")
let console = require("console")
let colorize = require("%ui/components/colorize.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { calc_stacked_item_volume } = require("das.inventory")

let { ceil } = require("math")
let { logerr } = require("dagor.debug")
let string = require("string")

let itemTooltipNameColor = Color(200,200,200)
let itemQuestTooltipStatColor = Color(245,150,0)
let itemStubTooltipStatColor = Color(110,110,110)
let itemTooltipStatColor = Color(225,180,140)
let itemTooltipBonusDescColor = Color(138,138,138)
let itemTooltipDescColor = Color(180,180,180)
let itemTooltipStatValueIncreasedColor = Color(45, 255, 45)
let itemTooltipStatValueDecreasedColor = Color(255, 40, 40)

let corruptedItemBackground = {
  rendObj = ROBJ_IMAGE
  size = [flex(), hdpxi(100)]
  color = corruptedItemColor
  image = Picture("ui/skin#corruptedWeaponBorder.svg:{0}:{1}:K".subst(hdpxi(200), hdpxi(200)))
}

let semiAutoBursts = {
  semi_auto_2_shots = true
  semi_auto_3_shots = true
}

let shootNoiseTbl = [
  {
    limit = 60,
    locId = "desc/shotSilent"
  }
  {
    limit = 110
    locId = "desc/shotQuiet"
  }
  {
    limit = 170
    locId = "desc/shotLoud"
  }
]

let tooltipSeparator = {
  rendObj = ROBJ_SOLID
  size = [flex(), hdpx(1)]
  color = itemStubTooltipStatColor
}

let showDebugTooltips = nestWatched("showDebugTooltips", false)
console.register_command(@() showDebugTooltips.modify(@(v) !v), "am.toggle_debug_tooltips")

let itemTooltipDamageMult = 10.0

let inventoryItemTooltipQuery = ecs.SqQuery("inventoryItemTooltipQuery",
  {
    
    comps_ro = [
      ["gun__recoilAmount", ecs.TYPE_FLOAT, null],
      ["gun_deviation__maxDeviation", ecs.TYPE_FLOAT, null],
      ["loud_noise__noisePerShot", ecs.TYPE_FLOAT, null],
      ["gun_entity_mods__loudNoisePerShotMult", ecs.TYPE_FLOAT, null],
      ["gun_entity_mods__damageMult", ecs.TYPE_FLOAT, null],
      ["gun__kineticDamageMult", ecs.TYPE_FLOAT, null],
      ["gun_mod__effectTemplate", ecs.TYPE_STRING, null],
      ["boxed_item__itemName", ecs.TYPE_STRING, null],
      ["item_healkit_magazine", ecs.TYPE_TAG, null],
      ["item_heal_ampoule", ecs.TYPE_TAG, null],
      ["gunmod__slots", ecs.TYPE_STRING_LIST, null],
      ["item__ampouleHealAmount", ecs.TYPE_FLOAT, null],
      ["item__boostTemplateName", ecs.TYPE_STRING, null],
      ["item__lootType", ecs.TYPE_STRING, ""],
      ["equipment__setDefaultStubMeleeTemplate", ecs.TYPE_STRING, null],
      ["default_stub_item", ecs.TYPE_TAG, null],
      ["questItemTooltip", ecs.TYPE_TAG, null],
      ["valuableItem", ecs.TYPE_TAG, null],
      ["entity_mod_effects", ecs.TYPE_OBJECT, null],
      ["key__tags", ecs.TYPE_STRING_LIST, null],
      ["key__scenes", ecs.TYPE_STRING_LIST, null],
      ["binoculars_item__binocularsAffectTemplate", ecs.TYPE_STRING, null],
      ["itemContainer", ecs.TYPE_EID_LIST, null],
      ["human_inventory__tooltipItems", ecs.TYPE_TAG, null],
      ["weapon_stat__rpm", ecs.TYPE_FLOAT, null],
      ["item__weight", ecs.TYPE_FLOAT, 0],
      ["item__volume", ecs.TYPE_FLOAT, 0],
      ["dm_part_armor__protection", ecs.TYPE_FLOAT_LIST, null],
      ["gun__firingModeNames", ecs.TYPE_ARRAY, []],
      ["gun_boxed_ammo_reload__batchReloadTime", ecs.TYPE_FLOAT, 0],
      ["gun__maxAmmo", ecs.TYPE_INT, 0],
      ["gun__shotFreq", ecs.TYPE_FLOAT, 1],
      ["gun_boxed_ammo_reload__loadPrepareTime", ecs.TYPE_FLOAT, 0],
      ["gun_boxed_ammo_reload__loadLoopTime", ecs.TYPE_FLOAT, 0],
      ["item__weapType", ecs.TYPE_STRING, null],
      ["dogtag_item", ecs.TYPE_TAG, null],
    ].extend(DBGLEVEL != 0 ? [
      ["weapon_stat__damage", ecs.TYPE_FLOAT, 0.0],
      ["weapon_stat__damageCount", ecs.TYPE_INT, 1],
      ["weapon_stat__dps", ecs.TYPE_FLOAT, 0.0]
    ] : [])
  }
)

function getTimeBetweenShots(comps) {
  let time = round_by_value(1.0 / (comps?.gun__shotFreq ?? 1), 0.1)
  return time
}

function formatStatValueTextByKoef(value, koef) {
  if (koef != 0.0)
    return $"<color={koef > 0.0 ? itemTooltipStatValueIncreasedColor : itemTooltipStatValueDecreasedColor}>{value}</color>"
  return $"{value}"
}

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
  let ammo = []
  let magazineSlotTemplateName = modsSlots?.magazine ?? ""
  if (magazineSlotTemplateName != "") {
    let magazines = getSlotAvailableMods(magazineSlotTemplateName)
    foreach(k in magazines) {
      let magazineTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(k)
      let ammoName = getMagazineCaliber(magazineTemplate)
      if (ammoName)
        ammo.append(ammoName)
    }
  }
  let ammoHolders = template?.getCompValNullable("gun__ammoHolders")
  foreach(v in ammoHolders ?? []) {
    let ammoName = getBoxedAmmoName(v)
    if (ammoName)
      ammo.append(ammoName)
  }

  return ammo
}


function getGunModSlotTypeLocs(gunmod_slot_template_name) {
  local result = []

  let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(gunmod_slot_template_name)
  if (slotTemplate == null) {
    logerr($"Unknown gunmod slot template: {gunmod_slot_template_name}")
  }
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

function coloredText(color, header, text = null) {
  if (text)
    return "<color={0}>{1}</color> {2}".subst(color, header, text)
  return "<color={0}>{1}</color>".subst(color, header)
}

function headerText(header, text = null) {
  if (text)
    return "<header>{0} {1}</header>".subst(header, text)
  return "<header>{0}</header>".subst(header)
}

function coloredStatText(header, text = null) {
  return coloredText(itemTooltipStatColor, header, text)
}

function buildInventoryItemName(item) {
  return loc(
    item?.itemName,
    {
      nickname = remap_nick(item?.ownerNickname)
    },
    "") ?? ""
}

function getFromTemplate(template) {
  if (!template)
    return {}

  
  return {
    gun__recoilAmount = template.getCompValNullable("gun__recoilAmount")
    gun_deviation__maxDeviation = template.getCompValNullable("gun_deviation__maxDeviation")
    loud_noise__noisePerShot = template.getCompValNullable("loud_noise__noisePerShot")
    gun_entity_mods__loudNoisePerShotMult = template.getCompValNullable("gun_entity_mods__loudNoisePerShotMult")
    gun_entity_mods__damageMult = template.getCompValNullable("gun_entity_mods__damageMult")
    gun__kineticDamageMult = template.getCompValNullable("gun__kineticDamageMult")
    gun_mod__effectTemplate = template.getCompValNullable("gun_mod__effectTemplate")
    boxed_item__itemName = template.getCompValNullable("boxed_item__itemName")
    item_healkit_magazine = template.getCompValNullable("item_healkit_magazine")
    item_heal_ampoule = template.getCompValNullable("item_heal_ampoule")
    gunmod__slots = template.getCompValNullable("gunmod__slots")
    item__ampouleHealAmount = template.getCompValNullable("item__ampouleHealAmount")
    item__boostTemplateName = template.getCompValNullable("item__boostTemplateName")
    equipment__setDefaultStubMeleeTemplate = template.getCompValNullable("equipment__setDefaultStubMeleeTemplate")
    default_stub_item = template.getCompValNullable("default_stub_item")
    questItemTooltip = template.getCompValNullable("questItemTooltip")
    entity_mod_effects = template.getCompValNullable("entity_mod_effects")
    key__tags = template.getCompValNullable("key__tags")
    key__scenes = template.getCompValNullable("key__scenes")
    binoculars_item__binocularsAffectTemplate = template.getCompValNullable("binoculars_item__binocularsAffectTemplate")
    itemContainer = template.getCompValNullable("itemContainer")
    human_inventory__tooltipItems = template.getCompValNullable("human_inventory__tooltipItems")
    item__weight = template.getCompValNullable("item__weight")
    item__volume = template.getCompValNullable("item__volume")
    dm_part_armor__protection = template?.getCompValNullable("dm_part_armor__protection")?.getAll() ?? []
    valuableItem = template.getCompValNullable("valuableItem")
    gun__firingModeNames = template.getCompValNullable("gun__firingModeNames")
    gun_boxed_ammo_reload__batchReloadTime = template.getCompValNullable("gun_boxed_ammo_reload__batchReloadTime") ?? 0
    gun__maxAmmo = template.getCompValNullable("gun__maxAmmo") ?? 0
    gun__shotFreq = template.getCompValNullable("gun__shotFreq") ?? 1
    weapon_stat__rpm = (template.getCompValNullable("gun__shotFreq") ?? 0.0) * 60.0 
    gun_boxed_ammo_reload__loadPrepareTime = template.getCompValNullable("gun_boxed_ammo_reload__loadPrepareTime") ?? 0
    gun_boxed_ammo_reload__loadLoopTime = template.getCompValNullable("gun_boxed_ammo_reload__loadLoopTime") ?? 0
    gun_boxed_ammo_reload__loadPostTime = template.getCompValNullable("gun_boxed_ammo_reload__loadPostTime") ?? 0
    item__weapType = template.getCompValNullable("item__weapType") ?? ""
    itemDescription = template.getCompValNullable("item__desc")
  }
}

function getFromEid(eid) {
  return inventoryItemTooltipQuery.perform(eid, @(_eid, comp) comp)
}

function getComps(item) {
  let eid = item?.eid
  let template = item?.itemTemplate ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate) : null
  let common = {
    itemRarity = template?.getCompValNullable("item__rarity")
    isFlamethrower = template?.getCompValNullable("flamethrower__active") != null
  }

  if (eid && eid != ecs.INVALID_ENTITY_ID) {
    local ret = getFromEid(eid)
    if (!ret) {
      print($"[Item tooltip] Getting fields failed. inventoryItemTooltipQuery is null. Eid: {eid}, Tempate: {item?.itemTemplate}. Trying to pick up fields from template")
      ret = getFromTemplate(template)
    }
    if (ret.len() == 0)
      print($"[Item tooltip] Cannot restore failed query from template. Eid: {eid}, Tempate: {item?.itemTemplate}")
    return ret.__update(common)
  }
  if (template) {
    return getFromTemplate(template).__update(common)
  }
  return {}
}

function canResearchBeOpened(itemTemplate) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
  local templateToUse = template?.getCompValNullable("profile_server_data__enrichmentResearchAlias") ?? itemTemplate
  foreach (id, recipe in playerProfileAllResearchNodes.get()) {
    let { containsRecipe = null } = recipe
    let { results = {} } = allCraftRecipes.get()?[containsRecipe]
    if ( results.len() > 1)
      continue
    if (templateToUse in results && id not in playerProfileOpenedNodes.get())
      return true

    foreach (rId, _v in results) {
      let { items = [] } = marketItems.get()?[rId].children
      if (items?[0].templateName == templateToUse && id not in playerProfileOpenedNodes.get())
        return true
    }
  }
  return false
}

let get_dogtag_info_query = ecs.SqQuery("get_dogtag_info_query", {
  comps_ro = [["cortical_vault_inactive__killerNickname", ecs.TYPE_STRING],
              ["cortical_vault_inactive__killedByWeapon", ecs.TYPE_STRING],
              ["cortical_vault_inactive__deathReason", ecs.TYPE_STRING]]
  comps_rq = ["dogtag_item"]
})

function buildInventoryItemTooltip(item, additionalHints={}) {
  if ((item == null || item?.itemTemplate == null || ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate) == null) &&
    additionalHints != null && additionalHints.len() == 0) {
    return {}
  }

  let comps = item ? getComps(item) : {}

  local tooltip = []

  let itemsCount = item?.count ?? 0

  
  let name = buildInventoryItemName(item)
  if (name != "") {
    let countText = itemsCount > 1 ? $" ({loc("ui/multiply")}{itemsCount})" : null
    tooltip.append(headerText(name, countText))
  }
  if (comps?.itemRarity) {
    let nameColor = rarityColorTable?[comps?.itemRarity] ?? RarityCommon
    tooltip.append(coloredText(nameColor, loc($"item/rarity/{comps.itemRarity}", "Unknown")))
  }

  
  local statsTooltip = []

  
  if (comps?.key__scenes != null) {
    let queues = matchingQueuesMap.get()
    let keyScenes = comps.key__scenes.getAll() ?? []
    let queuesLoc = queues.reduce(function(res, q) {
      let scenes = q.scenes ?? []
      if (scenes.findindex(@(s) keyScenes.findindex(@(k) s.fileName.startswith(k)) != null) != null) {
        let data = loc(q.locId)
        if (!res.contains(data))
          res.append(data)
      }
      return res
    }, [])
    if (queuesLoc.len() > 0)
      statsTooltip.append(coloredStatText(loc("desc/keyScenes"), ", ".join(queuesLoc)))
  }

  
  if (comps?.weapon_stat__dps && showDebugTooltips.get()) {
    let gunDamageMult = (comps?.gun_entity_mods__damageMult ?? 1.0) * (comps?.gun__kineticDamageMult ?? 1.0)
    let damageCount = comps?.weapon_stat__damageCount ?? 1
    let dpsVal = round_by_value(itemTooltipDamageMult * damageCount * (gunDamageMult * (comps?.weapon_stat__dps ?? 0.0)), 0.1)
    statsTooltip.append(coloredStatText(loc("desc/dps"), dpsVal))
  }

  
  if (comps?.weapon_stat__damage && showDebugTooltips.get()) {
    let gunDamageMult = (comps?.gun_entity_mods__damageMult ?? 1.0) * (comps?.gun__kineticDamageMult ?? 1.0)
    let damageCount = comps?.weapon_stat__damageCount ?? 1
    let singleDamageRounded = round_by_value(itemTooltipDamageMult * (gunDamageMult * (comps?.weapon_stat__damage ?? 0.0)), 0.1)

    local totalDamage = 0
    if (damageCount <= 1)
      totalDamage = formatStatValueTextByKoef($"{singleDamageRounded}", (comps?.gun_entity_mods__damageMult ?? 1.0) - 1.0)
    else {
      totalDamage = formatStatValueTextByKoef(round_by_value(itemTooltipDamageMult * damageCount * (comps?.weapon_stat__damage ?? 0.0), 0.1), (comps?.gun_entity_mods__damageMult ?? 1.0) - 1.0)
      totalDamage = "{0} ({1} {2} {3})".subst(totalDamage, singleDamageRounded, loc("ui/multiply"), damageCount)
    }
    statsTooltip.append(coloredStatText(loc("desc/damage"), totalDamage))
  }


  
  if (item?.isWeapon ?? false) {
    let weaponTemplateName = ecs.g_entity_mgr.getEntityTemplateName(item?.eid ?? ecs.INVALID_ENTITY_ID)
    if (weaponTemplateName != null) {
      let weaponTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(weaponTemplateName)
      let ammo = getWeaponAmmo(weaponTemplate)
      if (ammo.len() > 0)
        statsTooltip.append(coloredStatText(loc("desc/ammo"), ammo[0]))
      if (item?.mods.magazine != null) {
        let { itemTemplate = null } = item?.modInSlots.magazine
        if (itemTemplate != null) {
          let magazineTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
          let capacity = magazineTemplate?.getCompValNullable("item_holder__maxItemCount") ?? 0
          if (capacity > 0)
            statsTooltip.append(coloredStatText(loc("desc/magazineCapacity"), capacity))
        }
      }
      else if (item?.mods.magazine == null && (comps?.gun__maxAmmo ?? 0) > 0)
        statsTooltip.append(coloredStatText(loc("desc/gunCapacity"), comps.gun__maxAmmo))
      else if ((comps?.item__lootType ?? "") == "melee") {
        local typeText = loc("items/types/melee")

        if (comps?.default_stub_item)
          typeText = $"{typeText} ({loc("item/default_stub_weapon")})"

        tooltip.append(coloredText(itemStubTooltipStatColor, typeText))
      }
    }
    if ((comps?.item__weapType ?? "melee") != "melee") {
      let typeText = loc($"items/types/{comps?.item__weapType}")
      tooltip.append(coloredText(itemStubTooltipStatColor, typeText))
    }
  }
  else if ((item?.isAmmo ?? false) &&
    (((item?.isBoxedItem ?? false) == false) || (comps?.boxed_item__itemName != null))) {
    
    let ammoTemplateName = ecs.g_entity_mgr.getEntityTemplateName(item?.eid ?? ecs.INVALID_ENTITY_ID)
    if (ammoTemplateName != null) {
      let ammoTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(ammoTemplateName)
      local ammo = []
      let ammoName = getMagazineCaliber(ammoTemplate)
      if (ammoName)
        ammo.append(ammoName)
      let boxedAmmoName = getBoxedAmmoName(ammoTemplateName)
      if (boxedAmmoName)
        ammo.append(boxedAmmoName)

      if (ammo.len() > 0 && comps.item_heal_ampoule == null) {
        if (comps?.item_healkit_magazine != null)
          statsTooltip.append(coloredStatText(loc("desc/healing_ampoule_ammo"), ammo[0]))
        else
          statsTooltip.append(coloredStatText(loc("desc/ammo"), ammo[0]))
      }
    }
  }

   
  if (comps?.questItemTooltip)
    tooltip.append(coloredText(itemQuestTooltipStatColor, loc("item/questItem")))
  if (item?.isCorrupted)
    tooltip.append(colorize(corruptedItemColor, loc("item/corrupted")))
  if (item?.isReplica)
    tooltip.append(colorize(corruptedItemColor, loc("item/replica")))
  if (item?.isCorrupted && item?.createdByZone != null && canResearchBeOpened(item.itemTemplate))
    tooltip.append(colorize(itemQuestTooltipStatColor, loc("item/canGetResearch")))

  if (additionalHints?.hasBulletInBarrel)
    tooltip.append(coloredStatText(loc("Inventory/bullet_in_barrel")))

  if (comps?.valuableItem)
    tooltip.append(coloredText(itemQuestTooltipStatColor, loc("item/valuableItem")))

  if (comps?.key__tags != null)
    tooltip.append(coloredStatText(loc("item/usedFromBackpack")))

  
  if (!comps?.isFlamethrower && (comps?.gun__firingModeNames ?? []).len() > 0) {
    foreach(v in comps.gun__firingModeNames) {
      let mode = loc($"firing_mode/{v}/full")
      if (v == "full_auto") {
        let rpmStr = $"{round_by_value(comps.weapon_stat__rpm, 0.1)}<color={itemTooltipBonusDescColor}>{loc("desc/rpm_units")}</color>"
        statsTooltip.append(coloredStatText(mode))
        statsTooltip.append($"  - {coloredStatText(loc("desc/rpm"), rpmStr)}")
      }
      else if (v in semiAutoBursts) {
        statsTooltip.append(coloredStatText(loc("firing_mode/semi_auto_burst/full")))
        let time = getTimeBetweenShots(comps)
        let idxToEnd = v.indexof("_shot")
        if (idxToEnd != null) {
          let burstCount = v.slice(idxToEnd - 1, idxToEnd)
          let burstDuration = time * burstCount.tointeger()
          let shotsPerTime = $"{burstCount} <color={itemTooltipBonusDescColor}>{loc("desc/shots")}</color> {loc("desc/in")} {burstDuration} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>"
          statsTooltip.append($"  - {coloredStatText(mode, shotsPerTime)}")
        }
        statsTooltip.append($"  - {coloredStatText(loc("desc/timeBetweenBursts"),  $"{time} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>")}")
      }
      else if (v == "semi_auto") {
        statsTooltip.append(coloredStatText(mode))
        let time = getTimeBetweenShots(comps)
        statsTooltip.append($"  - {coloredStatText(loc("desc/timeBetweenShots"), $"{time} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>")}")
      }
      else if ((comps?.gun_boxed_ammo_reload__batchReloadTime ?? 0) > 0) {
        statsTooltip.append(coloredStatText(mode))
        let time = getTimeBetweenShots(comps)
        statsTooltip.append($"  - {coloredStatText(loc("desc/timeBetweenShots"),  $"{time} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>")}")
      }
      else {
        let time = getTimeBetweenShots(comps)
        statsTooltip.append(coloredStatText(mode))
        statsTooltip.append($"  - {coloredStatText(loc("desc/timeBetweenShots"), time)}")
      }
    }
    statsTooltip.append("")
  }

  
  if ((comps?.gun_boxed_ammo_reload__batchReloadTime ?? 0) > 0) {
    let timeString = $"{comps.gun_boxed_ammo_reload__batchReloadTime} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>"
    statsTooltip.append(coloredStatText(loc("desc/reloadTime"), timeString))
  }
  else if ((comps?.gun_boxed_ammo_reload__loadLoopTime ?? 0) > 0 && (comps?.gun__maxAmmo ?? 0) > 0) {
    let prep = comps?.gun_boxed_ammo_reload__loadPrepareTime ?? 0
    let reload = comps.gun_boxed_ammo_reload__loadLoopTime
    let post = comps?.gun_boxed_ammo_reload__loadPostTime ?? 0
    let maxReloadTime = prep + reload * comps.gun__maxAmmo + post
    let timeString = $"{maxReloadTime} <color={itemTooltipBonusDescColor}>{loc("desc/seconds")}</color>"
    statsTooltip.append(coloredStatText(loc("desc/maxReloadTime"), timeString))
  }

  
  if ((comps?.gun__recoilAmount ?? 0.0) >= 0.01)
    statsTooltip.append(coloredStatText(loc("desc/recoil"), round_by_value(comps?.gun__recoilAmount ?? 0.0, 0.01)))

  
  if ((comps?.gun_deviation__maxDeviation ?? 0.0) > 0.0)
    statsTooltip.append(coloredStatText(loc("desc/deviation"), round_by_value(comps?.gun_deviation__maxDeviation ?? 0.0, 0.1)))

  
  if ((comps?.loud_noise__noisePerShot ?? 0.0) > 0.0) {
    let mult = comps?.gun_entity_mods__loudNoisePerShotMult ?? 1.0
    let value = round_by_value((comps?.loud_noise__noisePerShot ?? 0.0) * mult, 0.1)
    local locIdToUse = loc("desc/shotVeryLoud")
    let koef = 1.0 - mult
    let color = koef == 0 ? itemTooltipNameColor
      : koef > 0.0 ? itemTooltipStatValueIncreasedColor
      : itemTooltipStatValueDecreasedColor
    for (local i = 0; i < shootNoiseTbl.len(); i++) {
      if (value <= shootNoiseTbl[i].limit) {
        locIdToUse = shootNoiseTbl[i].locId
        break
      }
    }

    statsTooltip.append(coloredStatText(loc("desc/noise_per_shot"), colorize(color, loc(locIdToUse))))
  }


  
  if (item?.revivePrice) {
    statsTooltip.append(loc("desc/revive"))
    statsTooltip.append(coloredStatText(loc("desc/revive_cost"), $"{item?.revivePrice}{amTextIcon}"))
  }


  
  let healsHP = comps?.item__ampouleHealAmount ?? 0.0
  if (healsHP > 0.0)
    statsTooltip.append(coloredStatText(loc("desc/heals_hp"), round_by_value(healsHP, 0.1)))

  
  if (item?.hp != null) {
    local durabilityStr = ceil(item?.hp).tointeger().tostring()
    if (item?.maxHp != null && (item?.maxHp ?? 0) > 0)
      durabilityStr = "{0}/{1}".subst(durabilityStr, ceil(item.maxHp).tointeger().tostring())
    statsTooltip.append(coloredStatText(loc("desc/durability"), durabilityStr))
  }
  
  else if (item?.charges != null) {
    let statName = (comps?.item_healkit_magazine != null) ? loc("desc/healing_ampoule_ammoCount") :
                   (item?.isAmmo ?? false) ? loc("desc/ammoCount") :
                   (item?.isAmStorage ?? false) ? loc("desc/active_matter") :
                   loc("desc/charges")
    let am2Money = item?.isAmStorage ? $" ({creditsTextIcon}{(item?.charges ?? 1) * playerProfileAMConvertionRate.get()})" : ""
    let amMark = item?.isAmStorage ? amTextIcon : ""
    let isCountKnown = item?.countKnown ?? true

    if (item?.maxCharges != null && (item?.maxCharges ?? 0) > 0) {
      if ((item?.isWeaponMod ?? false) && (item?.attachedTo ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID) {
        let ammo = get_equipped_magazine_current_ammo_count(item)

        let ammoText = isCountKnown ? ammo : "?"
        statsTooltip.append(coloredStatText(statName, $"{ammoText}/{ceil(item?.maxCharges).tointeger()}"))
      }
      else {
        let chargesText = isCountKnown ? $"{ceil(item?.charges).tointeger()}" : "?"
        statsTooltip.append(coloredStatText(statName, $"{chargesText}/{ceil(item?.maxCharges).tointeger()}"))
      }
    }
    else
      statsTooltip.append(coloredStatText(statName, $"{ceil(item?.charges).tointeger()}{amMark}{am2Money}"))

    if (item.canLoadOnlyOnBase)
      statsTooltip.append(loc("desc/item_holder_can_load_only_on_base"))
  }
  
  else if (item?.ammoCount != null) {
    let statName = comps?.item_heal_ampoule != null ? loc("desc/healing_ampoule_ammoCount") :
                   loc("desc/ammoCount")
    let isCountKnown = item?.countKnown ?? true

    let ammoCountText = isCountKnown ? $"{item?.ammoCount}" : "?"

    if (item?.maxAmmoCount != null && (item?.maxAmmoCount ?? 0) > 0)
      statsTooltip.append(coloredStatText(statName, $"{ammoCountText}/{item?.maxAmmoCount}"))
    else
      statsTooltip.append(coloredStatText(statName, ammoCountText))
  }

  
  let extraInventoryMaxVolume = item?.inventoryMaxVolume ?? 0.0
  if (extraInventoryMaxVolume > 0.0)
    statsTooltip.append(coloredStatText(loc("desc/extra_inventory_capacity"), round_by_value(extraInventoryMaxVolume, 0.1)))

  
  if (comps?.gun_mod__effectTemplate) {
    let effectTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(comps?.gun_mod__effectTemplate)
    if (effectTemplate != null) {
      let loudNoisePerShotMult = effectTemplate?.getCompValNullable("gun_mod_effect__loudNoisePerShotMult")
      if (loudNoisePerShotMult != null)
        statsTooltip.append(coloredStatText(loc("desc/loud_noise_per_shot"),
          $"-{round_by_value((1.0 - loudNoisePerShotMult) * 100.0, 0.1)}%"))

      let damageMult = effectTemplate?.getCompValNullable("gun_mod_effect__damageMult")
      if (damageMult != null && damageMult != 1.0) {
        if (damageMult < 1.0)
          statsTooltip.append(coloredStatText(loc("desc/damage"),
            $"-{round_by_value((1.0 - damageMult) * 100.0, 0.1)}%"))
        else
          statsTooltip.append(coloredStatText(loc("desc/damage"),
            $"+{round_by_value((damageMult - 1.0) * 100.0, 0.1)}%"))
      }

      let adsSpeedMult = effectTemplate?.getCompValNullable("gun_mod_effect__adsSpeedMult")
      if (adsSpeedMult != null)
        statsTooltip.append(coloredStatText(loc("desc/ads"),
          $"-{round_by_value((1.0 - adsSpeedMult) * 100.0, 0.1)}%"))
    }
  }

  
  if (comps?.gunmod__slots) {
    local typeLocs = []
    foreach (slot in comps.gunmod__slots) {
      foreach (typeLoc in getGunModSlotTypeLocs(slot ?? "")) {
        if (!typeLocs.contains(typeLoc))
          typeLocs.append(typeLoc)
      }
    }

    let localizedSlots = ",".join(typeLocs.map(@(str) loc(str)))
    if (localizedSlots != "") {
      let weapModSlotName = item?.weapModSlotName ?? ""
      if (weapModSlotName == "scope")
        statsTooltip.append(coloredStatText(loc("desc/scope_slot_type"), localizedSlots))
      else if (weapModSlotName == "silencer")
        statsTooltip.append(coloredStatText(loc("desc/silencer_slot_type"), localizedSlots))
    }
  }

  
  if (comps?.binoculars_item__binocularsAffectTemplate && comps?.questItemTooltip == null) {
    let binocularsAffectTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(comps?.binoculars_item__binocularsAffectTemplate)
    if (binocularsAffectTemplate != null) {
      let zoomMagnification = binocularsAffectTemplate.getCompValNullable("human_cam_magnification_affect__magnification") ?? 0.0
      if (zoomMagnification > 0.0)
        statsTooltip.append(coloredStatText(loc("desc/zoom_magnification"), $"{round_by_value(zoomMagnification, 0.1)}{loc("ui/multiply")}"))
    }
  }

  
  let backupWeapon = []
  if (comps?.equipment__setDefaultStubMeleeTemplate) {

    let defaultStubMeleeTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(comps?.equipment__setDefaultStubMeleeTemplate)
    let defaultStubMeleeLocName = loc(defaultStubMeleeTemplate.getCompValNullable("item__name"))
    backupWeapon.append(coloredStatText(loc("desc/default_stub_weapon"), defaultStubMeleeLocName))
  }

  let armorSlots = []
  
  if (item?.mods) {
    let armors = {}

    foreach (k, v in item.mods) {
      if (k.contains("pocket"))
        continue
      local words = k.split("_")
      words = words.resize(words.len() - 1)
      let part = "_".join(words)
      if (armors?[part] == null)
        armors[part] <- {}

      let armorPlateSlot = v?.allowed_items[0]
      if (armorPlateSlot != null) {
        let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(armorPlateSlot)
        if (template?.getCompValNullable("armorplate_big") != null) {
          let current = (armors[part]?["armorplate_big"] ?? 0) + 1
          armors[part]["armorplate_big"] <- current
        }
        else if (template?.getCompValNullable("armorplate_small") != null) {
          let current = (armors[part]?["armorplate_small"] ?? 0) + 1
          armors[part]["armorplate_small"] <- current
        }
      }
    }

    foreach (partName, armor in armors) {
      let armorLocs = []
      foreach (armorType, armorCount in armor) {
        armorLocs.append($"{loc($"desc/{armorType}")} {armorCount}")
      }

      if (armorLocs.len() > 0) {
        let partLoc = loc($"desc/{partName}")
        armorSlots.append(coloredStatText(partLoc, ",".join(armorLocs)))
      }
    }
  }


  
  let chronogeneTooltips = []
  if (comps?.dm_part_armor__protection != null) {
    local koef = 1.0
    if (item?.hp && (item?.maxHp ?? 0.0) > 0.0)
      koef = lerp(0.0, item.maxHp, item?.protectionMinHpKoef ?? 0.0, 1.0, ceil(item.hp))

    foreach (idx, value in comps.dm_part_armor__protection) {
      if (value != 0.0)
        chronogeneTooltips.append(coloredStatText(loc($"desc/{getDamageTypeStr(idx)}_damage_protection", $"{getDamageTypeStr(idx)} damage protection:"),
          $"{value > 0.0 ? "+" : "-"}{round_by_value(value * koef * 100.0, 0.1)}%"))
    }
  }


  
  let inventoryExtension = item?.inventoryExtension ?? 0.0
  if (inventoryExtension > 0.0) {
    statsTooltip.append(coloredStatText(loc("desc/inventory_extension"),
      $"+{round_by_value(inventoryExtension, 0.1)}"))
  }

  
  
  
  
  
  
  

  
  let painkillerEffect = comps?.item__boostTemplateName ?? ""
  if (painkillerEffect != "") {
    let painkillerEffectTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(painkillerEffect)
    if (painkillerEffectTemplate != null) {
      let timeToDestroy = painkillerEffectTemplate.getCompValNullable("game_effect__timeToDestroy") ?? 0.0
      if (timeToDestroy > 0.0) {
        let value = $"{round_by_value(timeToDestroy, 0.1)} <color={itemTooltipBonusDescColor}>{loc("desc/duration_units_seconds")}</color>"
        statsTooltip.append(coloredStatText(loc("desc/duration"), value))
      }
    }
  }

  
  let chronogeneEffect = comps?.entity_mod_effects.getAll() ?? {}
  foreach (effectKey, effectVal in chronogeneEffect) {
    let effectName = effectKey.split("+")?[0] ?? ""
    let effectCalcType = effectKey.split("+")?[1] ?? ""
    let effectLoc = loc($"clonesMenu/stats/{effectName}")
    let measurement = chronogeneStatCustom?[effectName]?.measurement ?? chronogeneStatDefault.measurement

    let defVal = chronogeneStatCustom?[effectName]?.defVal ?? chronogeneStatDefault.defVal
    let defEffect = chronogeneStatCustom?[effectName]?.calc(defVal) ?? chronogeneStatDefault.calc(defVal)
    let resultVal = chronogeneEffectCalc?[effectCalcType](defVal, effectVal) ?? defVal
    let resultEffect = chronogeneStatCustom?[effectName]?.calc(resultVal) ?? chronogeneStatDefault.calc(resultVal)

    let effectDiff = resultEffect - defEffect
    chronogeneTooltips.append(coloredStatText(effectLoc, $"{effectDiff > 0 ? "+" : ""}{string.format("%.1f", effectDiff)}{measurement}"))
  }


  
  if (comps?.itemContainer != null &&
      comps?.human_inventory__tooltipItems != null &&
      comps.itemContainer.len() > 0) {

    if (statsTooltip.len() > 0)
      statsTooltip.append("")

    statsTooltip.append(coloredStatText(loc("desc/inventory_items_inside"), ""))


    local itemsInContainerPerProto = {}
    foreach (itemEid in comps.itemContainer) {
      let inventoryItemInfo = get_item_info(itemEid)


      let itemData = itemsInContainerPerProto?[inventoryItemInfo.itemTemplate]
      if (itemData != null) {
        itemData.count++
      }
      else {
        local newItemData = {
          name = buildInventoryItemName(inventoryItemInfo)
          count = 1
        }
        itemsInContainerPerProto[inventoryItemInfo.itemTemplate] <- newItemData
      }
    }

    foreach (itemInContainerDataValue in itemsInContainerPerProto) {
      local itemName = $" · {itemInContainerDataValue.name}"
      if (itemInContainerDataValue.count > 1)
        itemName = $"{itemName} ({loc("ui/multiply")}{itemInContainerDataValue.count})"
      statsTooltip.append(itemName)
    }

  }


  
  if (comps?.dogtag_item != null) {
    get_dogtag_info_query.perform(item?.eid, function(_eid, querycomp) {
      if (querycomp.cortical_vault_inactive__killerNickname != "")
        statsTooltip.append(coloredStatText(loc("desc/killerNickname"), $"{querycomp.cortical_vault_inactive__killerNickname}"))
      let damageTypeStr = querycomp.cortical_vault_inactive__deathReason

      
      if (damageTypeStr == "")
        return

      local dogtagDescr = item?.itemDescription

      
      if (damageTypeStr == "0" || damageTypeStr == "1" || damageTypeStr == "2" || damageTypeStr == "8" ||
          (damageTypeStr == "6" && querycomp.cortical_vault_inactive__killerNickname != "")) {
        dogtagDescr = loc($"{dogtagDescr}/weapon", {weaponName = loc(querycomp.cortical_vault_inactive__killedByWeapon)})
        statsTooltip.append(coloredStatText(loc("desc/dogtagWeapon"), $"{dogtagDescr}"))
      }
      
      else if (damageTypeStr == "6") {
        dogtagDescr = loc($"{dogtagDescr}/neutralFire")
        statsTooltip.append(coloredStatText(loc("desc/dogtagDeathReason"), $"{dogtagDescr}"))
      }
      
      else {
        dogtagDescr = loc($"{dogtagDescr}/{damageTypeStr}")
        statsTooltip.append(coloredStatText(loc("desc/dogtagDeathReason"), $"{dogtagDescr}"))
      }
    })
  }

  
  local descriptionTooltip = []

  let descLoc = item?.itemDescription ?? comps?.itemDescription
  let desc = descLoc == null ? loc("{0}/desc".subst(item?.itemName ?? ""), "") : loc(descLoc, "")
  if (desc != "")
    descriptionTooltip.append(coloredText(itemTooltipDescColor, desc))

  
  local physParamsTooltip = []
  local volume = item?.isBoxedItem ? calc_stacked_item_volume(item.countPerStack, item?.ammoCount, item.volumePerStack) / 10.
    : item?.volume ?? 0
  let weight = comps?.item__weight ?? item?.weight ?? 0.0

  if (weight > 0.0) {
    let weightRounded = truncateToMultiple(weight, 0.01)
    let weightText = itemsCount > 1 ? $"{weight * itemsCount} ({weightRounded} {loc("ui/multiply")} {itemsCount})" : $"{weightRounded}"
    physParamsTooltip.append(coloredText(itemTooltipStatColor, loc("desc/weight"), weightText))
  }
  if (volume > 0.0) {
    let volumeRounded = truncateToMultiple(volume, 0.01)
    let volumeText = itemsCount > 1 && !item?.isBoxedItem ? $"{volume * itemsCount} ({volume} {loc("ui/multiply")} {itemsCount})"
      : $"{volumeRounded}"
    physParamsTooltip.append(coloredText(itemTooltipStatColor, loc("desc/volume"), volumeText))
  }

  let additionalDesc = item?.additionalDesc ?? []

  let tooltipStrings = "\n\n".join([
    "\n".join(tooltip),
    "\n".join(additionalDesc),
    "\n".join(statsTooltip),
    "\n".join(chronogeneTooltips),
    "\n".join(descriptionTooltip),
    "\n".join(physParamsTooltip),
    "\n".join(armorSlots),
    "\n".join(backupWeapon)
  ], @(v) v.len() > 0)

  return tooltipBox({
    key = tooltip
    children = [
      item?.isCorrupted ? corruptedItemBackground : null
      {
        flow = FLOW_VERTICAL
        gap = tooltipSeparator
        children = [
          {
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            maxWidth = hdpxi(500)
            color = Color(180, 180, 180, 120)
            text = tooltipStrings
            margin = fsh(1)
            tagsTable = {
              header = {
                fontSize = body_txt.fontSize
              }
            }
          }
          tooltipHotkeyHints
        ]
      }
    ]
  }, { padding = 0})
}

return {
  buildInventoryItemTooltip
}
