from "%sqGlob/dasenums.nut" import ContractType
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/loading/loadingComponents.nut" import mkAnimatedEllipsis
from "%ui/hud/objectives/objective_components.nut" import getContractProgressionText
from "%ui/components/commonComponents.nut" import mkText, mkTextArea, bluredPanel, mkDescTextarea
from "%ui/panels/smartwatch_panel.nut" import mkSmartwatchUi
from "dagor.localize" import doesLocTextExist

from "%ui/ui_library.nut" import *

let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { levelIsLoading, dbgLoading } = require("%ui/state/appState.nut")
let { queueRaid } = require("%ui/gameModeState.nut")
let { playerProfileCurrentContracts } = require("%ui/profile/profileState.nut")
let { isOnboarding, playerProfileOnboardingContracts } = require("%ui/hud/state/onboarding_state.nut")
let { isInSquad, isSquadLeader, squadLeaderState } = require("%ui/squad/squadManager.nut")
let { shuffle } = require("%sqstd/rand.nut")
let { amTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { isNexusWaveMode } = require("%ui/hud/state/nexus_mode_state.nut")
let { currentPrimaryContractIds } = require("%ui/mainMenu/raid_preparation_window_state.nut")

#allow-auto-freeze

const DEF_TIME_TO_SWITCH = 15
const DEF_AUTO_TIME_SWITCH = 10

let color = Color(160,160,160,160)
let fontSize = hdpx(25)
let screenPadding = [0, fsh(2)]
let contentPadding = [hdpx(5), hdpx(10)]
let animatedEllipsis = mkAnimatedEllipsis(fontSize, color)
let curIdx = Watched(0)
let nextTipAuto = @() curIdx.modify(@(v) v+1)

function nextTip() {
  gui_scene.clearTimer(nextTipAuto)
  gui_scene.clearTimer(callee())
  gui_scene.setTimeout(DEF_TIME_TO_SWITCH, callee())
  nextTipAuto()
}

function prevTip() {
  gui_scene.clearTimer(nextTipAuto)
  gui_scene.clearTimer(nextTip)
  gui_scene.setTimeout(DEF_TIME_TO_SWITCH, nextTip)
  nextTipAuto()
}

gui_scene.setInterval(DEF_AUTO_TIME_SWITCH, nextTipAuto)

let tipsHotkeys = @() {
  size = flex()
  children = {
    behavior = Behaviors.Button
    size = flex()
    hotkeys = [
      ["^A | Down | S | M:0", prevTip],
      ["^W | Up | D | | M:1", nextTip],
      ["^J:D.Left | Left", prevTip],
      ["^J:D.Right | Right", nextTip]
    ]
  }
}

let animations = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.4, play=true, easing=InCubic}
]

let activeTipText = @(text) {
  size = FLEX_H
  clipChildren = true
  valign = ALIGN_CENTER
  children = mkTextArea(loc(text), {
    behavior = [Behaviors.TextArea, Behaviors.Marquee]
    orientation = O_VERTICAL
    transform = {}
    speed = [hdpx(10), hdpx(200)]
    delay = 3
  }.__update(h2_txt))
}

function mkTips() {
  let hintsList = Computed(function() {
    #forbid-auto-freeze
    local hintsToChange = []
    let hintsKey = isNexusWaveMode.get() ? "nexus_loading_tip": "loading_tip"
    local lastAddedTipIdx = 0
    for(local idx = 1; idx - lastAddedTipIdx < 3 ; idx++){
      let newKey = $"{hintsKey}{idx}"
      if (doesLocTextExist(newKey)){
        hintsToChange.append(newKey)
        lastAddedTipIdx = idx
      }
    }
    return shuffle(hintsToChange)
  })

  let curHint = Computed(@() hintsList.get().len() > 0
    ? hintsList.get()[curIdx.get() % hintsList.get().len()]
    : null)

  let watch = [hintsList, curHint]
  if (curHint.get() == null)
    return @() { watch }
  return @() {
    watch
    size = static [sw(65), SIZE_TO_CONTENT]
    transform = {pivot = [0.5, 0.5]}
    vplace = ALIGN_CENTER
    minHeight = hdpx(80)
    padding = screenPadding
    valign = ALIGN_CENTER
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        valign = ALIGN_CENTER
        padding = contentPadding
        children = [
          mkText(amTextIcon, { fontSize = hdpxi(50) })
          {
            size = FLEX_H
            key = curHint.get()
            transform = {pivot = [0.5, 0.5]}
            flow = FLOW_VERTICAL
            animations
            children = activeTipText(curHint.get())
          }
        ]
      }
      tipsHotkeys
    ]
  }.__update(bluredPanel)
}

