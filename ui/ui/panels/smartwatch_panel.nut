from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/hud/compass/mk_compass_strip.nut" as mkCompassStrip
import "math" as math

from "%ui/helpers/timers.nut" import mkCountdownTimer
from "%ui/hud/menus/components/damageModel.nut" import miniBodypartsPanel
from "%ui/hud/player_info/affects_widget.nut" import mkWatchfaceAffectsWidget
from "%ui/hud/player_info/player_vitality_panel.nut" import mkVitalityPanel
from "%ui/hud/state/am_storage_state.nut" import heroAmValue, heroAmMaxValue
from "%ui/hud/state/watched_hero.nut" import watchedHeroEid
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import getCurrentHeroEffectModsQuery
from "dagor.random" import rnd_int
from "dasevents" import EventDesiredHeroIrqHappened, EventGameTrigger, broadcastNetEvent
from "net" import get_sync_time

let { assistantSpeakingScript } = require("%ui/hud/state/notes.nut")
let { shuffle } = require("%sqstd/rand.nut")
let { loudNoiseLevel } = require("%ui/hud/player_info/loud_noise_ui.nut")
let corticalVaultCompassItems = require("%ui/hud/compass/compass_cortical_vault.nut")
let { mkCompassAssistantPoints } = require("%ui/hud/compass/compass_assistant_points.nut")
let compassNexusPortals = require("%ui/hud/compass/compass_nexus_beacons.nut")
let teammatesCompass = require("%ui/hud/compass/compass_teammates.nut")
let airdropCompass = require("%ui/hud/compass/compass_airdrop.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")
let { levelLoaded } = require("%ui/state/appState.nut")
let { handStaminaPanel } = require("%ui/hud/player_info/hand_stamina.nut")
let { breathPanel } = require("%ui/hud/player_info/breath.nut")
let { heartbeatPanel } = require("%ui/hud/player_info/heartrate.nut")

#allow-auto-freeze

let smartwatchCircleSectionsScale = Watched([])
let smartwatchCircleSectionsOpacity = Watched([])
let smartwatchCircleSectionsMaxOpacity = Watched(1.0)
let loadingProcess = Watched(1.0)
let loadingInProgress = Computed(@() loadingProcess.get() < 1.0)

const quadCount = 60
const sectionCalmScale = 0.3
smartwatchCircleSectionsScale.set(array(quadCount, sectionCalmScale))
smartwatchCircleSectionsOpacity.set(array(quadCount, smartwatchCircleSectionsMaxOpacity.get()))

smartwatchCircleSectionsMaxOpacity.subscribe(function(maxOp) {
  smartwatchCircleSectionsOpacity.get().apply(@(v) min(maxOp, v))
})

function unhideAll() {
  smartwatchCircleSectionsOpacity.mutate(function(v) {
    local loadingCount = smartwatchCircleSectionsOpacity.get().len() * loadingProcess.get().tofloat()
    if (loadingCount == 0)
      loadingCount = smartwatchCircleSectionsOpacity.get().len()
    for (local i = 0; i < loadingCount; i++) {
      v[i] = smartwatchCircleSectionsMaxOpacity.get()
    }
  })
}

loadingProcess.subscribe(function(loading) {
  if (loading >= 1.0) {
    gui_scene.clearTimer("SmartwatchLoading")
    unhideAll()
    return
  }
  let loadingCount = smartwatchCircleSectionsOpacity.get().len() * loading
  if (loadingCount == 0)
    return
  smartwatchCircleSectionsOpacity.mutate(function(opacity) {
      opacity.apply(function(v, idx) {
        return idx > loadingCount ? 0.0 : v > 0.9 ? smartwatchCircleSectionsMaxOpacity.get() : v
      })
      opacity[loadingCount] = smartwatchCircleSectionsMaxOpacity.get()
  })
})

function hideSections(count) {
  local idxs = array(smartwatchCircleSectionsOpacity.get().len(), 0.0).apply(@(_, idx) idx)
  idxs = shuffle(idxs)

  smartwatchCircleSectionsOpacity.mutate(function(interference) {
    for (local i = 0; i < count; i++) {
      interference[ idxs[i] ] = 0.0
    }
  })
}

