from "%sqstd/math.nut" import round_by_value

from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import body_txt
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/state/human_damage_model_state.nut" import getDamageTypeStr
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByColor, getRarityColor
from "%ui/components/colors.nut" import RarityCommon, BtnBgHover, BtnBdHover, ItemBdColor, BtnBgTransparent
from "das.ribbons_color" import get_primary_color_of_hero, get_secondary_color_of_hero
from "%ui/hud/menus/components/inventoryItem.nut" import itemFillColorHovered, itemFillColorDef
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "das.inventory" import mod_effect_calc
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import fakeItemAsAttaches
from "%ui/hud/menus/components/damageModel.nut" import mkIconAttachments
import "%ui/components/icon3d.nut" as mkIcon3d
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/components/chocolateWnd.nut" import openChocolateWnd
from "%ui/components/msgbox.nut" import showMessageWithContent, showMsgbox
from "%ui/hud/menus/components/inventoryItemUtils.nut" import actionForbiddenDueToQueueState

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "string" as string

let { allItems } = require("%ui/state/allItems.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { chronogeneStatCustom, chronogeneStatDefault } = require("%ui/hud/state/item_info.nut")
let { rarityColorTable } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { inventoryImageParams, inventoryItemImage } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { equipTagChoronogeneItem } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")

let clonesMenuScreenPadding = static [hdpx(90), hdpx(50), hdpx(50), hdpx(50)]
let backTrackingMenu = Watched(null)
let findItemInAllItems = @(idx) allItems.get().findvalue(@(v) v?.itemId.tostring() == idx?.tostring())

const AlterSelectionSubMenuId = "AlterSelection"
const ClonesMenuId = "CloneBody"

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

function mkChronogeneImage(chronogene, imageParams=inventoryImageParams, rarityOverride = {}) {
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
      mkRarityIconByColor(getRarityColor(itemRarity), rarityOverride)
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

function mkChronogeneSlot(chronogene, imageParams=inventoryImageParams, onClick=null, isPassive = false) {
  let itemTemplate = chronogene?.itemTemplate ?? chronogene?.templateName

  let {
    slotTooltip = null
  } = chronogene

  let stateFlags = Watched(0)
  let isHovered = Computed(@() onClick != null && (stateFlags.get() & S_HOVER))
  return @() {
    watch = isInBattleState
    size = imageParams.slotSize
    behavior = Behaviors.Button
    onElemState = @(sf) stateFlags.set(sf)
    skipDirPadNav = isInBattleState.get()
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
        watch = isHovered
        rendObj = ROBJ_BOX
        size = flex()
        color = isHovered.get() ? itemFillColorHovered : itemFillColorDef
        borderRadius = isPassive ? imageParams.slotSize[0] : 0
        fillColor = isHovered.get() ? BtnBgHover : BtnBgTransparent
        borderColor = isHovered.get()? BtnBdHover : ItemBdColor
        borderWidth = hdpx(1)
      }
      mkChronogeneImage(chronogene, imageParams)
    ]
  }
}

let mkPassiveChronogeneSlot = @(chronogene, imageParams=inventoryImageParams)
  mkChronogeneSlot(chronogene, imageParams, null, true)

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

let mkChronogeneDoll = function(dollTemplateName, doll_size, presentationParams={}) {
  let template = dollTemplateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(dollTemplateName) : null
  let doll_animchar = template?.getCompValNullable("animchar__res")
  let bodyTypeId = template?.getCompValNullable("suit__suitType") ?? 0
  let iconAttachments = template ? mkIconAttachments(fakeItemAsAttaches(dollTemplateName, bodyTypeId, null)) : null

  let animchar = doll_animchar ?? (bodyTypeId == 0 ? "am_trooper_empty_model_male_char" : "am_trooper_empty_model_female_char")

  return mkIcon3d({
    iconAttachments = iconAttachments?()
    iconName=animchar
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
}

let mkChronogeneParamString = @(key, value, tooltip = null, color=null) {
  rendObj = ROBJ_BOX
  borderColor = Color(70, 70, 70)
  borderWidth = static [0,0,hdpx(1),0]

  flow = FLOW_HORIZONTAL
  size = FLEX_H
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
      size = FLEX_H
    }
    mkText(value, color ? { color } : {})
  ]
}

