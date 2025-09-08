from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "string" as string

let { allItems } = require("%ui/state/allItems.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { getDamageTypeStr } = require("%ui/hud/state/human_damage_model_state.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { chronogeneStatCustom, chronogeneStatDefault, chronogeneEffectCalc } = require("%ui/hud/state/item_info.nut")
let { rarityColorTable, mkRarityIconByColor, getRarityColor } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { RarityCommon, BtnBgHover, BtnBdHover, ItemBdColor, BtnBgTransparent } = require("%ui/components/colors.nut")
let { get_primary_color_of_hero, get_secondary_color_of_hero } = require("das.ribbons_color")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { itemFillColorHovered, itemFillColorDef } = require("%ui/hud/menus/components/inventoryItem.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let mkIcon3d = require("%ui/components/icon3d.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")

let clonesMenuScreenPadding = [hdpx(90), hdpx(50), hdpx(50), hdpx(50)]
let backTrackingMenu = Watched(null)
let findItemInAllItems = @(idx) allItems.get().findvalue(@(v) v?.itemId.tostring() == idx?.tostring())

let chronogeneEffecTypeToColor = {
  "alter" : Color(220, 220, 220, 220)
  "combat" : Color(228, 72, 68)
  "default" : Color(180, 180, 180, 180)
  "strength" : Color(201, 101, 83, 220)
  "agility" : Color(222, 209, 95, 220)
  "vitality" : Color(103, 192, 80, 220)
  "perception" : Color(107, 174, 210, 220)
  "active_matter" : Color(171, 107, 205, 220)
}

function mkChronogeneImage(chronogene, imageParams=inventoryImageParams) {
  let itemTemplate = chronogene?.itemTemplate ?? chronogene?.templateName
  let template = itemTemplate ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate) : null
  let {
    itemRarity = template?.getCompValNullable("item__rarity") ?? "common"
    chronogeneEffectIcon = template?.getCompValNullable("chronogene__effect_icon")
    chronogeneEffectType = template?.getCompValNullable("chronogene__effect_type")
    defaultIcon = null
  } = chronogene
  let icon = chronogeneEffectIcon ?? $"!ui/{defaultIcon}"

  return {
    size = imageParams.slotSize
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = [ imageParams.width, imageParams.height ]
        keepAspect = true
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        color = chronogeneEffecTypeToColor?[chronogeneEffectType] ?? chronogeneEffecTypeToColor["default"]
        image = Picture($"{icon}:{imageParams.width}:{imageParams.height}:K")
      }
      mkRarityIconByColor(getRarityColor(itemRarity))
    ]
  }
}

function getChronogeneTooltip(chronogene) {
  let itemTemplate = chronogene?.itemTemplate
  if (itemTemplate) {
    let fake = mkFakeItem(itemTemplate, chronogene)
    return buildInventoryItemTooltip(fake)
  }

  let { slotTooltip = null } = chronogene
  return loc(slotTooltip)
}

function mkChronogeneSlot(chronogene, imageParams=inventoryImageParams, onClick=null) {
  let itemTemplate = chronogene?.itemTemplate ?? chronogene?.templateName

  let {
    slotTooltip = null
  } = chronogene

  let getFillColor = @(sf) (sf & S_HOVER) ? BtnBgHover : BtnBgTransparent

  let stateFlags = Watched(0)
  return {
    behavior = Behaviors.Button
    size = imageParams.slotSize
    onElemState = @(sf) stateFlags.set(sf)
    onHover = function(on) {
      if (on) {
        local tooltip = null
        if (itemTemplate) {
          let fake = mkFakeItem(itemTemplate, chronogene)
          tooltip = buildInventoryItemTooltip(fake)
        }
        else {
          tooltip = loc(slotTooltip)
        }
        setTooltip(tooltip)
      }
      else
        setTooltip(null)
    }
    onClick
    children = [
      @() {
        watch = stateFlags
        rendObj = ROBJ_BOX
        size = flex()
        color = stateFlags.get() & S_HOVER ? itemFillColorHovered : itemFillColorDef

        fillColor = getFillColor(stateFlags.get())
        borderColor = (stateFlags.get() & S_HOVER) ? BtnBdHover : ItemBdColor
        borderWidth = hdpx(1)
      }
      mkChronogeneImage(chronogene, imageParams)
    ]
  }
}

function getChronogeneItemByUniqueId(id) {
  return stashItems.get().findvalue(function(v){
      return v.uniqueId == id
    }) ??
    equipment.get().values().findvalue(function(v) {
      return v?.uniqueId == id
    })
}

function getPresentation(presentationTemplateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(presentationTemplateName)
  if (template == null)
    return {}
  let sunColor = template?.getCompValNullable("sunColor")

  let convertColor = function(e3dcolor) {
    let colorValid =
      e3dcolor?.r != null &&
      e3dcolor?.g != null &&
      e3dcolor?.b != null &&
      e3dcolor?.a != null

    return colorValid ? $"{e3dcolor.r},{e3dcolor.g},{e3dcolor.b},{e3dcolor.a}" : "255,255,255,255"
  }

  let lights = template?.getCompValNullable("lights")?.getAll() ?? []
  lights.each(function(light) {
    if (light?.color != null) {
      light.color = convertColor(light.color)
    }
  })

  return {
    enviExposure = template?.getCompValNullable("enviExposure")
    iconYaw = template?.getCompValNullable("iconYaw")
    iconPitch = template?.getCompValNullable("iconPitch")
    iconRoll = template?.getCompValNullable("iconRoll")
    iconOffsX = template?.getCompValNullable("iconOffsX")
    iconOffsY = template?.getCompValNullable("iconOffsY")
    iconScale = template?.getCompValNullable("iconScale")
    sunColor = convertColor(sunColor)
    lightZenith = template?.getCompValNullable("lightZenith")
    lightAzimuth = template?.getCompValNullable("lightAzimuth")
    animation = template?.getCompValNullable("animation")
    animationParams = {
      presentation_idle_type = template?.getCompValNullable("presentation_idle_type")
      presentation_idle_frame = template?.getCompValNullable("presentation_idle_frame")
    }
    lights
  }
}