function interferenceSectionsCount(lvl) {
  let maxLevelSectionsHided = smartwatchCircleSectionsOpacity.get().len() * 0.75
  return maxLevelSectionsHided * lvl
}

function applySmartwatchInterferenceLevel(lvl) {
  gui_scene.clearTimer("SmartwatchInterferenceTimer")
  gui_scene.clearTimer("SmartwatchInterferenceScreenBlinkTimer")
  if (lvl == 0.0) {
    unhideAll()
    return
  }

  let sectionsToHide = interferenceSectionsCount(lvl)

  let maxPeriod = 1.0
  let minPeriod = 0.1
  let currentFreq = minPeriod + ( (maxPeriod - minPeriod) * (1.0 - lvl) )

  gui_scene.setInterval(currentFreq, function() {
    unhideAll()
    hideSections(sectionsToHide)
  }, "SmartwatchInterferenceTimer")

  gui_scene.setInterval(currentFreq, @() anim_start("smartwatchScreenBlink"), "SmartwatchInterferenceScreenBlinkTimer")
}

function interferenceBlink(lvl) {
  let sectionsToHide = interferenceSectionsCount(lvl)
  hideSections(sectionsToHide)
  gui_scene.resetTimeout(0.2, unhideAll, "SmartwatchBlinkEnd")
}

local loadingCoundownTimerTime = 0.0
let loadingCoundownTimerTimeWatch = Watched(0)
let loadingCountdownTimer = mkCountdownTimer(loadingCoundownTimerTimeWatch)

loadingCountdownTimer.subscribe(function(v) {
  let progress = 1 - v / loadingCoundownTimerTime;
  loadingProcess.set(progress)
  if (progress >= 1.0) {
    broadcastNetEvent(EventGameTrigger({
      source=ecs.INVALID_ENTITY_ID,
      triggerHash=ecs.calc_hash("onboarding_smartwatch_loading_finished"),
      target=ecs.INVALID_ENTITY_ID
    }))
  }
})

function startLoadingAnimation(loadingTime) {
  loadingCoundownTimerTime = loadingTime
  loadingProcess.set(0.0)
  loadingCoundownTimerTimeWatch.set(get_sync_time() + loadingTime)
}

ecs.register_es("smartwatch_loading_es",
  {
    [EventDesiredHeroIrqHappened] = function(_eid, _comp) {
      startLoadingAnimation(6.0)
    },
  },
  {
    comps_rq = [["smartwatch_loading"]]
  },
  { tags = "gameClient" }
)

ecs.register_es("smartwatch_interference_track",
  {
    [EventDesiredHeroIrqHappened] = function(_eid, _comp) {
      interferenceBlink(0.7)
    },
    ["onChange"] = function(_eid, comp) {
      applySmartwatchInterferenceLevel(comp.smartwatchInterference)
      smartwatchCircleSectionsMaxOpacity.set(comp.smartwatchScreenOpacity)
    }
  },
  {
    comps_track = [["smartwatchInterference", ecs.TYPE_FLOAT], ["smartwatchScreenOpacity", ecs.TYPE_FLOAT]]
  },
  { tags = "gameClient" }
)


ecs.register_es("smartwatch_show_loading",
  {
    function onInit(_eid, _comp){
      loadingProcess.set(0.0)
    }
    function onDestroy(_eid, _comp) {
      loadingProcess.set(1.0)
    }
  },
  {
    comps_rq = [["onboarding_monolith_smartwatch__startWithLoading"]]
  },
  { tags = "gameClient" }
)

