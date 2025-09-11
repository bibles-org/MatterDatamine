from "%sqGlob/dasenums.nut" import EquipmentSlotFlags

from "%sqstd/math.nut" import lerp

import "math" as math
from "%ui/fonts_style.nut" import tiny_txt
import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "dasevents" import CmdHideUiMenu, CmdShowUiMenu, TryUseItem, CmdShowHealingDoll
import "%ui/components/icon3d.nut" as mkIcon3d
from "das.ribbons_color" import get_primary_color_of_hero, get_secondary_color_of_hero, get_color_idx_of_hero
from "%ui/hud/menus/components/inventorySuit.nut" import mkSuitPartModsPanel, mkSuitSlots, mkEquipmentSlot
from "%ui/hud/menus/components/damageModelTooltip.nut" import buildDamageModelPartTooltip
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/state/interactive_state.nut" import removeInteractiveElement, addInteractiveElement
from "das.healing" import verify_healing_attempt_bind, show_healing_tip_bind, set_wish_part_to_heal_bind, get_most_needed_heal_item_bind
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import fakeEquipmentAsAttaches
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "string" import startswith
from "%ui/hud/menus/inventoryActions.nut" import fastEquipItem
from "%ui/hud/menus/components/inventoryItemUtils.nut" import isFastEquipItemPossible
from "%ui/components/colors.nut" import TextHighlight, TextActive
from "%ui/hud/state/item_info.nut" import getSlotAvailableMods

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { draggedData } = require("%ui/hud/state/inventory_state.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { bodyParts, bodyPartsIsDamaged, currentPosName } = require("%ui/hud/state/human_damage_model_state.nut")
let { watchedHeroAnimcharEid, watchedHeroMainAnimcharRes, watchedHeroEid, watchedHeroSex } = require("%ui/hud/state/watched_hero.nut")
let { equipmentModSlots, equipment, attachedEquipment } = require("%ui/hud/state/equipment.nut")
let { previewPreset, previewPresetOverrideRibbons, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { ribbonsChanged } = require("%ui/mainMenu/ribbons_colors_state.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { ON_BODY_SLOT } = require("%ui/hud/menus/components/slotTypes.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { isPreparationOpened, isNexusPreparationOpened } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { isInMonsterState, isMonsterInventoryEnabled } = require("%ui/hud/state/hero_monster_state.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")

#allow-auto-freeze

const HealingDollId = "HealingDoll"
local healingDollItemEid = Watched(ecs.INVALID_ENTITY_ID)

let isHealing = Watched(false)
let healingPart = Watched(null)

let closeHealingDoll = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = HealingDollId}))
let openHealingDoll = @() ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = HealingDollId}))

let onAttachHealingDoll = @() (bodyPartsIsDamaged.get() ? addInteractiveElement : removeInteractiveElement)(HealingDollId)
let onDetachHealingDoll = function(){
  removeInteractiveElement(HealingDollId)
  healingDollItemEid.set(ecs.INVALID_ENTITY_ID)
}

let injuredPartColor = Color(0, 0, 0, 200)
let slotHeaderBg = Color(0, 0, 0, 51)

let atlasSize = 1023.0
let miniDollSize = [ 64.0, 128.0 ]
let headerHeight = hdpx(19)

function getDollSize(wishHeight) {
  return  [min(atlasSize, wishHeight * 0.65).tointeger(), min(atlasSize, wishHeight).tointeger()]
}

enum hpElementHintLine {
  NONE,
  LEFT,
  RIGHT
}

let limbsDoll = [
  ["left_hand",   [0.0,  0.51], hpElementHintLine.LEFT, 0.30],
  ["right_hand",  [0.0,  0.51], hpElementHintLine.RIGHT, 0.33],
  ["left_leg",    [0.0,  0.67], hpElementHintLine.LEFT, 0.39],
  ["right_leg",   [0.0,  0.67], hpElementHintLine.RIGHT, 0.43]
]
let headDoll = ["head", [0.0, 0.11], hpElementHintLine.LEFT, 0.47]
let bodyDoll = ["body", [0.0, 0.27], hpElementHintLine.RIGHT, 0.54]
let flashlightDoll = [ "", [ 0.0, 0.11 ], hpElementHintLine.RIGHT, 0.0]
let backpackAndPouchesDoll = [ "", [ 0.0, 0.27 ], hpElementHintLine.LEFT, 0.0]

let allDummyNodes = [
  "body", "body_skeleton",
  "head", "head_skeleton",
  "l_hand", "l_hand_skeleton",
  "r_hand", "r_hand_skeleton",
  "l_leg", "l_leg_skeleton",
  "r_leg", "r_leg_skeleton"
]

