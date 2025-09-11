from "%dngscripts/globalState.nut" import nestWatched
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/commonComponents.nut" import mkText, bluredPanel, mkTextArea, mkSelectPanelItem, mkSelectPanelTextCtor, BD_LEFT
from "%ui/components/scrollbar.nut" import makeVertScroll
import "%ui/components/faComp.nut" as faComp
from "%ui/components/button.nut" import button
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/helpers/time.nut" import secondsToString
from "%ui/components/slider.nut" import Vert
from "%ui/components/cursors.nut" import setTooltip
from "dasevents" import EventUnlockAppear, CmdMusicPlayerPlay, CmdMusicPlayerStop
from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData
from "%ui/mainMenu/notificationMark.nut" import mkNotificationCircle
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBgNormal, BtnBgHover, BtnBgSelected, TextNormal, BtnBgFocused

let { playerStats } = require("%ui/profile/profileState.nut")

enum SoundStatus {
  SOUND_PLAY = "play"
  SOUND_STOP = "stop"
  SOUND_PAUSE = "pause"
}

enum LoopStatus {
  NO_LOOP
  ALL_TRACKS_LOOP
  ONE_TRACK_LOOP
}

const MUSIC_PLAYER_ID = "musicPlayerId"
const MUSIC_PLAYER_VOLUME = "musicPlayerVolume"

let playingSound = nestWatched("playingSound", null)
let soundHandle = nestWatched("soundHandle", null)
let unseenTracksCount = nestWatched("unseenTracksCount", 0)
let unseenTracks = nestWatched("unseenTracks", {})
let isPlaying = nestWatched("isMusicPlaying", false)
let soundLength = nestWatched("soundLength", 0)
let newUnlocksSongList = nestWatched("newUnlocksSongList", [])
let lastPlayed = Watched(null)

let musicPlayerVolumeStorage = mkOnlineSaveData(MUSIC_PLAYER_VOLUME, @() 1)
let musicPlayerVolumeWatch = musicPlayerVolumeStorage.watch
let musicPlayerVolumeSet = musicPlayerVolumeStorage.setValue

let loopOrder = [
  {
    hintLocId = "musicPlayer/noLoop"
    status = LoopStatus.NO_LOOP
  }
  {
    hintLocId = "musicPlayer/loopAll"
    status = LoopStatus.ALL_TRACKS_LOOP
  }
  {
    hintLocId = "musicPlayer/loopOne"
    status = LoopStatus.ONE_TRACK_LOOP
  }
]

let playerLoopState = nestWatched("playerLoopState", loopOrder[0])
playerLoopState.set(loopOrder[0])

ecs.register_es("check_sound_pos_length_es", {
  onChange = function(_eid, comp) {
    soundLength.set(comp.music_player__trackLength / 1000)
  }
}, { comps_track = [
    ["music_player__trackLength", ecs.TYPE_INT]
  ]
}, { tags="sound" })

ecs.register_es("CmdMusicPlayerStop", {
  [CmdMusicPlayerStop] = function(_eid, _comp) {
    playingSound.set(null)
    soundHandle.set(SoundStatus.SOUND_STOP)
    soundLength.set(0)
  }
}, {}, { tags="sound" })

let musicPlayerSetVolumeQuery = ecs.SqQuery("musicPlayerSetSoundVolumeQuery", {
  comps_rw = [
    ["music_player__volume", ecs.TYPE_FLOAT]
  ]
})
let musicPlayerSetVolume = @(v) musicPlayerSetVolumeQuery.perform(@(_eid, comps) comps.music_player__volume = v.tofloat())

let musicPlayerGetCurPos = ecs.SqQuery("musicPlayerGetCurPos", { comps_ro = [["music_player__pos", ecs.TYPE_INT]]})
let getCurTrackPos = @() musicPlayerGetCurPos.perform(@(_eid, comps) comps.music_player__pos) ?? 0

