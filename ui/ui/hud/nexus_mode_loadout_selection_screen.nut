from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/faComp.nut" as faComp

let { giant_txt, h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { mkSelectPanelItem, mkSelectPanelTextCtor, mkText, bluredPanel, BD_LEFT
} = require("%ui/components/commonComponents.nut")
let { CmdNexusBattleSelectLoadout, RequestNexusSpawnPlayer, sendNetEvent } = require("dasevents")
let { wrapInStdPanel } = require("%ui/mainMenu/stdPanel.nut")
let { allLocalPlayerNexusLoadouts } = require("%ui/hud/state/nexus_loadout_state.nut")
let { textButton } =  require("%ui/components/button.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { BtnBgDisabled, RedWarningColor, TextNormal } = require("%ui/components/colors.nut")
let { isNexus, isNexusRoundMode, isNexusWaveMode, isNexusPlayerSpawned, nexusModeAdditionalWavesLeft,
  isNexusPlayerExists, nexusModeTeamColorIndices
} = require("%ui/hud/state/nexus_mode_state.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { closeMenu, convertMenuId, currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { levelLoaded } = require("%ui/state/appState.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { isNexusDebriefingState } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { addPlayerLog, mkPlayerLog, playerLogsColors
} = require("%ui/popup/player_event_log.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview } = require("%ui/hud/menus/components/inventoryItemsPresetPreview.nut")
let { previewPreset, previewPresetOverrideRibbons } = require("%ui/equipPresets/presetsState.nut")
let { colorPickerButton } = require("%ui/mainMenu/ribbons_colors_picker.nut")
let { mkInventoryHeaderText } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { mkEquipmentWeapons } = require("%ui/hud/menus/components/inventoryItemsHeroWeapons.nut")
let { nonInteractiveDesaturateBodypartsPanel, nonInteractiveBodypartsPanel } = require("%ui/hud/menus/components/damageModel.nut")
let { update_body_parts_state } = require("%ui/hud/state/human_damage_model_state.nut")
let { get_color_as_array_by_index } = require("das.ribbons_color")
let { loadoutToPreset } = require("%ui/equipPresets/convert_loadout_to_preset.nut")
let { quickUsePanelEdit } = require("%ui/hud/menus/components/quickUsePanel.nut")

let isLoadoutAvailable = @(loadout) !(loadout?.locked ?? false)

const NexusLoadoutSelectionId = "NexusLoadoutSelection"

let selectedPreviewLoadoutIndex = Watched(-1)
let chosenLoadoutIndex = Watched(-1)
let takenLoadoutIndex = Watched(-1)
let defaultPreviewPresetIndex = Computed(@() isNexusPlayerSpawned.get()
  ? takenLoadoutIndex.get()
  : chosenLoadoutIndex.get() > -1
    ? chosenLoadoutIndex.get()
    : allLocalPlayerNexusLoadouts.get().findindex(isLoadoutAvailable) ?? 0
  )
let nexusLoadoutCanChange = Watched(false)

ecs.register_es("nexus_loadout_track_can_change_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    nexusLoadoutCanChange.set(comp.nexus_loadout_controller__canChange)
  }
  onDestroy = function(_eid, _comp) {
    nexusLoadoutCanChange.set(false)
  }
}, {
  comps_track = [["nexus_loadout_controller__canChange", ecs.TYPE_BOOL]],
}, {tags = "gameClient"})


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

isNexusPlayerSpawned.subscribe(function(v) {
  if (v)
    clearPreviewPresetOverride()
  else if (isNexusPlayerExists.get())
    updatePreviewPresetOverride()
})

nexusModeTeamColorIndices.subscribe(function(...) {
  if (!isNexusPlayerSpawned.get() && isNexusPlayerExists.get())
    updatePreviewPresetOverride()
})

let weaponPanels = @(){
  size = const [ SIZE_TO_CONTENT, flex() ]
  gap = hdpx(20)
  padding = const [hdpx(10), hdpx(20)]
  watch = previewPreset
  flow = FLOW_VERTICAL
  transform = const {}
  animations = const [
    { prop=AnimProp.opacity,from=0, to=1, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity,from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
  ]
  children = [
    const mkInventoryHeaderText(loc("inventory/weapons"))
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

  let updatePreviewPreset = @(preset) previewPreset.set((loadoutToPreset(preset ?? {} ) ?? {}).__merge(const { overrideMainChronogeneDoll = true }))

  updatePreviewPreset(loadout.get())
  loadout.subscribe(updatePreviewPreset)

  return function() {
    let isAvailable = isLoadoutAvailable(loadout.get())
    return {
      watch = [ loadout, nexusModeTeamColorIndices ]
      size = const [SIZE_TO_CONTENT, flex()]
      halign = ALIGN_CENTER
      valign = ALIGN_BOTTOM
      padding = const [0,0, hdpx(4),0]
      children = [
        {
          flow = FLOW_VERTICAL
          vplace = ALIGN_TOP
          children = [
            mkInventoryHeaderText(loadout.get()?.name).__update(const { halign = ALIGN_LEFT })
            isAvailable ? nonInteractiveBodypartsPanel : nonInteractiveDesaturateBodypartsPanel
          ]
        }
        colorPickerButton
        isAvailable ? null : const {
          children = {color = RedWarningColor rendObj = ROBJ_TEXT text = loc("nexus/wasted", "WASTED") fontFx = FFT_BLUR fontFxColor = Color(0,0,0,120) fontFxFactor = 48}.__update(giant_txt)
          transform = {rotate=30}
          pos = [0, sh(15)]
          vplace = ALIGN_TOP
        }
      ]
    }
  }
}

let dollPanels = @() {
  size = const [ SIZE_TO_CONTENT, flex() ]
  padding = hdpx(10)
  children = mkBodyPartsPanel()
}.__merge(bluredPanel)

let heroInventories = @() {
  size = const [ SIZE_TO_CONTENT, flex() ]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    {
      size = const [ SIZE_TO_CONTENT, flex() ]
      children = mkHeroInventoryPresetPreview()
    }.__merge(bluredPanel)
    {
      size = const [ SIZE_TO_CONTENT, flex() ]
      children = mkBackpackInventoryPresetPreview()
    }.__merge(bluredPanel)
  ]
}

let playerInventoryPanels = @() {
  watch = previewPreset
  size = const [ SIZE_TO_CONTENT, flex() ]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    weaponPanels
    heroInventories
  ]
}

ecs.register_es("nexus_loadout_show_on_start_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    nexusLoadoutCanChange.set(comp.nexus_loadout_controller__canChange)
  }
  onDestroy = function(_eid, _comp) {
    nexusLoadoutCanChange.set(false)
  }
}, {
  comps_track = [["nexus_loadout_controller__canChange", ecs.TYPE_BOOL]],
}, {tags = "gameClient"})