let dummyNodeNames = {
  ["head"]       = { zpos = 2, hide = allDummyNodes.filter(@(v) v != "head") },
  ["left_hand"]  = { zpos = 2, hide = allDummyNodes.filter(@(v) v != "l_hand") },
  ["right_hand"] = { zpos = 0, hide = allDummyNodes.filter(@(v) v != "r_hand") },
  ["body"]       = { zpos = 1, hide = allDummyNodes.filter(@(v) v != "body") },
  ["left_leg"]   = { zpos = 2, hide = allDummyNodes.filter(@(v) v != "l_leg") },
  ["right_leg"]  = { zpos = 2, hide = allDummyNodes.filter(@(v) v != "r_leg") }
}

let miniBodypartPanelOffset = {
    ["pose_stand"] = [ 5, -5],
    ["pose_crouch"] = [ 5, -20],
    ["pose_crawl"] = [ 5, -45]
}

let mkIconAttachments = @(equipmentAttach, overrideRibbonsColors = {}) function() {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("ribbon_colors")
  let countOfSimpleColors = template?.getCompValNullable("ribbon_colors__colors").getAll().len() ?? 0
  let patterns = template?.getCompValNullable("ribbon_colors__patterns").getAll() ?? {}
  let textureIdx = get_color_idx_of_hero(watchedHeroEid.get()).x - countOfSimpleColors

  return equipmentAttach.map(function(v) {
    let objReplace = v?.objTexReplace ?? {}

    local needRibbonColors = true
    if (patterns?[textureIdx] != null) {
      objReplace["iff_tape_band_a_tex_d*"] <-  $"{patterns?[textureIdx]}*"
      needRibbonColors = false
    }

    return {
      shading = "same"
      active = true
      attachType = v.slotName ? "slot" : "skeleton"
      animchar = v.animchar
      slot = v.slotName ?? ""
      parentNode = "root"
      hideNodes = v?.hideNodes ?? []
      objTexReplace = objReplace
      shaderColors={
        primary_color= needRibbonColors ?
          (overrideRibbonsColors?.primaryColor ?? get_primary_color_of_hero(watchedHeroEid.get()))
          : [ 1.0, 1.0, 1.0, 1.0 ]
        secondary_color= needRibbonColors ?
          (overrideRibbonsColors?.secondaryColor ?? get_secondary_color_of_hero(watchedHeroEid.get()))
          : [ 1.0, 1.0, 1.0, 1.0 ]
      }
    }
  })
}

let mkHeroDoll = @(doll_animchar, attachments, doll_size, params=null, overrideRibbons=null, overrideIconParams=null) @() {
  watch = ribbonsChanged
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children =
    mkIcon3d({
      iconName=doll_animchar
      iconAttachments=attachments?()
      atlasName="ui/hero#"
      animation="presentation_idle"
      enviPanoramaTex = "daylight_clouds_panorama_tex_d"
      enviExposure = 0.1
      lights = [
        {
          color = "50,50,80,255"
          brightness = 2.079
          zenith = 45
          azimuth = -230
        }
        {
          color = "255,255,255,255"
          brightness = 0.198
          zenith = 145
          azimuth = -10
        }
        {
          color = "220,220,220,255"
          brightness = 1.0395
          zenith = 45
          azimuth = -55
        }
        {
          color = "22,55,66,255"
          brightness = 0.198
          zenith = 25
          azimuth = -60
        }
        {
          color = "220,220,220,255"
          brightness = 1.32
          zenith = 78
          azimuth = -60
        }
      ]

      shaderColors={
        primary_color = overrideRibbons?.primaryColor ?? get_primary_color_of_hero(watchedHeroEid.get())
        secondary_color = overrideRibbons?.secondaryColor ?? get_secondary_color_of_hero(watchedHeroEid.get())
      }
    }.__update(overrideIconParams ?? static {}),{
      width=doll_size[0]
      height=doll_size[1]
      shading = "full"
    }.__merge(params ?? static {}))
  }

let mkHintDoll = @(iconName, doll_size, pose, override = {color = Color(192,192,192,200)}, hide = null)
  mkIcon3d({
    iconName
    atlasName = "ui/hero#"
    animation = pose
    hideNodes = hide
    iconScale = 0.9
  },{
    width = doll_size[0]
    height = doll_size[1]
    shading = "silhouette"
    silhouette = [255, 255, 255, 255]
    animations = null
  }.__merge(override))

