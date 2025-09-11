from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkSelectPanelTextCtor, bluredPanel, BD_LEFT, mkText
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog

from "%ui/fonts_style.nut" import giant_txt, body_txt
from "dasevents" import CmdNexusBattleSelectLoadout, RequestNexusSpawnPlayer, RequestNexusChangeLoadoutPlayer, sendNetEvent, RequestNexusEnterSpawnList
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/components/button.nut" import textButton
from "%ui/components/colors.nut" import BtnBgDisabled, RedWarningColor, TextNormal, NexusPlayerPointsColor
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement
from "%ui/hud/hud_menus_state.nut" import closeMenu, convertMenuId
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview
from "%ui/mainMenu/ribbons_colors_picker.nut" import colorPickerButton
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeaderText
from "%ui/hud/menus/components/inventoryItemsHeroWeapons.nut" import mkEquipmentWeapons
from "%ui/hud/menus/components/damageModel.nut" import nonInteractiveDesaturateBodypartsPanel, nonInteractiveBodypartsPanel
from "%ui/hud/state/human_damage_model_state.nut" import update_body_parts_state
from "das.ribbons_color" import get_color_as_array_by_index
from "%ui/equipPresets/convert_loadout_to_preset.nut" import loadoutToPreset
from "%ui/hud/menus/components/quickUsePanel.nut" import quickUsePanelEdit
from "%ui/hud/tips/nexus_header_components.nut" import mkNexusTimer
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/faComp.nut" as faComp
from "%ui/hud/menus/components/inventoryItemNexusPointPriceComp.nut" import nexusPointsIcon, nexusPointsIconSize
from "%ui/components/cursors.nut" import setTooltip

let { allLocalPlayerNexusLoadouts } = require("%ui/hud/state/nexus_loadout_state.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { isNexus, isNexusRoundMode, isNexusPlayerCanSpawn, isNexusPlayerCanChangeLoadout, isNexusPlayerSpawned, isNexusPlayerExists,
  nexusModeTeamColorIndices } = require("%ui/hud/state/nexus_mode_state.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { levelLoaded } = require("%ui/state/appState.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { isNexusDebriefingState } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { playerLogsColors } = require("%ui/popup/player_event_log.nut")
let { previewPreset, previewPresetOverrideRibbons } = require("%ui/equipPresets/presetsState.nut")
let { isNexusDelayedSpawn, nexusNextDelayedSpawnAt } = require("%ui/hud/state/nexus_spawn_state.nut")
const NexusLoadoutSelectionId = "NexusLoadoutSelection"

let selectedPreviewLoadoutIndex = Watched(-1)
let chosenLoadoutIndex = Watched(-1)
let takenLoadoutIndex = Watched(-1)
let loadoutScore = Watched(-1)
let waveRespawnIndex = Watched(-1)

let isLoadoutLocked = @(loadout) (loadout?.locked ?? false)
let isLoadoutFree = @(loadout) (loadout?.free ?? false)
let isLoadoutCostTooHigh = @(loadout) !isLoadoutFree(loadout) && (loadout?.cost ?? 0) > loadoutScore.get()
let isLoadoutAvailable = @(loadout) !isLoadoutLocked(loadout) && !isLoadoutCostTooHigh(loadout)

let defaultPreviewPresetIndex = Computed(@() isNexusPlayerSpawned.get()
  ? takenLoadoutIndex.get()
  : chosenLoadoutIndex.get() > -1
    ? chosenLoadoutIndex.get()
    : allLocalPlayerNexusLoadouts.get().findindex(isLoadoutAvailable) ?? 0
  )

ecs.register_es("track_selected_loadout_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    if (!comp.is_local) {
      return
    }
    takenLoadoutIndex.set(comp.nexus_player_loadout__takenIndex)
    chosenLoadoutIndex.set(comp.nexus_player_loadout__chosenIndex)
  }
  onDestroy = function(...) {
    chosenLoadoutIndex.set(-1)
    takenLoadoutIndex.set(-1)
  }
},{
  comps_track = [
    ["nexus_player_loadout__chosenIndex", ecs.TYPE_INT],
    ["nexus_player_loadout__takenIndex", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL]
  ]
})

ecs.register_es("track_loadout_score_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    if (!comp.is_local) {
      return
    }
    loadoutScore.set(comp.nexus_player_loadout__score)
  }
  onDestroy = function(...) {
    loadoutScore.set(-1)
  }
},{
  comps_track = [
    ["nexus_player_loadout__score", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL]
  ]
})

let initFakeDamageModel = function() {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("human_damage_model")
  let fakeDm = template?.getCompValNullable("human_damage_model__parts")
  update_body_parts_state(fakeDm)
}