let amGathererTickInterval = Watched(1)
let amGathererTickAt = Watched(0)
ecs.register_es("resources_gatherer_active_ui_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      if (comp["resources_gatherer_device__ownerEid"] == watchedHeroEid.get()) {
        let speedMult = getCurrentHeroEffectModsQuery.perform(@(_eid, comps) comps.entity_mod_values.getAll()?["activeMatterGatherSpeed"].value ?? 1)
        amGathererTickInterval.set(comp["resources_gatherer_device__tickInterval"] / speedMult)
        amGathererTickAt.set(comp["resources_gatherer_device__tickAt"])
      }
    },
    onDestroy = function(_eid, comp){
      if (comp["resources_gatherer_device__ownerEid"] == watchedHeroEid.get() || watchedHeroEid.get() == ecs.INVALID_ENTITY_ID)
        amGathererTickAt.set(0)
    }
  },
  {
    comps_track = [["resources_gatherer_device__tickAt", ecs.TYPE_FLOAT]]
    comps_ro = [
      ["resources_gatherer_device__tickInterval", ecs.TYPE_FLOAT],
      ["resources_gatherer_device__ownerEid", ecs.TYPE_EID]
    ]
  },
  { tags = "gameClient" }
)


console_register_command(
  @(level) applySmartwatchInterferenceLevel(level),
  "smartwatch.setInterferenceLevel"
)

console_register_command(
  @(loadingTIme) startLoadingAnimation(loadingTIme),
  "smartwatch.setLoading"
)

console_register_command(
  @() interferenceBlink(0.7),
  "smartwatch.tap_tap"
)

let mkDynamicText = @(text, fontSize) {
  validateStaticText = false
  font = Fonts.system
  rendObj = ROBJ_INSCRIPTION
  fontSize
  text
}

function mkInterferenceableSymbol(stringChar, idx, customHdpx) {
  let opacityComp = Computed(@() smartwatchCircleSectionsOpacity.get()?[idx] ?? 1.0)
  return @() {
    watch = opacityComp
    children = mkDynamicText(stringChar, customHdpx(18))
    opacity = opacityComp.get()
    transitions = [
      { prop = AnimProp.opacity, duration = 0.0, easing = Linear }
    ]
  }
}

function mkInterferenceableText(text, customHdpx) {
  let children = []
  let digitsCount = 3

  for (local i = 0; i < text.len(); i++) {
    children.append(mkInterferenceableSymbol(text.slice(i,i+1),  digitsCount + i, customHdpx))
  }
  return {
    flow = FLOW_HORIZONTAL
    gap = customHdpx(2)
    children
  }
}

let mkInterferenceableDigits = @(customHdpx)
  function (){
    let number = (loadingProcess.get() * 100).tointeger()
    function mkRandDigit(idx) {
      let changeDigit = Computed(@()smartwatchCircleSectionsOpacity.get()?[idx])
      return @() {
        watch = [ changeDigit, smartwatchCircleSectionsMaxOpacity ]
        children = mkDynamicText(rnd_int(0, 9), customHdpx(20))
        opacity = smartwatchCircleSectionsMaxOpacity.get()
        key = $"SmartWatchRandDigit{idx}"
      }
    }
    let children = []

    if (number == 0) {
      for (local i = 0; i < 3; i++) {
        children.append(mkRandDigit(i))
      }
    }
    else {
      let first = number / 100
      let second = number % 100 / 10
      let third = number % 10
      if (first > 0)
        children.append(mkInterferenceableSymbol(first, 0, customHdpx))
      if (second > 0)
        children.append(mkInterferenceableSymbol(second, 1, customHdpx))
      if (third > 0)
        children.append(mkInterferenceableSymbol(third, 2, customHdpx))
    }

    return {
      flow = FLOW_HORIZONTAL
      gap = customHdpx(4)
      children = children
      watch = loadingProcess
    }
  }

let loadingScreen = @(customHdpx) @(){
  watch = loadingInProgress
  flow = FLOW_VERTICAL
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = loadingInProgress.get() ? [
    mkInterferenceableText(loc("smartwatch/loading"), customHdpx)
    mkInterferenceableDigits(customHdpx)
  ] : null
}

let background = @(radius) @() {
  rendObj = ROBJ_MASK
  image = Picture($"ui/uiskin/white_circle.svg:{0}:{0}:P".subst(radius))
  size = flex()
  children = {
    size = flex()
    rendObj = ROBJ_SOLID
    color = Color(0, 0, 0, 255)
    transform = {}
    animations = [
      { prop=AnimProp.color, from=Color(27, 34, 27, 255), to=Color(40, 60, 40, 255),
        duration=0.2, play=false, easing=@(v) v, loop=false, trigger="smartwatchScreenBlink" }
    ]
  }
}