function mkBodypartBlock(bodypart, bodySize, labelContent, equipmentContent = null) {
  let labelContentY = calc_comp_size(labelContent)[1] - hdpx(2)
  let mkContent = @() {
    halign = bodypart[2] == hpElementHintLine.LEFT ? ALIGN_RIGHT : ALIGN_LEFT
    flow = FLOW_VERTICAL
    pos = [ 0, -labelContentY ]
    children = [
      labelContent
      @() {
        watch = [isInMonsterState, isMonsterInventoryEnabled]
        children = (isInMonsterState.get() && !isMonsterInventoryEnabled.get()) ? null : equipmentContent
      }
    ]
  }

  let position = [ bodySize[0] * bodypart[1][0], bodySize[1] * bodypart[1][1]]

  return {
    hplace = bodypart[2] == hpElementHintLine.LEFT ? ALIGN_RIGHT : ALIGN_LEFT
    halign = bodypart[2] == hpElementHintLine.RIGHT ? ALIGN_RIGHT : ALIGN_LEFT
    pos = position
    flow = FLOW_VERTICAL
    children = mkContent()
  }
}

let dmgColor = Color(150,0,0)
let mkDmgAnim = @(partName, baseColor) {
  prop = AnimProp.color, from = baseColor, to = Color(220, 220, 220, 220), duration = 1.5,
  loop = true, trigger = $"{partName}_dmg_anim", easing = CosineFull
}

let mkInjuredAnim = @(partName, baseColor) {
  prop = AnimProp.color, from = baseColor, to = dmgColor, duration = 1,
  loop = true, trigger = $"{partName}_inj_anim", easing = CosineFull
}

let healColor = Color(100,150,100)
let healDarkColor = Color(30,80,30)
let mkHealAnim = @(partName, _baseColor) {
  prop = AnimProp.color, from = healColor, to = healDarkColor, duration = 1,
  loop = true, trigger = $"{partName}_heal_anim", easing = CosineFull
}

let mkPartName = @(bodypart) {
  rendObj = ROBJ_SOLID
  size = [ flex(), headerHeight ]
  color = slotHeaderBg
  hplace = bodypart[2] == hpElementHintLine.RIGHT ? ALIGN_RIGHT : ALIGN_LEFT
  children = {
    rendObj = ROBJ_TEXT
    color = Color(220, 220, 220, 220)
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    maxWidth = hdpx(76)
    text = loc($"damage_model/{bodypart[0]}")
  }.__update(tiny_txt)
}

let itemHealFilterTypeQuery = ecs.SqQuery("itemHealFilterTypeQuery", {comps_ro = [["item__filterType", ecs.TYPE_STRING]]})

ecs.register_es("is_healing_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      let eid = comp["human_inventory__entityToUse"]
      local isPlayerHealing = false
      itemHealFilterTypeQuery.perform(eid, function(_eid, querycomp) {
        isPlayerHealing = querycomp?.item__filterType == "medicines"
      })
      isHealing.set(isPlayerHealing)
    }
    onDestroy = function() {
      isHealing.set(false)
      healingPart.set(null)
    }
  },
  {
    comps_track = [["human_inventory__entityToUse",ecs.TYPE_EID]],
    comps_rq = ["watchedByPlr"]
  },
)

ecs.register_es("show_healing_doll_es",
  {
    [CmdShowHealingDoll] = function(_evt, eid, _comp) {
      healingDollItemEid.set(eid)
      openHealingDoll()
    }
  },
  {
    comps_rq = ["watchedPlayerItem"]
  },
)