let updatePreviewPresetOverride = function() {
  initFakeDamageModel()
  let colors = nexusModeTeamColorIndices.get()
  if (colors != null) {
    previewPresetOverrideRibbons.set({ primaryColor = get_color_as_array_by_index(colors[0]), secondaryColor = get_color_as_array_by_index(colors[1]) })
  }
  selectedPreviewLoadoutIndex.set(-1)
}

let clearPreviewPresetOverride = function() {
  selectedPreviewLoadoutIndex.set(-1)
  previewPresetOverrideRibbons.set(null)
}

isNexusPlayerSpawned.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v)
    clearPreviewPresetOverride()
  else if (isNexusPlayerExists.get()) {
    updatePreviewPresetOverride()
  }
})

nexusModeTeamColorIndices.subscribe_with_nasty_disregard_of_frp_update(function(...) {
  if (!isNexusPlayerSpawned.get() && isNexusPlayerExists.get())
    updatePreviewPresetOverride()
  }
)

let weaponPanels = @(){
  size = FLEX_V
  gap = hdpx(20)
  padding = static [hdpx(10), hdpx(20)]
  watch = previewPreset
  flow = FLOW_VERTICAL
  transform = static {}
  animations = static [
    { prop=AnimProp.opacity,from=0, to=1, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity,from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
  ]
  children = [
    static mkInventoryHeaderText(loc("inventory/weapons"))
    mkEquipmentWeapons()
    quickUsePanelEdit
  ]
}.__merge(bluredPanel)

function mkBodyPartsPanel() {
  let previewLoadoutIndex = Computed(function() {
    let cselected = selectedPreviewLoadoutIndex.get()
    return cselected > -1
      ? cselected
      : defaultPreviewPresetIndex.get()
  })
  let loadout = Computed(@() allLocalPlayerNexusLoadouts.get()?[previewLoadoutIndex.get()])

  let updatePreviewPreset = @(preset) previewPreset.set((loadoutToPreset(preset ?? {} ) ?? {}).__merge(static { overrideMainChronogeneDoll = true }))

  updatePreviewPreset(loadout.get())
  loadout.subscribe_with_nasty_disregard_of_frp_update(updatePreviewPreset)

  return function() {
    let isAvailable = isLoadoutAvailable(loadout.get())
    let isLocked = isLoadoutLocked(loadout.get())
    let isCostTooHigh = isLoadoutCostTooHigh(loadout.get())

    return {
      watch = [ loadout, nexusModeTeamColorIndices ]
      size = FLEX_V
      halign = ALIGN_CENTER
      valign = ALIGN_BOTTOM
      padding = static [0,0, hdpx(4),0]
      children = [
        {
          flow = FLOW_VERTICAL
          vplace = ALIGN_TOP
          children = [
            mkInventoryHeaderText(loadout.get()?.name).__update(static { halign = ALIGN_LEFT })
            isAvailable ? nonInteractiveBodypartsPanel : nonInteractiveDesaturateBodypartsPanel
          ]
        }
        colorPickerButton
        isLocked ? static {
          children = {color = RedWarningColor rendObj = ROBJ_TEXT text = loc("nexus/wasted", "WASTED") fontFx = FFT_BLUR fontFxColor = Color(0,0,0,120) fontFxFactor = 48}.__update(giant_txt)
          transform = {rotate=30}
          pos = [0, sh(15)]
          vplace = ALIGN_TOP
        } : isCostTooHigh ? static {
          children = {color = RedWarningColor rendObj = ROBJ_TEXT text = loc("nexus/too_pricey", "TOO PRICEY") fontFx = FFT_BLUR fontFxColor = Color(0,0,0,120) fontFxFactor = 48}.__update(giant_txt)
          transform = {rotate=30}
          pos = [0, sh(15)]
          vplace = ALIGN_TOP
        } : null
      ]
    }
  }
}

let dollPanels = @() {
  size = FLEX_V
  padding = hdpx(10)
  children = mkBodyPartsPanel()
}.__merge(bluredPanel)

let heroInventories = @() {
  size = FLEX_V
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    {
      size = FLEX_V
      children = mkHeroInventoryPresetPreview()
    }.__merge(bluredPanel)
    {
      size = FLEX_V
      children = mkBackpackInventoryPresetPreview()
    }.__merge(bluredPanel)
  ]
}

let playerInventoryPanels = @() {
  watch = previewPreset
  size = FLEX_V
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    weaponPanels
    heroInventories
  ]
}