let unavailableColor = mul_color(TextNormal, 0.5)
function mkLoadoutComponent(loadout){
  let { index, name } = loadout
  let isAvailable = isLoadoutAvailable(loadout)
  let textCtor = mkSelectPanelTextCtor(name, {
    hplace = ALIGN_LEFT
    size = const [flex(), SIZE_TO_CONTENT]
    color = isAvailable ? TextNormal : unavailableColor
    children = isAvailable ? null : const {vplace = ALIGN_CENTER, rendObj = ROBJ_SOLID color = unavailableColor size = [flex(), hdpx(1)], transform={} pos = [0, hdpx(2)]}
  }.__update(body_txt))
  return @() {
    size = const [flex(), hdpx(45)]

    children = mkSelectPanelItem({
      onSelect = function(idx) {
        if (index == chosenLoadoutIndex.get())
          return
        if (isLoadoutAvailable(loadout))
          sendNetEvent(localPlayerEid.get(), CmdNexusBattleSelectLoadout({loadoutIndex = idx, selectAnyIfUnavailable = false}))
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
      visual_params = !isAvailable ? const {
        style = {
          SelBgNormal = BtnBgDisabled
        }} : null
      onHover = @(on) selectedPreviewLoadoutIndex.set(on ? index : defaultPreviewPresetIndex.get())
      children = @(params) {
        gap = hdpx(5)
        children  = [
          isAvailable ? null : const faComp("skull.svg", {color = TextNormal}),
          textCtor(params)
        ]
        size = flex()
        flow = FLOW_HORIZONTAL
      }
    })
  }
}

function spawnButton() {
  let watch = isSpectator
  if (isSpectator.get())
    return const { watch }

  return {
    watch
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    margin = const[0, 0, hdpx(10), 0]
    children = textButton(loc("nexus/equipLoadout"), function() {
      sendNetEvent(localPlayerEid.get(), RequestNexusSpawnPlayer())
      if (convertMenuId(currentMenuId.get())[0] == NexusLoadoutSelectionId)
        closeMenu(NexusLoadoutSelectionId)
    },
    const {
      hotkeys = [["Enter"]]
    }.__update(accentButtonStyle))
  }
}

let gap = hdpx(2)

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
    size = [const flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    watch = [allLocalPlayerNexusLoadouts, isNexusRoundMode]
    halign = ALIGN_CENTER
    vplace = ALIGN_TOP
    padding = const [0, hdpx(5)]
    children = {
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap
      children = loadouts
    }
  }
})

