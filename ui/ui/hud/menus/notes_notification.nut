import "%dngscripts/ecs.nut" as ecs
import "%ui/components/fontawesome.map.nut" as fa

from "%ui/ui_library.nut" import *
from "%ui/hud/state/notes.nut" import predefinedNotes
from "%ui/hud/tips/tipComponent.nut" import tipContents
from "%ui/components/colors.nut" import BtnBgHover
from "%ui/hud/hud_menus_state.nut" import areHudMenusOpened, openMenu
from "%ui/hud/menus/journal.nut" import JournalMenuId, journalCurrentTab

let { sub_txt, body_txt, fontawesome } = require("%ui/fonts_style.nut")
let utf8 = require("utf8")
let { find_local_player } = require("%dngscripts/common_queries.nut")
let { CmdStopAssistantSpeak } = require("dasevents")
let { assistantSpeakingScript, shownTextNote } = require("%ui/hud/state/notes.nut")
let { mkTextArea } = require("%ui/components/commonComponents.nut")
let { clearTextSubtitlesTags } = require("%ui/hud/subtitles/subtitles_common.nut")

const MSG_MAX_CHARS = 180

let newNote = Computed(@() assistantSpeakingScript.get() ?? shownTextNote.get())

let avatarSize = hdpxi(26)
let msSecondAvatar = freeze({
  rendObj = ROBJ_IMAGE
  image = Picture($"!ui/skin#ms_second.svg:{avatarSize}:{avatarSize}")
  size = [avatarSize,avatarSize]
})


let tipIcon = freeze({
  rendObj = ROBJ_BOX
  size = [SIZE_TO_CONTENT, flex()]
  fillColor = BtnBgHover
  valign = ALIGN_CENTER
  borderRadius = [ hdpx(5), 0, 0, 0 ]
  padding = hdpx(5)
  vplace = ALIGN_TOP
  children = {
    rendObj = ROBJ_TEXT
    font = fontawesome.font
    fontSize = fontawesome.fontSize
    text = fa["file-text"]
  }
})

let mkNoteTitle = @(title) {
  flow = FLOW_HORIZONTAL
  size = [flex(), SIZE_TO_CONTENT]
  clipChildren = true
  gap = hdpx(5)
  padding = [0, hdpx(5),0,0]
  valign = ALIGN_CENTER
   children = [
    tipIcon
    mkTextArea(title, {color = Color(120,140,180,50)}.__update(body_txt))
  ]
}

let assistantComp = freeze({
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)

  valign = ALIGN_CENTER
  animations = [
    { prop=AnimProp.opacity, from=1, to=0, duration=0.8, easing = InOutQuad, playFadeOut = true}
  ]
  children = [
    {rendObj = ROBJ_TEXT text = loc("assistant_name", "Miss Second"), color = BtnBgHover}
    msSecondAvatar
  ]
})

let textStyle = {
  fontSize = sub_txt.fontSize
}

let noteInteractiveTip = tipContents({
  text = loc("tip/open_note")
  inputId = "HUD.Journal"
  needBuiltinPadding = false
  animations = []
  style = {
    rendObj = ROBJ_BOX
    padding = 0
  }
  needCharAnimation = false
  textStyle
}.__update(sub_txt))

let assistantVoiceStartTip = tipContents({
  text = loc("tip/assistant_voicing_note")
  inputId = "HUD.AssistantVoiceToggle"
  needBuiltinPadding = false
  animations = []
  style = {
    rendObj = ROBJ_BOX
    padding = 0
  }
  needCharAnimation = false
  textStyle
}.__update(sub_txt))

let assistantVoiceStopTip = tipContents({
  text = loc("tip/assistant_mute")
  inputId = "HUD.AssistantVoiceToggle"
  needBuiltinPadding = false
  animations = []
  style = {
    rendObj = ROBJ_BOX
    padding = 0
  }
  needCharAnimation = false
  textStyle
}.__update(sub_txt))

let voiceTip = @() {
  watch = assistantSpeakingScript
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = hdpx(10)
  children = assistantSpeakingScript.get() ? assistantVoiceStopTip : assistantVoiceStartTip
}

let mkAvatar = function(){
  let hide = Watched(false)
  return [
    @() gui_scene.setTimeout(1.0, @() hide.set(true)),
    @() {size = [flex(), 0] halign = ALIGN_RIGHT watch = hide children = hide.get() ? null : assistantComp vplace = ALIGN_BOTTOM valign = ALIGN_BOTTOM  pos = [0, -hdpx(5)]}
  ]
}

let tipMainBlock = function() {
  let noteId = newNote.get()
  let note = predefinedNotes.get().findvalue(@(v) v.id == noteId)
  let noteTitle = note?.title ?? loc("notes/missing/title")

  local message = utf8( clearTextSubtitlesTags(note?.notificationText) ?? "...")
  let textLength = message.charCount()
  if (textLength >= MSG_MAX_CHARS) {
    let nearestSpace = message.indexof(" ", MSG_MAX_CHARS) ?? textLength
    message = $"{message.slice(0, nearestSpace)} ..."
  }
  let [onAttach, avatar] = mkAvatar()
  return {
    watch = [ predefinedNotes, newNote, assistantSpeakingScript ]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = [hdpx(300), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    borderRadius = hdpx(5)
    fillColor = Color(10, 10, 10, 130)
    onAttach
    children = [
      avatar
      mkNoteTitle(noteTitle)
      {
        clipChildren = true
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        padding = [hdpx(5), hdpx(10)]
        gap = hdpx(5)
        children = [
          mkTextArea(message, sub_txt),
          {
            flow = FLOW_HORIZONTAL
            size = [flex(), SIZE_TO_CONTENT]
            gap = hdpx(10)
            children = [
              {
                flow = FLOW_VERTICAL
                gap = hdpx(5)
                children = [
                  noteInteractiveTip,
                  (newNote.get() != null && newNote.get() == assistantSpeakingScript.get()) ? voiceTip : null
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}

let operJournal = function() {
  openMenu(JournalMenuId)
  journalCurrentTab.set("notes")
}

let journalOpenInterceptor = {
  size = [0, 0]
  zOrder = Layers.Upper
  eventHandlers = {
    ["HUD.Journal"] = function(_event) {
      operJournal()
    },
    ["HUD.AssistantVoiceToggle"] = function(_event) {
      if (assistantSpeakingScript.get())
        ecs.g_entity_mgr.sendEvent(find_local_player(), CmdStopAssistantSpeak())
    }
  }
}

let showNewNoteTip = Computed(@() newNote.get()
  && !areHudMenusOpened.get()
  && predefinedNotes.get().findvalue(@(v) v.id == newNote.get()) != null)

let noteNotification = @() {
  vplace = ALIGN_BOTTOM
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  children = [
    tipMainBlock,
    journalOpenInterceptor
  ]
}

return {
  noteNotification
  showNewNoteTip
}