function mkMainChronogeneInfoStrings(chronogene, override = {}, isSmallVersion = false) {
  if (!chronogene)
    return null

  
  let chronogeneName = mkText(loc(chronogene?.itemName), body_txt)
  if (chronogeneName == null)
    return null

  
  let armors = {}
  foreach (k, v in chronogene?.mods ?? []) {
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
      armorLocs.append($"{loc($"desc/{armorType}")} {loc("ui/multiply")}{armorCount}")
    }

    if (armorLocs.len() > 0) {
      let partLoc = loc($"desc/{partName}")
      armorSlots.append(mkChronogeneParamString(partLoc, ", ".join(armorLocs)))
    }
  }

  let geneTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(chronogene.itemTemplate)

  
  let properties = []
  let protections = geneTemplate.getCompValNullable("dm_part_armor__protection")
  if (protections != null) {
    foreach (idx, value in protections) {
      if (value != 0.0)
        properties.append(mkChronogeneParamString(loc($"desc/{getDamageTypeStr(idx)}_damage_protection"), $"{value > 0.0 ? "+" : "-"}{round_by_value(value * 100.0, 0.1)}%"))
    }
  }
  let chronogeneEffect = geneTemplate?.getCompValNullable("entity_mod_effects")
  if (chronogeneEffect) {
    let entity_mods = ecs.CompObject()
    let entity_mod_values = ecs.CompObject()

    let baseEntityTmpl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("base_entity_mods")
    let templateEntityModValues = baseEntityTmpl.getCompValNullable("entity_mod_values")

    foreach (k, v in templateEntityModValues) {
      entity_mod_values[k] <- v
    }

    mod_effect_calc(entity_mods, entity_mod_values, [ chronogene.itemTemplate ])

    foreach(k, v in entity_mod_values.getAll()) {
      if (v.value == v.defaultValue)
        continue

      let measurement = chronogeneStatCustom?[k]?.measurement ?? chronogeneStatDefault.measurement
      let effectLoc = loc($"clonesMenu/stats/{k}")
      let curVal = chronogeneStatCustom?[k]?.calc(v.value) ?? chronogeneStatDefault.calc(v.value)
      let defVal = chronogeneStatCustom?[k]?.calc(v.defaultValue) ?? chronogeneStatDefault.calc(v.defaultValue)
      let result = curVal - defVal

      properties.append(mkChronogeneParamString(effectLoc, $"{result > 0 ? "+" : ""}{string.format("%.1f", result)}{measurement}"))
    }
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
        size = FLEX_H
        flow = FLOW_VERTICAL
        children = armorSlots
      }
      
      isSmallVersion ? null : {
        size = FLEX_H
        flow = FLOW_VERTICAL
        children = properties
      }
    ]
  }.__update(override)
}

let item_comps = [
  ["entity_mods", ecs.TYPE_OBJECT],
  ["entity_mod_values", ecs.TYPE_OBJECT]
]

let getCurrentHeroEffectModsQuery = ecs.SqQuery("get_current_hero_effect_mod_query", {
  comps_ro = item_comps
  comps_rq = [["watchedByPlr"]]
})


function getEffectsTable(_eid, comp) {
  return {
    entity_mods = comp.entity_mods
    entity_mod_values = comp.entity_mod_values
  }
}



function getCurrentHeroEffectMod(additionalEffectsTemplates) {
  let currentEffects = getCurrentHeroEffectModsQuery(watchedHeroEid.get(), getEffectsTable)

  if (currentEffects?.entity_mods == null || currentEffects?.entity_mod_values == null) {
    return {
      entity_mods = {}
      entity_mod_values = {}
    }
  }

  let entity_mods = ecs.CompObject()
  let entity_mod_values = ecs.CompObject()
  foreach (k, v in currentEffects.entity_mods.getAll()) {
    entity_mods[k] <- v
  }
  foreach (k, v in currentEffects.entity_mod_values.getAll()) {
    entity_mod_values[k] <- v
  }

  mod_effect_calc(entity_mods, entity_mod_values, additionalEffectsTemplates)
  return {
    entity_mods = entity_mods.getAll()
    entity_mod_values = entity_mod_values.getAll()
  }
}