function soundPlay(soundData) {
  if (playingSound.get()?.soundTrack==soundData?.soundTrack)
    return
  musicPlayerSetVolume(musicPlayerVolumeWatch.get())
  playingSound.set(soundData)
  soundHandle.set(SoundStatus.SOUND_PLAY)
  ecs.g_entity_mgr.broadcastEvent(CmdMusicPlayerPlay({
    track = soundData.soundTrack
    pos = 0
  }))
}

function soundStop(soundData=null) {
  if (soundData)
    lastPlayed.set(soundData)
  ecs.g_entity_mgr.broadcastEvent(CmdMusicPlayerStop())
}

let getTrack = memoize(function(unlockName) {
  if (!unlockName.startswith("item_audio"))
    return null

  local template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(unlockName)
  if (template == null) {
    let start = "item_audio_".len()
    template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(unlockName.slice(start))
  }
  let soundTrack = template?.getCompValNullable("soundTrack")
  if (soundTrack == null)
    return null
  return {
    pickup_unlock__name = template?.getCompValNullable("pickup_unlock__name")
    item__proto = template?.getCompValNullable("item__proto")
    author = template?.getCompValNullable("author")
    soundTrack
  }
})

let trackList = Computed(function() {
  let list = [].extend(playerStats.get()?.unlocks ?? []).extend(newUnlocksSongList.get())
  let res = []
  if (list.len() <= 0)
    return res
  foreach (k in list) {
    let track = getTrack(k)
    if (track==null || res.findvalue(@(v) v?.soundTrack == track?.soundTrack) != null)
      continue
    res.append(track)
  }
  return res.filter(@(v) v!=null).sort(@(a,b) a.item__proto <=> b.item__proto)
})

function playNextLoopTrack() {
  let sound = playingSound.get()
  let status = playerLoopState.get().status
  let list = trackList.get()
  if (status == LoopStatus.NO_LOOP) {
    let curTrackIdx = list.findindex(@(v) v.soundTrack == sound.soundTrack) ?? 0
    if (list?[curTrackIdx + 1] != null)
      soundPlay(list[curTrackIdx + 1])
    else
      soundStop(sound)
  }
  else if (status == LoopStatus.ONE_TRACK_LOOP)
    soundPlay(sound)
  else {
    let curSoundIdx = trackList.get().findindex(@(v) v?.soundTrack == sound?.soundTrack) ?? 0
    let nextIdx = (curSoundIdx + 1) % trackList.get().len()
    soundPlay(trackList.get()[nextIdx])
  }
}

ecs.register_es("check_sound_is_playing_es", {
    onChange = function(_eid, comp) {
      isPlaying.set(comp.music_player__isPlaying)
      if (!comp.music_player__isPlaying && playingSound.get() != null)
        playNextLoopTrack()
    }
  },
  { comps_track=[["music_player__isPlaying", ecs.TYPE_BOOL]] },
  { tags="sound" }
)

ecs.register_es("track_new_audios_es",
  { [EventUnlockAppear] = function(evt, _eid, _comp) {
      if (!evt.unlockName.startswith("item_audio"))
        return
      if (trackList.get().findvalue(@(v) v?.pickup_unlock__name == evt.unlockName) != null)
        return
      newUnlocksSongList.mutate(@(v) v.append(evt.unlockName))
      unseenTracks.mutate(@(v) v[evt.unlockName] <- true )
      unseenTracksCount.modify(@(v) v + 1)
    }
  }
  { comps_rq = ["player"] }
  { tags = "gameClient" }
)

function changeLoopState() {
  let curLoop = playerLoopState.get()
  let curLoopIdx = loopOrder.findindex(@(v) v.status == curLoop.status) ?? 0
  let nexIdx = (curLoopIdx + 1) % loopOrder.len()
  playerLoopState.set(loopOrder[nexIdx])
}

let loopBtnStateFlags = Watched(0)

let buttonIconHeight = hdpxi(20)
let playIconSize = hdpxi(55)

let mkNotesIcon = memoize(@(iconSize) {
  rendObj = ROBJ_IMAGE
  size = iconSize
  color = TextNormal
  image = Picture("!ui/skin#def_audio_icon.svg:{0}:{0}:K".subst(iconSize[0]))
})