let blurredBackground = @(rad) {
  rendObj = ROBJ_MASK
  image = Picture($"ui/uiskin/white_circle.svg:{0}:{0}:P".subst(rad))
  size = flex()
  children = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = flex()
  }
}

let bodyparts = @(customHdpx=hdpx) @() {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = miniBodypartsPanel(customHdpx)
  pos = [ customHdpx(23), -customHdpx(4) ]
}

function indicators(customHdpx, override = {}) {
  return @() {
    watch = [ hideHud, loadingInProgress, amGathererTickAt ]
    size = flex()
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    gap = customHdpx(5)
    pos = [customHdpx(5), 0]
    children = hideHud.get() || !levelLoaded.get() || (amGathererTickAt.get() > 0) ? null : [
      {
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        halign = ALIGN_LEFT
        flow = FLOW_VERTICAL
        pos = [ -customHdpx(29), 0 ]
        gap = customHdpx(5)
        children = mkVitalityPanel([
          heartbeatPanel
          handStaminaPanel
          breathPanel
        ], customHdpx, override)
      }
      bodyparts(customHdpx)
    ]
  }
}


let amCompFontSize = 32
function amComp(customHdpxi = hdpxi) {
  return @() {
    watch = [heroAmValue, amGathererTickAt]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex()
    children = (amGathererTickAt.get() > 0) ? {
      rendObj = ROBJ_TEXT
      font = Fonts.system
      pos = [0, customHdpxi(40)]
      fontSize = customHdpxi(amCompFontSize)
      text = $"{heroAmValue.get()}"
    } : null
  }
}


let watchfaceDasScript = load_das("%ui/panels/watchface.das")

function mkWatchface(radius){
  return @(){
    size = [2 * radius, 2 * radius]
    watch = [loudNoiseLevel, assistantSpeakingScript, amGathererTickAt, amGathererTickInterval, heroAmValue, heroAmMaxValue]
    rendObj = ROBJ_DAS_CANVAS
    script = watchfaceDasScript
    setupFunc = "setup_data"
    drawFunc = "draw_watchface"
    loudness = loudNoiseLevel.get()
    speech = assistantSpeakingScript.get() != null
    amGathererTickInterval = amGathererTickInterval.get()
    amGathererTickAt = amGathererTickAt.get()
    amStorageFull = heroAmMaxValue.get() <= heroAmValue.get()
  }
}

let copmassStrips = @(radius) @() {
  watch = levelLoaded
  children = mkCompassStrip({
    compassObjects = [mkCompassAssistantPoints(), corticalVaultCompassItems, teammatesCompass, compassNexusPortals, airdropCompass],
    diameter=radius * 2,
    override = levelLoaded.get() ? {} : {
      transform = {}
      animations = [{ prop = AnimProp.rotate, from = 0, to = 360, duration = 8, play = true, loop = true }]
    }
  })
}

let smartwatchUiPx = 90
let mkSmartwatchUi = @(radius = hdpx(smartwatchUiPx)){
  size = flex()
  children = [
    blurredBackground(radius)
    mkWatchface(radius)
    indicators(hdpxi)
    copmassStrips(radius)
    amComp(hdpxi)
    mkWatchfaceAffectsWidget(radius)
  ]
}

function mkSmartwatch(radius) {
  let ratio = 1
  let customHdpx = @(v) v * ratio
  return {
    size = flex()
    children = [
      background(radius)
      loadingScreen(customHdpx)
      mkWatchface(radius)
      indicators(customHdpx)
      amComp(customHdpx)
    ]
  }
}

function mkSmartwatchOnboardingInitializationPanel(canvasSize, data, _=null) {
  return {
    
    worldAnchor   = PANEL_ANCHOR_ENTITY
    worldGeometry = PANEL_GEOMETRY_RECTANGLE
    canvasSize

    
    size = [canvasSize[0], canvasSize[1]]
    color = Color(0,0,0,255)
    children = [
      mkSmartwatch(canvasSize[0] / 2)
    ]
  }.__merge(data)
}

return {
  mkSmartwatchOnboardingInitializationPanel
  mkSmartwatch
  mkSmartwatchUi
  indicators
}