function mkPartHp(bodypart, showCurrent, interactable) {
  let partName = bodypart[0]
  let maxHp = bodyParts.get()?[partName]?.maxHp ?? -1.0
  let hp = bodyParts.get()?[partName]?.hp ?? -1.0
  let isInjured = bodyParts.get()?[partName]?.isInjured ?? false
  let canDropDragged = @(item) item?.isHealkit && hp < maxHp
  let percent = min(1.0, hp / max(maxHp, 0.01))
  let isInfinity = hp > maxHp
  let fillColor = showCurrent
    ? isInjured
      ? injuredPartColor
      : Color(220, lerp(1.0, 0.0, 220, 31, percent), lerp(1.0, 0.0, 220, 32, percent), 255)
    : Color(220, 220, 220, 255)
  let hint = buildDamageModelPartTooltip(partName)
  let stateFlag = Watched(0)

  let hpTextStr = !showCurrent ? ""
    : isInfinity ? "∞"
    : (hp >= 0.0 && maxHp >= 0.0) ? $"{hp} / {maxHp}"
    : maxHp
  let hpText = {
    rendObj = ROBJ_INSCRIPTION
    text = hpTextStr
    color = isInjured ? TextHighlight : TextActive
    fontSize = isInfinity ? hdpx(20) : hdpx(9)
    key = hpTextStr
    padding = hdpx(1)
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
  }

  let minWidth = math.max(
    calc_comp_size(hpText)[0]
    calc_str_box({text=loc($"damage_model/{bodypart[0]}")}.__update(tiny_txt))[0]
    itemHeight
  )

  let partNameComp = mkPartName(bodypart)
  function mkHpComp() {
    function triggerAnimation() {
      let isDamaged = percent < 1.0
      let isPartInjured = percent == 0.0
      if (isHealing.get() && healingPart.get() == partName)
        anim_start($"{partName}_heal_anim")
      else {
        anim_request_stop($"{partName}_heal_anim")

        if (isPartInjured)
          anim_start($"{partName}_inj_anim")
        else
          anim_request_stop($"{partName}_inj_anim")

        if (!isPartInjured && isDamaged)
          anim_start($"{partName}_dmg_anim")
        else
          anim_request_stop($"{partName}_dmg_anim")
      }
    }
    return function() {
      triggerAnimation()
      return {
        watch = [isHealing, healingPart]
        rendObj = ROBJ_SOLID
        size = [ flex(), headerHeight ]
        hplace = ALIGN_CENTER
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        onAttach = triggerAnimation
        transform = static {}
        animations = [
          mkInjuredAnim(partName, fillColor),
          mkDmgAnim(partName, fillColor),
          mkHealAnim(partName, fillColor)
        ]
        children = hpText
      }
    }
  }

  return @() {
    watch = [draggedData, stateFlag]
    minWidth
    size = FLEX_H
    behavior = interactable ? [Behaviors.Button, Behaviors.DragAndDrop] : null
    skipDirPadNav = true
    onElemState = @(val) stateFlag.set(val)

    hplace = bodypart[2] == hpElementHintLine.RIGHT ? ALIGN_RIGHT :
              bodypart[2] == hpElementHintLine.LEFT ? ALIGN_LEFT :
              ALIGN_CENTER

    function onHover(on) {
      setTooltip(on && hint != "" ? hint : null)
    }
    function onClick() {
      set_wish_part_to_heal_bind(controlledHeroEid.get(), bodypart[0])
      if (healingDollItemEid.get() == ecs.INVALID_ENTITY_ID)
        healingDollItemEid.set(get_most_needed_heal_item_bind(controlledHeroEid.get()))
      ecs.g_entity_mgr.sendEvent(healingDollItemEid.get(), TryUseItem({userEid = controlledHeroEid.get()}))
      healingPart.set(partName)
      closeHealingDoll()
    }
    function onDrop(data) {
      if (canDropDragged(data) && verify_healing_attempt_bind(controlledHeroEid.get(), data.eid)) {
        set_wish_part_to_heal_bind(controlledHeroEid.get(), bodypart[0])
        ecs.g_entity_mgr.sendEvent(data.eid, TryUseItem({userEid = controlledHeroEid.get()}))
        healingPart.set(partName)
      }
      else if (data?.isHealkit)
        show_healing_tip_bind(controlledHeroEid.get(), data.eid)
    }
    children = [
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        valign = ALIGN_BOTTOM
        children = [
          partNameComp
          mkHpComp()
        ]
      }
      {
        size = flex()
        children = draggedData && draggedData.get() && canDropDragged(draggedData.get()) ? dropMarker(stateFlag.get()) : null
      }
    ]
  }
}

function mkActivePresetHp(bodypart) {
  let hplace = bodypart[2] == hpElementHintLine.RIGHT ? ALIGN_RIGHT :
      bodypart[2] == hpElementHintLine.LEFT ? ALIGN_LEFT :
      ALIGN_CENTER
  return {
    minWidth = itemHeight
    size = FLEX_H
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    hplace
    children = [
      mkPartName(bodypart)
      {
        rendObj = ROBJ_SOLID
        size = [flex(), headerHeight]
        color = slotHeaderBg
      }
    ]
  }
}

function mkPartHpBlock(bodypart, showCurrent = true, interactable = true) {
  let isPresetActive = Computed(@() previewPreset.get() != null)
  return @() {
    watch = isPresetActive
    children = isPresetActive.get() ? mkActivePresetHp(bodypart) : mkPartHp(bodypart, showCurrent, interactable)
  }
}

function previewToSlot(previewItem, slotName) {
  if (previewItem == null)
    return null
  let fakeSlot = humanEquipmentSlots?[slotName] ?? getSlotFromTemplate(slotName)
  let fakeItem = previewItem?.itemTemplate != null ? mkFakeItem(previewItem.itemTemplate, previewItem) : {}

  return fakeItem.__merge(fakeSlot, { slotName })
}

function mkSuitSlotCallbacks(slotName, previewCallbacks) {
  if (previewCallbacks) {
    return inventoryItemClickActions[slotName].__merge(previewCallbacks)
  }
  return inventoryItemClickActions[slotName]
}