let playIcon = faComp("play", { vplace = ALIGN_CENTER pos = [hdpx(2), 0] fontSize = buttonIconHeight })
let stopIcon = faComp("stop", { vplace = ALIGN_CENTER fontSize = buttonIconHeight})
let startPlayer = function(soundData) { soundPlay(soundData) }
let stopPlayer = function(soundData) {
  if (soundData==null)
    return
  soundStop(soundData)
}

let mkPlayButton = @(soundData) @() {
  watch = playingSound
  children = button({
    size = [playIconSize, playIconSize]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = playIcon
  }, function() {
    if (soundData == null) {
      if (lastPlayed.get() != null) {
        let hasLastPlayed = trackList.get().findvalue(@(v) v.soundTrack == lastPlayed.get()?.soundTrack)
        if (hasLastPlayed) {
          startPlayer(lastPlayed.get())
          return
        }
      }
      else if (trackList.get().len() > 0)
        startPlayer(trackList.get()[0])
      else
        showMsgbox({ text = loc("musicPlayer/chooseSound") })
      return
    }
    startPlayer(soundData)
  }, {
    onHover = @(on) setTooltip(on ? loc("musicPlayer/play") : null)
    style = { BtnBgNormal = playingSound.get() ? BtnBgSelected : BtnBgNormal }
  })
}

let mkStopButton = @(soundData) button({
  size = [playIconSize, playIconSize]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = stopIcon
}, @() stopPlayer(soundData), {
  onHover = @(on) setTooltip(on ? loc("musicPlayer/stop") : null)
})

let mkDeltaButton = @(delta) button({
  size = [playIconSize, playIconSize]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = faComp(delta > 0 ? "forward" : "backward" , {
    vplace = ALIGN_CENTER
    transform = {}
    pos = [hdpx(2), 0]
    fontSize = buttonIconHeight
  })
}, function() {
  let list = trackList.get()
  if (list.len() <= 0) {
    showMsgbox({ text = loc("musicPlayer/noAudiosFound") })
    return
  }
  let curIdx = list.findindex(@(v) v.soundTrack == playingSound.get()?.soundTrack) ?? 0
  let newIdx = (curIdx + delta + list.len()) % list.len()
  startPlayer(list[newIdx])
}, {
  onHover = @(on) setTooltip(on ? delta > 0 ? loc("musicPlayer/next") : loc("musicPlayer/prev")
    : null)
})

let largeIconParams = {
  itemYaw = 0
  itemPitch = 0
  itemRoll = 90
}

let mkIconNoBorder = @(iconSize, item__proto, params = null) itemIconNoBorder(item__proto, {width = iconSize[0] height = iconSize[1] }.__update(params ?? {}))
let mkMkIconFromItemProto = @(iconSize, params=null) @(item__proto = null) item__proto == null
  ? mkNotesIcon(iconSize)
  : mkIconNoBorder(iconSize, item__proto, params)

let mkIconFromItemProtoSmall = mkMkIconFromItemProto([hdpxi(50), hdpxi(50)])
let boxSmallSize = [hdpxi(60), hdpxi(60)]

function mkSoundIcon(soundData, stateFlags, group) {
  let icon = mkIconFromItemProtoSmall(soundData?.item__proto)
  let soundTrack = soundData.soundTrack
  return function() {
    let sf = stateFlags.get()
    let active = (sf & S_HOVER) != 0 || (sf & S_ACTIVE) != 0
    return {
      size = boxSmallSize
      valign = ALIGN_CENTER
      watch = stateFlags
      halign = ALIGN_CENTER
      group
      children = active ? @() {
        watch = playingSound
        rendObj = ROBJ_SOLID
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = {
          rendObj = ROBJ_VECTOR_CANVAS
          size = hdpx(50)
          commands = [
            [VECTOR_FILL_COLOR, BtnBgNormal],
            [VECTOR_ELLIPSE, 50, 50, 50, 50],
          ]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = playingSound.get()?.soundTrack == soundTrack
            ? stopIcon
            : playIcon
        }
      }.__update(bluredPanel) : icon
    }
  }
}