function getChronogenePreviewPresentation(chronogeneTemplateName) {
  if (!chronogeneTemplateName)
    return {}
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(chronogeneTemplateName)
  let presentation = template?.getCompValNullable("preview_presentation_params")
  if (presentation != null) {
    return getPresentation(presentation).__merge({ atlasName="ui/hero#" })
  }
  return {}
}

function getChronogeneFullBodyPresentation(chronogeneTemplateName) {
  if (!chronogeneTemplateName)
    return {}
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(chronogeneTemplateName)
  let presentation = template?.getCompValNullable("full_body_presentation_params")
  if (presentation != null) {
    return getPresentation(presentation)
  }
  return {}
}

let mkChronogeneDoll = @(doll_animchar, doll_size, presentationParams={}) mkIcon3d({
    iconName=doll_animchar
    atlasName="ui/hero#"
    animation="presentation_idle"
    lightZenith=100
    lightAzimuth=90
    sunColor="255,210,180,255"
    shaderColors={
      primary_color = get_primary_color_of_hero(watchedHeroEid.get())
      secondary_color = get_secondary_color_of_hero(watchedHeroEid.get())
    }
  }.__update(presentationParams), {
    width=doll_size[0]
    height=doll_size[1]
    shading = "full"
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
  })

let mkChronogeneParamString = @(key, value, tooltip = null, color=null) {
  rendObj = ROBJ_BOX
  borderColor = Color(70, 70, 70)
  borderWidth = const [0,0,hdpx(1),0]

  flow = FLOW_HORIZONTAL
  size = [ flex(), SIZE_TO_CONTENT ]
  behavior = Behaviors.Button
  skipDirPadNav = true
  onHover = @(on) setTooltip(on && tooltip ?
    tooltipBox({
      padding = hdpx(7)
      children = {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        maxWidth = hdpx(200)
        text = tooltip
      }
    }) : null
  )
  children = [
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = key
      size = [ flex(), SIZE_TO_CONTENT ]
    }
    mkText(value, color ? { color } : {})
  ]
}

function mkMainChronogeneInfoStrings(chronogene, override = {}, isSmallVersion = false) {
  if (!chronogene)
    return null
  
  let chronogeneName = mkText(loc(chronogene.itemName), body_txt)

  
  let armors = {}
  foreach (k, v in chronogene.mods) {
    if (k.contains("pocket"))
      continue
    let words = k.split("_")
    words.resize(words.len() - 1)
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

  let armorSlots = []
  foreach (partName, armor in armors) {
    let armorLocs = []
    foreach (armorType, armorCount in armor) {
      armorLocs.append($"{loc($"desc/{armorType}")} {armorCount}")
    }

    if (armorLocs.len() > 0) {
      let partLoc = loc($"desc/{partName}")
      armorSlots.append(mkChronogeneParamString(partLoc, ",".join(armorLocs)))
    }
  }

  let geneTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(chronogene.itemTemplate)

  
  let defaultWeaponTemplateName = geneTemplate.getCompValNullable("equipment__setDefaultStubMeleeTemplate")
  let defaultStubMeleeTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(defaultWeaponTemplateName)
  let defaultStubMeleeLocName = loc(defaultStubMeleeTemplate.getCompValNullable("item__name"))
  let backupWeapon = mkChronogeneParamString(loc("desc/default_stub_weapon"), defaultStubMeleeLocName)

  
  let properties = []
  let protections = geneTemplate.getCompValNullable("dm_part_armor__protection")
  if (protections != null) {
    foreach (idx, value in protections) {
      if (value != 0.0)
        properties.append(mkChronogeneParamString(loc($"desc/{getDamageTypeStr(idx)}_damage_protection"), $"{value > 0.0 ? "+" : "-"}{round_by_value(value * 100.0, 0.1)}%"))
    }
  }
  let chronogeneEffect = geneTemplate?.getCompValNullable("entity_mod_effects") ?? {}
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
    properties.append(mkChronogeneParamString(effectLoc, $"{effectDiff > 0 ? "+" : ""}{string.format("%.1f", effectDiff)}{measurement}"))
  }

  let itemRarity = geneTemplate?.getCompValNullable("item__rarity")
  let rarityTextColor = rarityColorTable?[itemRarity] ?? RarityCommon
  let rarityText = mkText(loc($"item/rarity/{itemRarity}"), { color = rarityTextColor})

  return {
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    size = flex()
    margin = hdpx(10)
    children = [
      chronogeneName
      rarityText
      
      isSmallVersion ? null : {
        size = [ flex(), SIZE_TO_CONTENT ]
        flow = FLOW_VERTICAL
        children = armorSlots
      }
      
      isSmallVersion ? null : {
        size = [ flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        children = properties
      }
      isSmallVersion ? null : backupWeapon
    ]
  }.__update(override)
}


return {
  clonesMenuScreenPadding
  findItemInAllItems
  getChronogeneItemByUniqueId
  mkMainChronogeneInfoStrings
  mkChronogeneParamString
  mkChronogeneDoll
  getChronogenePreviewPresentation
  getChronogeneFullBodyPresentation
  mkChronogeneSlot
  mkChronogeneImage
  getChronogeneTooltip
  backTrackingMenu
}