function mkPartSuitEquipment(bodypart, suit, isActionForbidden = false) {
  #forbid-auto-freeze
  let partName = bodypart[0]
  local slots = []
  if (previewPreset.get() != null) {
    foreach (slotName, suitSlotData in suit?.mods ?? {}) {
      if (!startswith(slotName, $"equipment_mod_{partName}"))
        continue

      let cbOverride = previewPresetCallbackOverride.get()?["chronogene_primary_1"][slotName]
      let presetData = (previewPreset.get()?.chronogene_primary_1[slotName]
        ? previewToSlot(previewPreset.get().chronogene_primary_1[slotName], slotName)
        : {
          defaultIcon = suitSlotData?.icon
          slotTooltip = suitSlotData?.tooltip
          slotTemplate = suitSlotData?.slotTemplate
          iconImageColor = Color(101, 101, 101, 51)
        }).__merge({
          allowed_items = suitSlotData?.slotTemplate ? getSlotAvailableMods(suitSlotData.slotTemplate) : []
          slotName
        })

      slots.append(mkEquipmentSlot(presetData, mkSuitSlotCallbacks(ON_BODY_SLOT.name, cbOverride),
        inventoryImageParams, ON_BODY_SLOT, isActionForbidden || (cbOverride == null)))
    }
  }
  else {
    slots = mkSuitSlots(suit, partName, ON_BODY_SLOT,
      inventoryItemClickActions[ON_BODY_SLOT.name], isActionForbidden)
  }
  return mkSuitPartModsPanel(slots, ALIGN_LEFT)
}

function getTemplateEquipmentSlots(suitTemplateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplateName)
  let mods = (template.getCompValNullable("equipment_mods__slots")?.getAll() ?? {}).map(function(equipTemplateName) {
    let equipTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(equipTemplateName)
    return {
      slotTemplate = equipTemplateName
      icon = equipTemplate?.getCompValNullable("mod_slot__icon")
      tooltip = equipTemplate?.getCompValNullable("mod_slot__tooltip")
      allowed_items = equipTemplate?.getCompValNullable("slot_holder__availableItems")
    }
  })
  return mods
}

function getEquipmentSlotData(preview, equip, slotName) {
  if (preview) {
    let slot = preview?[slotName]
    return slot ? previewToSlot(slot, slotName) : humanEquipmentSlots[slotName].__merge({ slotName })
  }
  else {
    return equip?[slotName].__merge(humanEquipmentSlots[slotName]) ?? humanEquipmentSlots[slotName]
  }
}

function getEquipmentVisibility(preview, equip, slotName) {

  if (preview?[slotName] == null && equip?[slotName] == null)
    return false

  let slotData = getEquipmentSlotData(preview, equip, slotName)
  return !((slotData?.flags ?? 0) & EquipmentSlotFlags.REMOVED)
}

function mkHelmet(isActionForbidden) {
  let helmetSlot = getEquipmentSlotData(previewPreset.get(), equipment.get(), "helmet")

  local nvdSlot = null

  if (previewPreset.get() != null) {
    let helmetPreviewSlot = previewPreset.get()?.helmet
    let nvdPreviewPresetSlot = previewPreset.get()?.helmet.attachments.equipment_mod_night_vision_device
    if (nvdPreviewPresetSlot) {
      nvdSlot = previewToSlot(nvdPreviewPresetSlot, "night_vision_device_slot")
    }
    else if (helmetPreviewSlot?.itemTemplate){
      let templateSlots = getTemplateEquipmentSlots(helmetPreviewSlot?.itemTemplate)
      let nvdTemplateSlot = templateSlots?.equipment_mod_night_vision_device
      if (nvdTemplateSlot) {
        nvdSlot = getSlotFromTemplate("night_vision_device_slot")
      }
    }
  }
  else {
    nvdSlot = equipmentModSlots.get()?.helmet.equipment_mod_night_vision_device 
  }

  let helmetCbOverride = previewPresetCallbackOverride.get()?.helmet
  let helmetModCbOverride = previewPresetCallbackOverride.get()?.helmet.attachments.equipment_mod_night_vision_device

  let helmetActionsForbidden = isActionForbidden || (previewPreset.get() != null && helmetCbOverride == null)
  let helmetModActionsForbidden = isActionForbidden || (previewPreset.get() != null && helmetModCbOverride == null)

  let helmet = mkEquipmentSlot(helmetSlot, mkSuitSlotCallbacks(ON_BODY_SLOT.name, helmetCbOverride), inventoryImageParams, ON_BODY_SLOT, helmetActionsForbidden)
  let helmetMod = nvdSlot ? mkEquipmentSlot(nvdSlot, mkSuitSlotCallbacks(ON_BODY_SLOT.name, helmetModCbOverride), inventoryImageParams, ON_BODY_SLOT, helmetModActionsForbidden) : null

  return {
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [
      helmetMod
      helmet
    ]
  }
}