let mkIconFromItemProtoBig = mkMkIconFromItemProto([hdpxi(230), hdpxi(230)], largeIconParams)
let mkLargeSoundIcon = @(item__proto) {
  size = hdpxi(250) valign = ALIGN_CENTER halign = ALIGN_CENTER children = mkIconFromItemProtoBig(item__proto)
}

let tracknameStyle = {hplace = ALIGN_LEFT}.__update(body_txt)
let authorStyle = {hplace = ALIGN_LEFT, opacity = 0.5}

let notificationIcon = freeze({
  size = hdpx(14)
  padding = hdpx(2)
  vplace = ALIGN_TOP
  children = mkNotificationCircle([0, 100])
})

function mkSoundRow(soundData) {
  let soundTrack = soundData?.soundTrack
  let curTrack = Computed(@() playingSound.get()?.soundTrack)
  let group = ElemGroup()
  let isUnseen = Computed(@() soundData?.pickup_unlock__name in unseenTracks.get())
  let visual_params = {
    group
    onDoubleClick = @() startPlayer(playingSound.get())
    size = FLEX_H
    padding=0,
    onHover = function(on) {
      if (on && soundData?.pickup_unlock__name in unseenTracks.get()) {
        unseenTracks.mutate(@(v) v?.$rawdelete(soundData?.pickup_unlock__name))
        unseenTracksCount.modify(@(v) v - 1)
      }
    }
    xmbNode = XmbNode()
  }
  let textTrackCompCtor = mkSelectPanelTextCtor(loc(soundData.soundTrack), tracknameStyle)
  let textAuthorCompCtor = mkSelectPanelTextCtor(loc(soundData.author), authorStyle)
  return mkSelectPanelItem({
    children = @(params) @() {
      watch = isUnseen
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      valign = ALIGN_CENTER
      padding = static [0, hdpx(4), 0, hdpx(5)]
      children = [
        mkSoundIcon(soundData, params.stateFlags, group)
        {
          behavior = Behaviors.Marquee
          scrollOnHover = true
          flow = FLOW_VERTICAL
          group
          speed = hdpx(50)
          size = FLEX_H
          children = [
            textTrackCompCtor(params)
            textAuthorCompCtor(params)
          ]
        }
        isUnseen.get() ? notificationIcon : null
      ]
    },
    idx=soundTrack
    state=curTrack
    visual_params
    onSelect = @(soundtrack) (playingSound.get()?.soundTrack == soundtrack ? stopPlayer : startPlayer)(soundData)
    border_align = BD_LEFT
  })
}

let soundsListBlock = @() {
  watch = trackList
  size = static [hdpx(377), flex()]
  children = trackList.get().len() <= 0
    ? mkTextArea(loc("musicPlayer/noAudiosFound"), {
      margin = static [hdpx(10), 0]
      padding = hdpx(10)
      halign = ALIGN_CENTER
    })
    : makeVertScroll({
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = static hdpx(2)
        xmbNode = XmbContainer({ canFocus = false, wrap = false })
        children = trackList.get().map(mkSoundRow)
      })
}.__update(bluredPanel)

let getPos = @() isPlaying.get() ? getCurTrackPos()/1000 : 0
let curTrackTime = Watched(getPos())

function mkTimeLine() {
  let setCurTrackTime = @() curTrackTime.set(getPos())
  let onAttach = function() {
    curTrackTime.set(getPos())
    gui_scene.clearTimer(setCurTrackTime)
    gui_scene.setInterval(1, setCurTrackTime)
  }
  return function() {
    let sl = soundLength.get()
    return {
      watch = [soundLength, isPlaying, playingSound]
      key = playingSound.get()
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(5)
      onAttach
      children = [
        {
          rendObj = ROBJ_SOLID
          size = static [hdpx(460), hdpx(10)]
          color = BtnBgNormal
          children = sl == 0 ? null : @() {
            rendObj = ROBJ_SOLID
            watch = curTrackTime
            size = [pw((curTrackTime.get() / sl.tofloat()) * 100), flex()]
            color = BtnBgSelected
          }
        }
        {
          size = FLEX_H
          children = [
            @() {
              watch = curTrackTime
              children = mkText(secondsToString(curTrackTime.get()))
            }
            mkText(secondsToString(soundLength.get()), { hplace = ALIGN_RIGHT })
          ]
        }
      ]
    }
  }
}