let unavailableColor = mul_color(TextNormal, 0.5)
function mkLoadoutComponent(loadout){
  let { index, name } = loadout
  let isAvailable = isLoadoutAvailable(loadout)
  let isLocked = isLoadoutLocked(loadout)
  let isFree = isLoadoutFree(loadout)
  let textCtor = mkSelectPanelTextCtor(name, {
    hplace = ALIGN_LEFT
    size = FLEX_H
    color = isAvailable ? TextNormal : unavailableColor
    children = isLocked ? static {vplace = ALIGN_CENTER, rendObj = ROBJ_SOLID color = unavailableColor size = static [flex(), hdpx(1)], transform={} pos = [0, hdpx(2)]} : null
  }.__update(body_txt))

  let cost = loadout?.cost ?? 0

  return @() {
    size = static [flex(), hdpx(45)]

    children = mkSelectPanelItem({
      onSelect = function(idx) {
        if (index == chosenLoadoutIndex.get())
          return
        if (isLoadoutAvailable(loadout))
          sendNetEvent(localPlayerEid.get(), CmdNexusBattleSelectLoadout({loadoutIndex = idx, selectAnyIfUnavailable = true}))
        else
          addPlayerLog({
            id = $"{chosenLoadoutIndex.get()}_{name}"
            idToIgnore = $"{chosenLoadoutIndex.get()}_{name}"
            content = mkPlayerLog({
              titleText = loc("nexus/equipLoadoutAlert")
              titleFaIcon = "close"
              bodyText = loc("nexus/loadoutUnavailable", { name = loc(name) })
              logColor = playerLogsColors.warningLog
            })
          })
      }
      idx = index
      state = chosenLoadoutIndex
      border_align = BD_LEFT
      visual_params = {
        padding = static [ 0, hdpx(2), 0, hdpx(10) ]
        style = !isAvailable ? {
          SelBgNormal = BtnBgDisabled
        } : null
      }
      onHover = @(on) selectedPreviewLoadoutIndex.set(on ? index : defaultPreviewPresetIndex.get())
      children = @(params) {
        gap = hdpx(5)
        flow = FLOW_HORIZONTAL
        children  = [
          isLocked ? static faComp("skull.svg", {color = TextNormal}) : null,
          textCtor(params),
          isLocked || cost == 0 ? null : {
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            rendObj = ROBJ_BOX
            borderRadius = [ hdpx(2), 0, 0, hdpx(2) ]
            fillColor = NexusPlayerPointsColor
            size = [ SIZE_TO_CONTENT, flex() ]
            minWidth = hdpx(80)
            valign = ALIGN_CENTER
            halign = ALIGN_CENTER
            padding = [ 0, hdpx(4) ]
            children = [
              {
                rendObj = ROBJ_IMAGE
                size = nexusPointsIconSize
                image = nexusPointsIcon
              }
              isFree ? mkText(loc("nexus/freeLoadout")) : mkText(cost)
            ]
          }
        ]
        size = flex()
      }
    })
  }
}

let equipLoadoutButton = textButton(loc("nexus/equipLoadout"),
  function() {
    sendNetEvent(localPlayerEid.get(), RequestNexusSpawnPlayer())
    if (convertMenuId(currentMenuId.get())[0] == NexusLoadoutSelectionId)
      closeMenu(NexusLoadoutSelectionId)
  },
  static {
    hotkeys = [["Enter"]]
  }.__update(accentButtonStyle))

let changeLoadoutButton = textButton(loc("nexus/equipLoadout"),
  function() {
    sendNetEvent(localPlayerEid.get(), RequestNexusChangeLoadoutPlayer())
    if (convertMenuId(currentMenuId.get())[0] == NexusLoadoutSelectionId)
      closeMenu(NexusLoadoutSelectionId)
  },
  static {
    hotkeys = [["Enter"]]
  }.__update(accentButtonStyle))

let selectLoadoutToSpawn = textButton(loc("nexus/selectLoadout"),
  function() {
    sendNetEvent(localPlayerEid.get(), RequestNexusEnterSpawnList())
    waveRespawnIndex.set(defaultPreviewPresetIndex.get())
    closeMenu(NexusLoadoutSelectionId)
  },
  static {
    hotkeys = [["Enter"]]
  }.__update(accentButtonStyle))

let waveRespawnBlock = @() {
  watch = [waveRespawnIndex, defaultPreviewPresetIndex]
  children = [
    waveRespawnIndex.get() >= 0 && defaultPreviewPresetIndex.get() == waveRespawnIndex.get()
      ? {
          size = static [SIZE_TO_CONTENT, hdpx(33)]
          children =  mkNexusTimer(nexusNextDelayedSpawnAt, loc("nexus/nextWaveTimer"))
        }
      : selectLoadoutToSpawn
  ]
}