let loadoutSelectorBody = const {
  size = flex()
  padding = [hdpx(10), hdpx(2), 0, hdpx(2)]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    selectorContent
    spawnButton
  ]
}

let loadoutsBlocker = @(){
  watch = const [nexusModeAdditionalWavesLeft, isNexusWaveMode]
  size = flex()
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = (isNexusWaveMode.get() && nexusModeAdditionalWavesLeft.get() == 0) ? {
    stopMouse = true
    size = flex()
    rendObj = ROBJ_BOX
    fillColor = BtnBgDisabled
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = mkText(loc("nexus/selection_blocked/no_reinforcements"), const {color = RedWarningColor}.__update(h2_txt))
  } : null
}

let nexusLoadoutSelector = {
  vplace = ALIGN_TOP
  size = flex()
  children = [
    loadoutSelectorBody,
    loadoutsBlocker
  ]
}

let selectorPanel = const { 
  size = [hdpx(300), flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = nexusLoadoutSelector
}.__merge(bluredPanel)

let isChangeAvailable = Computed(@() isNexus.get() && (nexusLoadoutCanChange.get() || isSpectator.get()))
let isChangeRequired = Computed(@() isChangeAvailable.get()
  && takenLoadoutIndex.get()==-1
  && levelLoaded.get()
  && !isNexusDebriefingState.get())

let selectionScreen = {
  size = flex()
  transform = const {}
  padding = const [0,0, hdpx(10), 0]
  behavior = DngBhv.ActivateActionSet
  actionSet = "StopInput"
  children = [
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = const hdpx(20)
      halign = ALIGN_CENTER
      children = [
        selectorPanel
        playerInventoryPanels
      ]
    }
  ]
  onAttach = function() {
    selectedPreviewLoadoutIndex.set(-1)
    addInteractiveElement(NexusLoadoutSelectionId)
  }
  onDetach = function() {
    selectedPreviewLoadoutIndex.set(-1)
    removeInteractiveElement(NexusLoadoutSelectionId)
    previewPreset.set(null)
  }
}

let loadoutSelectionUi = wrapInStdPanel(NexusLoadoutSelectionId, selectionScreen, null, null,
  const { size = [0, 0] }, const { showback = false })

function selectLoadout() {
  return {
    watch = isChangeRequired
    children = isChangeRequired.get() ? const {
      size = flex()
      onAttach = @() addInteractiveElement(NexusLoadoutSelectionId)
      onDetach = @() removeInteractiveElement(NexusLoadoutSelectionId)
      children = loadoutSelectionUi
    } : null
    size = flex()
  }
}

return {
  loadoutSelectionMenu = {
    id = NexusLoadoutSelectionId
    isAvailable = Computed(@() isChangeAvailable.get() && !isChangeRequired.get())
    name = loc(NexusLoadoutSelectionId)
    getContent = @() loadoutSelectionUi
    event = "HUD.NexusLoadout"
  }
  NexusLoadoutSelectionId
  selectLoadout
}