function canDropOnBody(item) {
  return item && item?.eid && (
      isFastEquipItemPossible(item) ||
      verify_healing_attempt_bind(controlledHeroEid.get(), item.eid)
    ) && !item.isAmmo
}

function mkFakeSuit(suitTemplate) {
  let suitType = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplate)?.getCompValNullable("suit__suitType") ?? 0
  return suitType == 0 ? "am_trooper_empty_model_male_char" : "am_trooper_empty_model_female_char"
}

let highlightDollParams = static {
  silhouette = [25, 25, 15, 150],
  silhouetteInactive = [25, 25, 15, 150],
  shading = "silhouette",
  animations = [{ prop=AnimProp.opacity, from=0.0, to=1, duration=1.2, play=true, loop=true, easing=CosineFull }]
}

let outlineDollParams = static {
  outline = [56, 44, 18, 255],
  outlineInactive = [56, 44, 18, 255],
  shading = "silhouette",
  silhouette = [0, 0, 0, 0],
  silhouetteInactive = [0, 0, 0, 0],
}

let bodypartsPanel = @(isActionForbidden = false, iconParams=null) function() {
  let width = isPreparationOpened.get() ? hdpx(565) : hdpx(600)
  let panelSize = [width, hdpx(800)]
  let bodyPanelSize = [panelSize[0], hdpx(750)]
  let dollSize = static [ hdpx(487), hdpx(750) ]

  let suit = previewPreset.get() != null
    ? {
        mods = previewPreset.get()?.chronogene_primary_1.itemTemplate ? getTemplateEquipmentSlots(previewPreset.get().chronogene_primary_1.itemTemplate) : null
      }
    : equipment.get()?["chronogene_primary_1"]
  let bodyEquipment = mkPartSuitEquipment(bodyDoll, suit, isActionForbidden)

  let limbsEquipment = limbsDoll.map(function(i) {
    let equip = mkPartSuitEquipment(i, suit, isActionForbidden)
    return mkBodypartBlock(i, panelSize, mkPartHpBlock(i), equip)
  })

  let backpackSlotIsVisible = getEquipmentVisibility(previewPreset.get(), equipment.get(), "backpack")
  let pouchSlotIsVisible = getEquipmentVisibility(previewPreset.get(), equipment.get(), "pouch")

  let safepackSlotIsRemoved = !getEquipmentVisibility(previewPreset.get(), equipment.get(), "safepack")
  let backpackAndPouch = @(){
    watch = [equipment, attachedEquipment, previewPreset]
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    halign = ALIGN_RIGHT
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(5)
        children = [
          backpackSlotIsVisible ? mkEquipmentSlot(
            getEquipmentSlotData(previewPreset.get(), equipment.get(), "backpack"),
            mkSuitSlotCallbacks(ON_BODY_SLOT.name, previewPresetCallbackOverride.get()?.backpack),
            inventoryImageParams,
            ON_BODY_SLOT,
            isActionForbidden && (previewPreset.get() != null && previewPresetCallbackOverride.get()?.backpack != null)
          ) : null
          pouchSlotIsVisible ? mkEquipmentSlot(
            getEquipmentSlotData(previewPreset.get(), equipment.get(), "pouch")
            mkSuitSlotCallbacks(ON_BODY_SLOT.name, previewPresetCallbackOverride.get()?.pouch),
            inventoryImageParams,
            ON_BODY_SLOT,
            isActionForbidden && (previewPreset.get() != null && previewPresetCallbackOverride.get()?.pouch != null)
          ) : null
        ]
      }
      function() {
        let safepackSlotIsVisible = !safepackSlotIsRemoved
          && !(isInMonsterState.get() && !isMonsterInventoryEnabled.get())
          && !isNexus.get()
          && !isNexusPreparationOpened.get()
        return {
          watch = [isInMonsterState, isMonsterInventoryEnabled, isNexus, isNexusPreparationOpened]
          flow = FLOW_HORIZONTAL
          gap = hdpx(5)
          children = [
            safepackSlotIsVisible ? mkEquipmentSlot(
              getEquipmentSlotData(previewPreset.get(), equipment.get(), "safepack")
              mkSuitSlotCallbacks(ON_BODY_SLOT.name, previewPresetCallbackOverride.get()?.safepack),
              inventoryImageParams,
              ON_BODY_SLOT,
              isActionForbidden || (previewPreset.get() != null && previewPresetCallbackOverride.get()?.safepack != null)
            ) : null
          ]
        }
      }
    ]
  }

  let backpackAndPouchPart = mkBodypartBlock(backpackAndPouchesDoll, panelSize, null, backpackAndPouch)

  let flashlightSlotIsVisible = getEquipmentVisibility(previewPreset.get(), equipment.get(), "flashlight")
  let signalGrenadeSlotIsVisible = getEquipmentVisibility(previewPreset.get(), equipment.get(), "signal_grenade")
  let devices = @(){
    watch = [equipment, attachedEquipment, previewPreset, isNexusPreparationOpened]
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    halign = ALIGN_RIGHT
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(5)
        children = [
          flashlightSlotIsVisible ? mkEquipmentSlot(
            getEquipmentSlotData(previewPreset.get(), equipment.get(), "flashlight"),
            mkSuitSlotCallbacks(ON_BODY_SLOT.name, previewPresetCallbackOverride.get()?.flashlight),
            inventoryImageParams,
            ON_BODY_SLOT,
            isActionForbidden || (previewPreset.get() != null && previewPresetCallbackOverride.get()?.flashlight == null)
          ) : null
          signalGrenadeSlotIsVisible && !isNexusPreparationOpened.get() ? mkEquipmentSlot(
            getEquipmentSlotData(previewPreset.get(), equipment.get(), "signal_grenade")
            mkSuitSlotCallbacks(ON_BODY_SLOT.name, previewPresetCallbackOverride.get()?.pouch),
            inventoryImageParams,
            ON_BODY_SLOT,
            isActionForbidden && (previewPreset.get() != null && previewPresetCallbackOverride.get()?.signal_grenade != null)
          ) : null
        ]
      }
    ]
  }

  let flashlightPart = mkBodypartBlock(flashlightDoll, panelSize, null, devices)

  let helmetSlotIsVisible = getEquipmentVisibility(previewPreset.get(), equipment.get(), "helmet")
  let headPart = helmetSlotIsVisible ? mkBodypartBlock(headDoll, panelSize, mkPartHpBlock(headDoll), mkHelmet(isActionForbidden))
    : mkBodypartBlock(headDoll, panelSize, mkPartHpBlock(headDoll))
  let bodyPart = mkBodypartBlock(bodyDoll, bodyPanelSize, mkPartHpBlock(bodyDoll), bodyEquipment)

  let needFakeEquip = previewPreset.get() != null && previewPreset.get()?.overrideMainChronogeneDoll

  let equipAttached = needFakeEquip
    ? fakeEquipmentAsAttaches(previewPreset.get())
    : attachedEquipment.get()
  let ribbonsOverride = previewPresetOverrideRibbons.get() ?? {}
  let normalDoll = mkHeroDoll(watchedHeroMainAnimcharRes.get(), mkIconAttachments(equipAttached), dollSize, null, null, iconParams)
  let highlightedDoll = mkHeroDoll(watchedHeroMainAnimcharRes.get(), mkIconAttachments(equipAttached), dollSize, highlightDollParams, null, iconParams)
  let outlineDoll = mkHeroDoll(watchedHeroMainAnimcharRes.get(), mkIconAttachments(equipAttached), dollSize, outlineDollParams, null, iconParams)

  let normalDollComp = @(){
    watch = draggedData
    size = flex()
    hplace = ALIGN_CENTER
    children = [
      normalDoll,
      canDropOnBody(draggedData.get()) ? highlightedDoll : null,
      canDropOnBody(draggedData.get()) ? outlineDoll : null
    ]
  }

  let doll = !needFakeEquip ? normalDollComp
    : mkHeroDoll(mkFakeSuit(previewPreset.get()?["chronogene_primary_1"].itemTemplate ?? ""),
        mkIconAttachments(equipAttached, ribbonsOverride), dollSize,
        {}, ribbonsOverride, iconParams)

  return {
    watch = [equipment, bodyParts, watchedHeroAnimcharEid, watchedHeroMainAnimcharRes, attachedEquipment,
      previewPreset, draggedData, equipmentModSlots, isPreparationOpened, previewPresetCallbackOverride]
    size = panelSize
    skipDirPadNav = true
    behavior = Behaviors.DragAndDrop
    onDrop = function(item){
      if (verify_healing_attempt_bind(controlledHeroEid.get(), item.eid))
        ecs.g_entity_mgr.sendEvent(item.eid, TryUseItem({userEid = controlledHeroEid.get()}))
      else if (isFastEquipItemPossible(item) && !item.isAmmo)
        fastEquipItem(item)
      else if (item.isHealkit)
        show_healing_tip_bind(controlledHeroEid.get(), item.eid)
    }
    canDrop = function(item) {
      return (item?.isDragAndDropAvailable ?? true) &&
        ((item?.slotName == null && isFastEquipItemPossible(item)) ||
        verify_healing_attempt_bind(controlledHeroEid.get(), item.eid))
    }
    children = bodyParts.get() ? [
      doll
    ].extend(limbsEquipment).append(headPart, bodyPart, flashlightPart, backpackAndPouchPart) : null
  }
}