function mainObjective() {
  let queueInfo = isInSquad.get() && !isSquadLeader.get()
    ? squadLeaderState.get().curQueueParam?.queueRaid
    : queueRaid.get()

  local selectedContract = isOnboarding.get() ? playerProfileOnboardingContracts.get()?[0]
    : playerProfileCurrentContracts.get().findvalue(@(v, k) v.raidName == queueInfo?.extraParams.raidName
        && v.contractType == ContractType.PRIMARY
        && k in currentPrimaryContractIds.get())

  if (selectedContract == null)
    selectedContract = playerProfileCurrentContracts.get()
      .reduce(function(res, v) {
        if (v.raidName == queueInfo?.extraParams.raidName
          && v.contractType == ContractType.PRIMARY
          && (res?.difficulty == null || v.difficulty < res.difficulty)
        )
          return v
        return res
      }, null)

  let watch = [queueRaid, squadLeaderState, isSquadLeader, isInSquad, isOnboarding,
    playerProfileOnboardingContracts, playerProfileCurrentContracts, currentPrimaryContractIds ]

  if (selectedContract == null)
    return { watch }

  let { name = "", handledByGameTemplate = "", currentValue = null, requireValue = 0, params = {},
    addition = null, requireExtraction = false } = selectedContract
  return {
    watch
    size = FLEX_H
    valign = ALIGN_BOTTOM
    padding = screenPadding
    children = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(5)
      padding = contentPadding
      children = [
        mkTextArea(loc($"contract/{name}"), h2_txt)
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(2)
          children = [
            mkDescTextarea(getContractProgressionText({ name, handledByGameTemplate, currentValue, requireValue, params }), body_txt)
            addition != null ? mkText(addition) : null
            requireExtraction ? mkText(loc("contract/require_extraction_short")) : null
          ]
        }
      ]
    }
  }.__update(bluredPanel)
}

let loadingText = static {
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      text = loc("Loading")
      fontSize = fontSize
      color
    }
    static {size=[hdpx(4),0]}
    animatedEllipsis
  ]
}

let loadingWatch = @() {
  size = hdpx(180)
  pos = static [-fsh(5),-fsh(3)]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  children = [
    mkSmartwatchUi()
    loadingText
  ]
}

let simpleLoading = @() {
  watch = [safeAreaVerPadding, safeAreaHorPadding]
  size = flex()
  padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
  children = [
    {
      size = static [hdpx(453), flex()]
      flow = FLOW_VERTICAL
      children = [
        {
          size = flex()
          valign = ALIGN_BOTTOM
          children = mainObjective
        }
        static { size = [flex(), flex(2)]}
      ]
    }
    {
      size = static [sw(100), hdpx(180) + fsh(6)]
      valign = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
      children = [
        mkTips()
        loadingWatch
      ]
    }
  ]
}

let loadingComp = {value = simpleLoading}
let loadingUiGeneration = Watched(0)

function setLoadingComp(val){
  loadingComp.value = val
  loadingUiGeneration.modify(@(v) v+1)
}

let showLoading = Computed(@() levelIsLoading.get() || dbgLoading.get())

let loadingUI = @() {
  watch = static [levelIsLoading, showLoading]
  size = flex()
  children = showLoading.get() ? loadingComp.value : null
}

return {loadingUI, setLoadingComp, showLoading, dbgLoading}