function spawnButton() {
  if (isNexusPlayerSpawned.get()) {
    if (!isNexusPlayerCanChangeLoadout.get())
      return { watch = [isNexusPlayerSpawned, isNexusPlayerCanChangeLoadout] }
    return {
      watch = [isNexusPlayerSpawned, isNexusPlayerCanChangeLoadout]
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_CENTER
      margin = static[0, 0, hdpx(10), 0]
      children = changeLoadoutButton
    }
  }
  else {
    if (!isNexusPlayerCanSpawn.get())
      return { watch = [isNexusPlayerSpawned, isNexusPlayerCanSpawn] }
    return {
      watch = [isNexusPlayerSpawned, isNexusPlayerCanSpawn, isNexusDelayedSpawn]
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_CENTER
      margin = static[0, 0, hdpx(10), 0]
      children = isNexusDelayedSpawn.get() ? waveRespawnBlock : equipLoadoutButton
    }
  }
}

let selectorContent = makeVertScroll(function() {
  let loadoutBuckets = allLocalPlayerNexusLoadouts.get()
    .reduce(function(res, v, index) {
      let isPrivate = v?.isPrivate ?? false
      let bucket = isPrivate ? res.private : res.public
      bucket.append(v.__merge({index}))
      return res
    }, {private = [], public = []})
  let loadouts = [].extend(loadoutBuckets.public, loadoutBuckets.private).map(mkLoadoutComponent)
  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    watch = [allLocalPlayerNexusLoadouts, isNexusRoundMode]
    halign = ALIGN_CENTER
    vplace = ALIGN_TOP
    padding = static [0, hdpx(5)]
    children = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        @() {
          watch = loadoutScore
          rendObj = ROBJ_BOX
          borderRadius = hdpx(2)
          fillColor = NexusPlayerPointsColor
          padding = hdpx(4)
          size = FLEX_H
          behavior = Behaviors.Button
          onHover = function(on) {
            if (on)
              setTooltip(loc("mint/nexusPointsTitleTooltip"))
            else
              setTooltip(null)
          }
          children = [
            {
              size = FLEX_H
              flow = FLOW_HORIZONTAL
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              gap = hdpx(4)
              children = [
                mkText(loc("mint/availableScores"), body_txt)
                {
                  rendObj = ROBJ_IMAGE
                  size = nexusPointsIconSize
                  image = nexusPointsIcon
                }
                mkText(loadoutScore.get(), body_txt)
              ]
            }
            faComp("question-circle", {
              padding = [ 0, hdpx(5) ]
              color = Color(255,255,255,255)
              vplace = ALIGN_CENTER
              hplace = ALIGN_RIGHT
            })
          ]
        }
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(2)
          children = loadouts
        }
      ]
    }
  }
})

let loadoutSelectorBody = static {
  size = flex()
  padding = static [hdpx(10), hdpx(2), 0, hdpx(2)]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    selectorContent
    spawnButton
  ]
}

let nexusLoadoutSelector = static {
  vplace = ALIGN_TOP
  size = flex()
  children = [
    loadoutSelectorBody,
  ]
}

let selectorPanel = static { 
  size = static [hdpx(300), flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = nexusLoadoutSelector
}.__merge(bluredPanel)

let isChangeAvailable = Computed(@() isNexus.get() && (isNexusPlayerCanSpawn.get() || isSpectator.get()))
let isChangeRequired = Computed(@() isChangeAvailable.get()
  && takenLoadoutIndex.get()==-1
  && levelLoaded.get()
  && !isNexusDebriefingState.get())

let selectionScreen = {
  size = flex()
  transform = static {}
  padding = static [0,0, hdpx(10), 0]
  behavior = DngBhv.ActivateActionSet
  actionSet = "StopInput"
  children = [
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = static hdpx(20)
      halign = ALIGN_CENTER
      children = [
        selectorPanel
        playerInventoryPanels
      ]
    }
  ]
  onAttach = function() {
    selectedPreviewLoadoutIndex.set(-1)
    waveRespawnIndex.set(-1)
    addInteractiveElement(NexusLoadoutSelectionId)
  }
  onDetach = function() {
    selectedPreviewLoadoutIndex.set(-1)
    removeInteractiveElement(NexusLoadoutSelectionId)
    previewPreset.set(null)
  }
}

let loadoutSelectionUi = wrapInStdPanel(NexusLoadoutSelectionId, selectionScreen, null, null,
  static { size = 0 }, static { showback = false })

function selectLoadout() {
  return {
    watch = isChangeRequired
    children = isChangeRequired.get() ? static {
      size = flex()
      onAttach = @() addInteractiveElement(NexusLoadoutSelectionId)
      onDetach = @() removeInteractiveElement(NexusLoadoutSelectionId)
      children = loadoutSelectionUi
    } : null
    size = flex()
  }
}

return freeze({
  loadoutSelectionMenu = {
    id = NexusLoadoutSelectionId
    isAvailable = Computed(@() isChangeAvailable.get() && !isChangeRequired.get())
    name = loc(NexusLoadoutSelectionId)
    getContent = @() loadoutSelectionUi
  }
  NexusLoadoutSelectionId
  selectLoadout
})