function mkSuitPreview(suitTemplatName){
  let panelSize = static [ hdpx(600), hdpx(800)]
  let dollSize = static [ hdpx(487), hdpx(750) ]

  let suitTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplatName)
  if (!suitTemplate)
    return null
  let animchar = suitTemplatName ?
    suitTemplate.getCompValNullable("animchar__res") :
    "am_trooper_empty_model_male_char"

  return {
    size = panelSize
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = mkHeroDoll(animchar, null, dollSize)
  }
}

function mkMiniBodyPartsChildren(iconName, pos_name, size){
  return [
    mkHintDoll(iconName, size, pos_name, static { color = Color(192, 192, 192, 200), outline = [18, 18, 18, 255] }),
  ].extend(bodyParts.get().values()
    .sort(@(a,b) dummyNodeNames[a.name].zpos <=> dummyNodeNames[b.name].zpos)
    .map(function(bp){
      if (bp.hp < bp.maxHp) {
        let percent = min(1.0, bp.hp / max(bp.maxHp, 0.01))
        let color = bp.isInjured
          ? injuredPartColor
          : Color(220, lerp(1.0, 0.0, 220, 31, percent), lerp(1.0, 0.0, 220, 32, percent), 255)
        return mkHintDoll(iconName, size, pos_name, { color }, dummyNodeNames[bp.name].hide)
      }
      else
        throw null
    }))
}

