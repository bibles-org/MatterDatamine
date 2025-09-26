from "%ui/mainMenu/audioModule/music_player.nut" import startPlayer, stopPlayer, LoopStatus, musicPlayerVolumeSet,
  musicPlayerSetVolume, playOnlyFreeStreamingMusicWatch, playOnlyFreeStreamingMusicSet
from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import panelRowColor, BtnBgHover, BtnTextNormal
from "%ui/components/commonComponents.nut" import mkTextArea, bluredPanel
from "dasevents" import EventSpawnSequenceEnd
from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData
from "%ui/mainMenu/menus/options/miss_second_map_help.nut" import missSecondMapHelp
import "%ui/mainMenu/menus/options/optionLabel.nut" as optionLabel
from "%ui/mainMenu/menus/options/options_lib.nut" import optionCtor, optionCheckBox, optionPercentTextSliderCtor
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let rand = require("%sqstd/rand.nut")()
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { playingSound, trackList, playerLoopState, loopOrder, musicPlayerVolumeWatch } = require("%ui/mainMenu/audioModule/music_player.nut")

const SETTINGS_TAB_ID = "settingsAudio"
const MUSIC_ON_BASE_SETTING = "isMusicOnBaseOn"
const MUSIC_IN_RAIDS_SETTING = "isMusicInRaidsOn"

let playMusicOnBaseStorage = mkOnlineSaveData(MUSIC_ON_BASE_SETTING, @() true)
let playMusicOnBaseWatch = playMusicOnBaseStorage.watch
let playMusicOnBaseSet = playMusicOnBaseStorage.setValue

let playMusicInRaidsStorage = mkOnlineSaveData(MUSIC_IN_RAIDS_SETTING, @() false)
let playMusicInRaidsWatch = playMusicInRaidsStorage.watch
let playMusicInRaidsSet = playMusicInRaidsStorage.setValue

function playMusicOnBase(playOnBase = null) {
  let isPlayOnBase = playOnBase ?? playMusicOnBaseWatch.get()
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
    && playingSound.get() == null
  if (!needToPlay)
    return

  if (playingSound.get() != null) {
    startPlayer(playingSound.get())
    return
  }

  let list = trackList.get()
  let randTrackIdx = rand.rint(0, list.len() - 1)
  local trackIdx = null
  local trackFound = false
  for (local i = randTrackIdx; i <= list.len(); i++) {
    let newIdx = (randTrackIdx + list.len() + i) % list.len()
    if (list?[newIdx] == null)
      continue
    let restricted = list[newIdx].isStreamRestricted && (isStreamerMode.get() || playOnlyFreeStreamingMusicWatch.get())
    
    if (!restricted) { 
      trackIdx = newIdx
      trackFound = true
      break
    }
  }
  if (!trackFound || trackIdx == null)
    return
  playerLoopState.set(loopOrder[LoopStatus.ALL_TRACKS_LOOP])
  let track = list[trackIdx]
  startPlayer(track)
}

foreach (watch in [isOnPlayerBase, isOnboarding, trackList, playMusicOnBaseWatch]) {
  watch.subscribe_with_nasty_disregard_of_frp_update(function(_v) { playMusicOnBase() }) 
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

  if (playingSound.get() != null) {
    startPlayer(playingSound.get())
    return
  }

  let list = trackList.get()
  let randTrackIdx = rand.rint(0, list.len() - 1)
  local trackIdx = null
  local trackFound = false
  for (local i = randTrackIdx; i <= list.len(); i++) {
    let newIdx = (randTrackIdx + list.len() + i) % list.len()
    if (list?[newIdx] == null)
      continue
    let restricted = list[newIdx].isStreamRestricted && (isStreamerMode.get() || playOnlyFreeStreamingMusicWatch.get())
    
    if (!restricted) { 
      trackIdx = newIdx
      trackFound = true
      break
    }
  }
  if (!trackFound || randTrackIdx == null)
    return
  playerLoopState.set(loopOrder[LoopStatus.ALL_TRACKS_LOOP])
  let track = list[trackIdx]
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
  tab = "Sound"
  widgetCtor = optionCheckBox
  valToString = @(v) (v ? loc("option/on") : loc("option/off"))
})

let playMusicOnBaseSetting = optionCtor({
  name = loc("musicPlayer/musicOnBase")
  setValue = function(v) {
    playMusicOnBaseSet(v)
    playMusicOnBase(v)
  }
  tab = "Sound"
  var = playMusicOnBaseWatch
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  valToString = @(v) (v ? loc("option/on") : loc("option/off"))
})

let playFreeStreamingMusicSetting = optionCtor({
  name = loc("musicPlayer/onlyFreeStreaming")
  setValue = @(v) playOnlyFreeStreamingMusicSet(v)
  var = playOnlyFreeStreamingMusicWatch
  defVal = true
  tab = "Sound"
  widgetCtor = optionCheckBox
  valToString = @(v) (v ? loc("option/on") : loc("option/off"))
})

function optionRowContainer(children) {
  let stateFlags = Watched(0)
  return @() {
    watch = stateFlags
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onElemState = @(sf) stateFlags.set(sf)
    skipDirPadNav = true
    children
    rendObj = ROBJ_BOX
    margin = static [0, fsh(8)]
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
    padding = static [0, hdpx(12)]
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
  size = static [flex(), hdpx(2)]
  margin = static [hdpx(10),0,hdpx(2),0]
  color = BtnTextNormal
}

let missSecondOptionsBlock = {
  size = FLEX_H
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
  tab = "Sound"
  min = 0.0 max = 2.0 unit = 0.1 pageScroll = 0.1
  restart = false
  mult = 50
  valToString = @(v) v * 50
})

let playerOptionsBlock = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = optionBlockSeparator
  children = [
    mkTextArea(loc("musicPlayer"), body_txt)
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        makeOptionRow(playerMusicVolumeSetting)
        makeOptionRow(playMusicOnBaseSetting)
        makeOptionRow(playMusicInRaidsSetting)
        makeOptionRow(playFreeStreamingMusicSetting)
      ]
    }
  ]
}

let settingsTabUi = {
  size = FLEX_H
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
  playOnlyFreeStreamingMusicWatch
  playerMusicVolumeSetting
  playMusicOnBaseSetting
  playMusicInRaidsSetting
  playFreeStreamingMusicSetting
}