function tagChronogeneSlot() {
  let stateFlags = Watched(0)
  let isHovered = Computed(@() stateFlags.get() & S_HOVER)

  let getFittingItems = @() stashItems.get().filter(@(v) v.filterType == "dogtag_chronogene")
  let defaultItemTemplate = "dogtag_chronogene"
  let defaultItem = mkFakeItem(defaultItemTemplate)

  return {
    watch = [ isInBattleState, equipment]
    size = inventoryImageParams.slotSize
    behavior = Behaviors.Button
    onElemState = @(sf) stateFlags.set(sf)
    skipDirPadNav = isInBattleState.get()
    onHover = function(on) {
      if (on) {
        let curItem = equipment.get()?.chronogene_dogtag_1.uniqueId == 0 ? defaultItem : equipment.get()?.chronogene_dogtag_1
        let fake = mkFakeItem(curItem?.itemTemplate ?? "")
        let tooltip = buildInventoryItemTooltip(fake)
        setTooltip(tooltip)
      }
      else
        setTooltip(null)
    }
    onClick = function(event) {
      if (actionForbiddenDueToQueueState(equipment.get()?.chronogene_dogtag_1.uniqueId == 0 ? defaultItem : equipment.get()?.chronogene_dogtag_1)) {
        showMsgbox({ text = loc("playerPreset/cantChangePresetRightNow") })
        return
      }

      openChocolateWnd({
        event,
        itemsDataArr = getFittingItems(),
        onClick = function(item, _actions) {
          let equipItem = item?.itemTemplate == defaultItemTemplate || item?.itemTemplate == null ?
            null : item
          equipTagChoronogeneItem(equipItem)
        },
        itemInSlot = equipment.get()?.chronogene_dogtag_1.uniqueId == 0 ? defaultItem : equipment.get()?.chronogene_dogtag_1,
        defaultItem = defaultItem
        forceOnClick = true
      })
    }
    children = [
      @() {
        watch = isHovered
        rendObj = ROBJ_BOX
        size = flex()
        color = isHovered.get() ? itemFillColorHovered : itemFillColorDef

        fillColor = isHovered.get() ? BtnBgHover : BtnBgTransparent
        borderColor = isHovered.get()? BtnBdHover : ItemBdColor
        borderWidth = hdpx(1)
      }
      inventoryItemImage(equipment.get()?.chronogene_dogtag_1.uniqueId == 0 ? defaultItem : equipment.get()?.chronogene_dogtag_1)
    ]
  }
}

function mkAlterIconParams(templateName, tpl = null) {
  let template = tpl ?? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (template == null)
    return { attachments = {}, alterIconParams = {}}
  let attachments = template.getCompValNullable("suit_attachable_item__animcharTemplates")?.getAll() ?? {}
  let visualPatch = getChronogenePreviewPresentation(templateName)
  let doll_animchar = template?.getCompValNullable("animchar__res")
  let bodyTypeId = template?.getCompValNullable("suit__suitType") ?? 0
  let iconAttachments = mkIconAttachments(fakeItemAsAttaches(templateName, bodyTypeId, null))()
  let animchar = doll_animchar ?? (bodyTypeId == 0 ? "am_trooper_empty_model_male_char" : "am_trooper_empty_model_female_char")
  let alterIconParams = { iconAttachments, iconName = animchar }.__merge(visualPatch)
  return { attachments, alterIconParams }
}

return freeze({
  ClonesMenuId
  AlterSelectionSubMenuId

  clonesMenuScreenPadding
  findItemInAllItems
  getChronogeneItemByUniqueId
  mkMainChronogeneInfoStrings
  mkChronogeneParamString
  mkChronogeneDoll
  tagChronogeneSlot
  getChronogenePreviewPresentation
  getChronogeneFullBodyPresentation
  mkChronogeneSlot
  mkPassiveChronogeneSlot
  mkChronogeneImage
  getChronogeneTooltip
  backTrackingMenu
  getCurrentHeroEffectMod
  getCurrentHeroEffectModsQuery
  mkAlterIconParams
})
