import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { body_txt } = require("%ui/fonts_style.nut")
let { panelRowColor, BtnBgHover, BtnTextNormal } = require("%ui/components/colors.nut")
let { mkTextArea, bluredPanel } = require("%ui/components/commonComponents.nut")
let rand = require("%sqstd/rand.nut")()
let { EventSpawnSequenceEnd } = require("dasevents")
let { mkOnlineSaveData } = require("%ui/options/mkOnlineSaveData.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { missSecondMapHelp } = require("%ui/mainMenu/menus/options/miss_second_map_help.nut")
let { startPlayer, stopPlayer, playingSound, trackList, playerLoopState, loopOrder, LoopStatus,
  musicPlayerVolumeWatch, musicPlayerVolumeSet, musicPlayerSetVolume } = require("music_player.nut")
let optionLabel = require("%ui/mainMenu/menus/options/optionLabel.nut")
let { optionCtor, optionCheckBox, optionPercentTextSliderCtor } = require("%ui/mainMenu/menus/options/options_lib.nut")

const SETTINGS_TAB_ID = "settingsAudio"
const MUSIC_ON_BASE_SETTING = "isMusicOnBaseOn"
const MUSIC_IN_RAIDS_SETTING = "isMusicInRaidsOn"

let playMusicOnBaseStorage = mkOnlineSaveData(MUSIC_ON_BASE_SETTING, @() true)
let playMusicOnBaseWatch = playMusicOnBaseStorage.watch
let playMusicOnBaseSet = playMusicOnBaseStorage.setValue

let playMusicInRaidsStorage = mkOnlineSaveData(MUSIC_IN_RAIDS_SETTING, @() false)
let playMusicInRaidsWatch = playMusicInRaidsStorage.watch
let playMusicInRaidsSet = playMusicInRaidsStorage.setValue

function playMusicOnBase(isPlayOnBase = playMusicOnBaseWatch.get()) {
  let needToStop = ((isOnPlayerBase.get() && !isPlayOnBase) || isOnboarding.get())
    && playingSound.get() != null

  if (needToStop) {
    stopPlayer(playingSound.get())
    return
  }

  let needToPlay = isOnPlayerBase.get()
    && isPlayOnBase
    && !isOnboarding.get()
    && (trackList.get()?.len() ?? 0) > 0
  if (!needToPlay)
    return

  let trackIdx = rand.rint(0, trackList.get().len() - 1)
  playerLoopState.set(loopOrder[LoopStatus.ALL_TRACKS_LOOP])
  let track = trackList.get()[trackIdx]
  startPlayer(track)
}

foreach (watch in [isOnPlayerBase, isOnboarding, trackList]) {
  watch.subscribe(function(_v) { playMusicOnBase() })
}

function playMusicInRaids(isPlayInRaids = playMusicInRaidsWatch.get()) {
  let needToStop = ((!isOnPlayerBase.get() && !isPlayInRaids) || isOnboarding.get())
    && playingSound.get() != null

  if (needToStop) {
    stopPlayer(playingSound.get())
    return
  }

  let needToPlay = isInBattleState.get()
    && isPlayInRaids
    && !isOnboarding.get()
    && (trackList.get()?.len() ?? 0) > 0
  if (!needToPlay)
    return

  let trackIdx = rand.rint(0, trackList.get().len() - 1)
  playerLoopState.set(loopOrder[LoopStatus.ALL_TRACKS_LOOP])
  let track = trackList.get()[trackIdx]
  startPlayer(track)
}

ecs.register_es("start_play_music_on_spawn_es",
  {[EventSpawnSequenceEnd] = @(...) playMusicInRaids()},
  {comps_rq = ["watchedByPlr"]}
)

let playMusicInRaidsSetting = optionCtor({
  name = loc("musicPlayer/musicInRaids")
  setValue = function(v) {
    playMusicInRaidsSet(v)
    playMusicInRaids(v)
  }
  var = playMusicInRaidsWatch
  defVal = false
  widgetCtor = optionCheckBox
  valToString = @(v) (v ? loc("option/on") : loc("option/off"))
})

let playMusicOnBaseSetting = optionCtor({
  name = loc("musicPlayer/musicOnBase")
  setValue = function(v) {
    playMusicOnBaseSet(v)
    playMusicOnBase(v)
  }
  var = playMusicOnBaseWatch
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  valToString = @(v) (v ? loc("option/on") : loc("option/off"))
})


function optionRowContainer(children) {
  let stateFlags = Watched(0)
  return @() {
    watch = stateFlags
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onElemState = @(sf) stateFlags(sf)
    skipDirPadNav = true
    children
    rendObj = ROBJ_BOX
    margin = [0, fsh(8)]
    fillColor = stateFlags.get() & S_HOVER ? Color(60, 60, 70, 150) : panelRowColor
    borderWidth = stateFlags.get() & S_HOVER ? [hdpx(2), 0] : 0
    borderColor = BtnBgHover
    gap = fsh(2)
  }
}

function makeOptionRow(opt) {
  let group = ElemGroup()
  let xmbNode = XmbNode()

  let widget = opt.widgetCtor(opt, group, xmbNode)
  if (!widget)
    return {}

  let baseHeight = fsh(4.8)
  let height = baseHeight
  let label = optionLabel(opt, group)

  let row = {
    padding = [0, hdpx(12)]
    size = [flex(), height]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = fsh(2)
    children = [
      label
      widget
    ]
  }

  return optionRowContainer(row)
}

let optionBlockSeparator = {
  rendObj = ROBJ_SOLID
  size = [flex(), hdpx(2)]
  margin = [hdpx(10),0,hdpx(2),0]
  color = BtnTextNormal
}

let missSecondOptionsBlock = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap  = optionBlockSeparator
  children = [
    mkTextArea(loc("options/miss_second"), body_txt)
    makeOptionRow(missSecondMapHelp)
  ]
}

let playerMusicVolumeSetting = optionCtor({
  name = loc("musicPlayer/musicVolume")
  widgetCtor = optionPercentTextSliderCtor
  defVal = musicPlayerVolumeWatch.get()
  var = musicPlayerVolumeWatch
  setValue = function(v) {
    musicPlayerVolumeSet(v)
    musicPlayerSetVolume(v)
  }
  min = 0.0 max = 2.0 unit = 0.1 pageScroll = 0.1
  restart = false
  mult = 50
  valToString = @(v) v * 50
})

let playerOptionsBlock = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = optionBlockSeparator
  children = [
    mkTextArea(loc("musicPlayer"), body_txt)
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        makeOptionRow(playerMusicVolumeSetting)
        makeOptionRow(playMusicOnBaseSetting)
        makeOptionRow(playMusicInRaidsSetting)
      ]
    }
  ]
}

let settingsTabUi = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(20)
  padding = hdpx(20)
  halign = ALIGN_CENTER
  children = [
    missSecondOptionsBlock
    playerOptionsBlock
  ]
}.__update(bluredPanel)

return {
  settingsTabUi
  SETTINGS_TAB_ID
}