let getMiniPos = @(name, customHdpx) [
  customHdpx(miniBodypartPanelOffset?[name][0] ?? 5),
  customHdpx(miniBodypartPanelOffset?[name][1] ?? -5)
]

let miniBodypartsPanel = @(customHdpx=hdpx) @(){
  watch = [bodyParts, bodyPartsIsDamaged, currentPosName, watchedHeroSex]
  pos = getMiniPos(currentPosName.get(), customHdpx)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = currentPosName.get() ? mkMiniBodyPartsChildren(
      watchedHeroSex.get() == 0 ?
        "damage_doll_male_char" :
        "damage_doll_female_char",
      currentPosName.get(),
      [ customHdpx(miniDollSize[0]), customHdpx(miniDollSize[1]) ]
    ) : null
}

let damagedAnimations = freeze([
  { prop=AnimProp.translate, from=[0, -20], to=[0,0], duration=0.2, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[0,0], to=[1,1], duration=0.2, play=true, easing=OutCubic}
])

function getHealingDollAnimations(isDamaged){
  if (isDamaged) {
    return damagedAnimations
  }
  else {
    return [
      { prop=AnimProp.translate, from=[0, -20], to=[0,0], duration=0.2, play=true, easing=OutCubic }
      { prop=AnimProp.opacity, from=1, to=0, duration=2, play=true, easing=InCubic, onFinish = closeHealingDoll}
    ]
  }
}
let healthyTxt = {rendObj = ROBJ_TEXT text = loc("Healthy") hplace = ALIGN_CENTER}

function healingDollPanel() {
  let dollSize = getDollSize(hdpx(800))
  return {
    size = dollSize
    onAttach = onAttachHealingDoll
    onDetach = onDetachHealingDoll
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = @() {
      watch = [bodyParts, bodyPartsIsDamaged]
      opacity = bodyPartsIsDamaged.get() ? 1 : 0
      transform = {}
      animations = getHealingDollAnimations(bodyPartsIsDamaged.get())
      size = flex()
      children = [!bodyPartsIsDamaged.get() ? healthyTxt : null].extend(
        limbsDoll.map( function(v) {
          return mkBodypartBlock(v, dollSize, mkPartHpBlock(v, true, bodyPartsIsDamaged.get()), null )
        }),
        [
          mkHeroDoll("am_trooper_empty_model_male_char", mkIconAttachments(attachedEquipment.get()), dollSize)
          mkBodypartBlock(bodyDoll, dollSize, mkPartHpBlock(bodyDoll, true, bodyPartsIsDamaged.get()), null)
          mkBodypartBlock(headDoll, dollSize, mkPartHpBlock(headDoll, true, bodyPartsIsDamaged.get()), null)
        ])
    }
  }
}

return {
  bodypartsPanel = bodypartsPanel(false)
  nonInteractiveBodypartsPanel = bodypartsPanel(true)
  nonInteractiveDesaturateBodypartsPanel = bodypartsPanel(true, {picSaturate=0})
  miniBodypartsPanel
  healingDollPanel
  HealingDollId
  openHealingDoll
  closeHealingDoll
  mkHeroDoll
  mkSuitPreview
  hpElementHintLine
  mkIconAttachments
}