let playerLoopButton = @() {
  watch = playerLoopState
  children = button({
    size = [playIconSize, playIconSize]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      rendObj = ROBJ_IMAGE
      size = [buttonIconHeight, buttonIconHeight]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      color = TextNormal
      keepAspect = true
      image = playerLoopState.get().status != LoopStatus.ONE_TRACK_LOOP
        ? Picture("ui/skin#music_loop.svg:{0}:{0}:K".subst(buttonIconHeight))
        : Picture("ui/skin#music_loop_1.svg:{0}:{0}:K".subst(buttonIconHeight))
    }
  }, changeLoopState,
  {
    stateFlags = loopBtnStateFlags
    style = {
      BtnBgNormal = playerLoopState.get().status != LoopStatus.NO_LOOP ? BtnBgSelected : BtnBgNormal
    }
    onElemState = function(sf) {
      loopBtnStateFlags.set(sf)
      setTooltip(sf & S_HOVER ? loc(playerLoopState.get().hintLocId) : null)
    }
  })
}

function trackInfo() {
  let { soundTrack = "musicPlayer/chooseSound", author=null } = playingSound.get()
  return {
    watch = playingSound
    size = flex()
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    padding = hdpx(20)
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        children = [
          mkDeltaButton(-1)
          playingSound.get() == null ? mkPlayButton(playingSound.get()) : null
          playingSound.get()!=null ? mkStopButton(playingSound.get()) : null
          playerLoopButton
          mkDeltaButton(1)
        ]
      }
      { size = flex() }
      mkLargeSoundIcon(playingSound.get()?.item__proto)
      { size = flex() }
      mkText(loc(soundTrack), {
        behavior = Behaviors.Marquee
        scrollOnHover = false
        speed = hdpx(50)
      }.__update(h2_txt))
      mkText(loc(author), {opacity = 0.5})
      {size=static [0, hdpx(10)]}
      mkTimeLine()
    ]
  }
}

let musicVolumeBlock =  freeze({
  size = static [SIZE_TO_CONTENT, ph(40)]
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  children = [
    {
      size = FLEX_V
      padding = static [hdpx(20), 0]
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = { size  = flex() }
      children = [
        mkText("+", body_txt)
        mkText("-", body_txt)
      ]
    }
    {
      size = static [fsh(2), flex()]
      padding = static [hdpx(20), 0]
      children = Vert(musicPlayerVolumeWatch, {
        min = 0
        max = 2
        unit = 0.05
        setValue = function(v) {
          musicPlayerVolumeSet(v)
          musicPlayerSetVolume(v)
        }
        bgColor = BtnBgFocused
        knobContent = @() {
          watch = musicPlayerVolumeWatch
          pos = [fsh(3), 0]
          children = mkText(musicPlayerVolumeWatch.get() * 50)
        }
      })
    }
  ]
})

let playerBlock = freeze({
  size = flex()
  halign = ALIGN_CENTER
  children = [
    {
      size = static [hdpx(500), flex()]
      children = [
        trackInfo
        musicVolumeBlock
      ]
    }.__update(bluredPanel)
  ]
})

let musicPlayerTab = freeze({
  flow = FLOW_VERTICAL
  size = flex()
  gap = hdpx(10)
  children = [
    {
      size = static [flex(), hdpx(50)]
      padding = static [0, hdpx(4)]
      valign = ALIGN_CENTER
      children = mkText(loc("statisticsMenu/musicPlayer"), h2_txt)
    }
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = [
        soundsListBlock
        playerBlock
      ]
    }
  ]
})

return freeze({
  musicPlayerTab
  unseenTracksCount
  MUSIC_PLAYER_ID
  startPlayer
  stopPlayer
  playingSound
  trackList
  playerLoopState
  loopOrder
  LoopStatus
  musicPlayerVolumeWatch
  musicPlayerVolumeSet
  musicPlayerSetVolume
})
