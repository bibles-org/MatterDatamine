from "%ui/ui_library.nut" import *

let textColor = Color(227, 109, 0, 255)
const consoleFontSize = 12
const consoleTitleFontSize = 22

let waitingCursor = const {
  rendObj = ROBJ_TEXT text = ">", color=textColor,
  animations=[{ prop=AnimProp.opacity,  from=0.0, to=1.0, duration=1,  play=true, loop=true, easing=OutStep }]
  fontSize = consoleFontSize
}

let inviteText = const {
  rendObj = ROBJ_TEXTAREA behavior = Behaviors.TextArea text = loc("raids/console/invite", "Waiting for commands. Tap with your smartwatch to start"), size = [flex(), SIZE_TO_CONTENT] color=textColor
  fontSize = consoleFontSize
}

function mkStdPanel(canvasSize, data=const {}, override=null) {
  return {
    
    worldAnchor   = PANEL_ANCHOR_ENTITY
    worldGeometry = PANEL_GEOMETRY_RECTANGLE
    canvasSize
    
    color = Color(0,0,0,255)
    size = [canvasSize[0], canvasSize[1]]
  }.__update(data, override ?? const {})
}

let flashingScreen = const {
  rendObj = ROBJ_SOLID, size = flex()
  color = textColor
  animations = [{prop=AnimProp.opacity from = 0, to = 1 duration = 0.5 play = true loop = true easing=CosineFull}]
}

let mkInviteText = @(text) {
  rendObj = ROBJ_TEXTAREA behavior=Behaviors.TextArea color=textColor fontSize = consoleTitleFontSize, size = flex()
  halign = ALIGN_CENTER
  text
  margin = [5, 10]
  animations = [{prop=AnimProp.opacity from = 0, to = 1 duration = 0.5 play = true loop = true easing=CosineFull}]
}

let mkFlashingInviteTextScreen = @(text) { size = flex() children = [ mkInviteText(text) flashingScreen ] }

return {
  textColor
  consoleFontSize
  consoleTitleFontSize
  waitingCursor
  inviteText
  mkStdPanel
  mkFlashingInviteTextScreen
  mkInviteText
  flashingScreen
}