from "%ui/ui_library.nut" import *

let {body_txt, sub_txt} = require("%ui/fonts_style.nut")
let { TEAM_UNASSIGNED } = require("team")
let { makeVertScrollExt } = require("%ui/components/scrollbar.nut")
let {ControlBg, UserNameColor, TEAM0_TEXT_COLOR} = require("%ui/components/colors.nut")
let {sendChatMessage, chatTotalLines, chatLogState, chatLines, chatOutMessage, chatSendMode, MatchingTeam} = require("%ui/hud/state/chat.nut")
let {addInteractiveElement, removeInteractiveElement, hudIsInteractive} = require("%ui/hud/state/interactive_state.nut")
let {localPlayerTeam, localPlayerName} = require("%ui/hud/state/local_player.nut")
let { DBGLEVEL } = require("dagor.system")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let {sound_play_one_shot} = require("%dngscripts/sound_system.nut")
let {hasMsgBoxes} = require("%ui/components/msgbox.nut")
let {groupmatesSet} = require("%ui/hud/state/teammates_es.nut")
let {mkInputHintBlock} = require("%ui/hud/tips/tipComponent.nut")

let switchSendModesAllowed = DBGLEVEL > 0

let showChatInput = mkWatched(persist, "showChatInput", false)

let inputBoxHeight = fsh(8)

let itemTextAnim = [



]

let itemGap = freeze({size=[0,hdpx(1)]})

let itemAnim = freeze([
  { prop=AnimProp.opacity, from=1.0, to=0, duration=0.6, playFadeOut=true}
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], delay=0.4, duration=0.6, playFadeOut=true}
])
let neutralColor = Color(180,180,180)
function chatItem(item, params = {}) {
  let team = item?.team ?? TEAM_UNASSIGNED
  let color = team == TEAM_UNASSIGNED ? 0xFFFFFFFF :
    team == localPlayerTeam.get() || team == MatchingTeam || item.sendMode=="team" ? TEAM0_TEXT_COLOR : neutralColor

  let rowChildren = []
  if (item.name != "")
    rowChildren.append(
      item.sendMode != "all" ? null : { rendObj = ROBJ_TEXT, color = color, text = "".concat("[", loc("chat/all"), "]") },
      {
        rendObj = ROBJ_TEXT,
        color = item.name == localPlayerName.get() ? UserNameColor : color,
        text = "".concat(remap_nick(item.name),": ")
      })
  rowChildren.append({
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    color
    text = item.text
  })

  return {
    size = [flex(), SIZE_TO_CONTENT]
    key = item
    rendObj = ROBJ_WORLD_BLUR
    color = Color(200,200,200,200)
    children = {
      flow = FLOW_HORIZONTAL
      key = item
      transform = { pivot = [0, 1.0] }
      size = [flex(), SIZE_TO_CONTENT]
      animations = (params?.noanim) ? null : itemTextAnim
      children = rowChildren
    }
    transform = { pivot = [0, 0] }
    animations = (params?.noanim) ? null : itemAnim
  }
}

let scrollHandler = ScrollHandler()

function chatLogContent() {
  let logLines = chatLogState.get().map(@(line) chatItem(line, { noanim = true }))
  let scrollTo = chatLogState.get().len() ? chatLogState.get().top() : null
  return {
    watch = chatLogState
    key = "chatLog"
    size = [flex(),SIZE_TO_CONTENT]
    minHeight = SIZE_TO_CONTENT
    clipChildren = true
    gap = itemGap
    flow = FLOW_VERTICAL
    children = logLines
    onAttach = @() scrollHandler.scrollToChildren(@(desc) ("key" in desc) && (desc.key == scrollTo), 2, false, true)
  }
}

let chatLog = {
  size = flex()
  flow = FLOW_VERTICAL
  children = makeVertScrollExt(chatLogContent, {scrollHandler})
  vplace = ALIGN_BOTTOM
}

function chatContent() {
  let children = chatLines.get().map(chatItem)

  return {
    key = "chatContent"
    size = flex()
    clipChildren = true
    children = children
    valign = ALIGN_BOTTOM
    gap = itemGap
    flow = FLOW_VERTICAL
    watch = [chatLines, localPlayerTeam]


  }
}

let setInteractive = @(new_val) (new_val ? addInteractiveElement : removeInteractiveElement)("chat")
if (hudIsInteractive.get())
  setInteractive(showChatInput.get())

function inputBox() {
  let textInput = {
    rendObj = ROBJ_SOLID
    color = ControlBg
    vplace = ALIGN_TOP
    size = [flex(), SIZE_TO_CONTENT]

    children = [
      function() {
        return {
          rendObj = ROBJ_TEXT
          size = [flex(), fontH(120)]
          margin = fsh(0.5)
          text = chatOutMessage.get()
          watch = chatOutMessage
          behavior = Behaviors.TextInput
          function onChange(text) {
            chatOutMessage(text)
          }
          function onAttach(elem) {
            capture_kb_focus(elem)
          }
          function onReturn() {
            if (chatOutMessage.get().len()>0) {
              sendChatMessage({mode = chatSendMode.get(),
                                      text = chatOutMessage.get()})
            }
            chatOutMessage("")
            showChatInput(false)
          }
        }.__update(sub_txt)
      }
    ]
  }

  function sendModeText() {
    let mode = chatSendMode.get()
    if (mode == "all")
      return loc("chat/all")
    if (mode == "team")
      return loc("chat/team")
    return "???"
  }

  let modesHelp = {
    vplace = ALIGN_BOTTOM
    size = [flex(), fsh(3)]
    children = [
      {
        rendObj = ROBJ_TEXT
        vplace = ALIGN_CENTER
        text = loc("chat/help/short")
        color = Color(180, 180, 180, 180)
      }.__update(sub_txt)
      @() {
        rendObj = ROBJ_TEXT
        vplace = ALIGN_CENTER
        hplace = ALIGN_RIGHT
        watch = chatSendMode
        text = sendModeText()
      }.__update(body_txt)
    ]
  }

  function switchSendModes() {
    let newMode = chatSendMode.get() == "all" ? "team" : "all"
    if (switchSendModesAllowed)
      chatSendMode(newMode)
  }

  return {
    size = [flex(), inputBoxHeight]
    flow = FLOW_VERTICAL

    onAttach = @() setInteractive(true)
    onDetach = @() setInteractive(false)

    hotkeys = switchSendModesAllowed ? [ ["^Tab", switchSendModes] ] : null

    children = [
      textInput
      switchSendModesAllowed ? modesHelp : null
    ]
  }
}


hasMsgBoxes.subscribe(function(shown_any) {
  
  if (shown_any) {
    chatOutMessage("")
    showChatInput(false)
  }
})


let inputBoxDummy = {size=[flex(), inputBoxHeight]}
let showChatInputHint = Watched(true)
let chatHint = @() {
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [mkInputHintBlock("HUD.ChatInput"), {rendObj=ROBJ_TEXT text=loc("Open chat") color = Color(200,200,200)}]
  onAttach = @() gui_scene.resetTimeout(10, @() showChatInputHint.set(false))
  animations = [
    {prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, playFadeOut=true, easing=OutCubic}
  ]
}

function chatRoot() {
  local children = null
  if (showChatInput.get()) {
    children = [chatLog, inputBox]
  } else {
    children = [chatContent, (groupmatesSet.get()?.len() ?? 0) > 0 && showChatInputHint.get() ? chatHint : null, inputBoxDummy]
  }

  return {
    key = "chat"
    flow = FLOW_VERTICAL
    size = [flex(), fsh(24)]
    gap = hdpx(5)
    watch = [showChatInput, groupmatesSet, showChatInputHint]

    children
  }
}

chatTotalLines.subscribe(@(_v) sound_play_one_shot("ui_sounds/new_log_message"))

return {
  chatRoot
  showChatInput
}
