from "%ui/components/colors.nut" import ConsoleBorderColor, ConsoleFillColor
from "%ui/components/commonComponents.nut" import mkTitleString, fontIconButton
from "dasevents" import CmdHideUiMenu, CmdShowUiMenu
from "%ui/components/cursors.nut" import setTooltip
from "%ui/navState.nut" import addNavScene, backNavScene
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/control/gui_buttons.nut" as JB

let { safeAreaHorPadding, safeAreaVerPadding, safeAreaAmount } = require("%ui/options/safeArea.nut")

let defaultAspectRatio = 16.0/9.0
let wideAspectRatio = 9.0/16.0

let currentAspectRatio = static(sw(100).tofloat() / sh(100).tofloat()) 
let isWideScreen = currentAspectRatio >= 1.7

let screenTitleHeight = hdpx(55)

let stdBtnSize = static [hdpx(30), hdpx(30)]
let stdBtnFontSize = hdpx(20)

let screenHeight = isWideScreen ? sh(86) : sw(95) * wideAspectRatio
let screenWidth = isWideScreen ? sh(88) * defaultAspectRatio : sw(89.5)
let screenSize = static [ screenWidth, screenHeight ]

let mkCloseStyleBtn = @(cb, override = {} ) fontIconButton(
  "icon_buttons/x_btn.svg",
  cb
  {
    fontSize = stdBtnFontSize
    size = stdBtnSize
    hotkeys = static [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnClose")}]]
    onHover = @(on) setTooltip(on ? loc("mainmenu/btnClose") : null )
    skipDirPadNav = true
    sound = static {
      click = null 
      hover = "ui_sounds/button_highlight"
    }
  }.__update(override)
)

let mkCloseBtn = @(id) mkCloseStyleBtn(@() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = id})), { key = id })

let mkBackBtn = @(id, cb=null, prehook = null) fontIconButton(
  "angle-left",
  function() {
    if (prehook != null) {
      prehook()
      return
    }
    if (id)
      ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({ menuName = id }))
    if (cb)
      cb()
  },
  {
    fontSize =stdBtnFontSize
    size = stdBtnSize
    hotkeys = [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnBack")}]]
    onHover = @(on) setTooltip(on ? loc("mainmenu/btnBack") : null )
    skipDirPadNav = true
    sound = static {
      click = null 
      hover = "ui_sounds/button_highlight"
    }
  }
)

let mkWndTitleComp = @(name) name instanceof Watched
    ? @() { watch = name, size = FLEX_H, flow = FLOW_HORIZONTAL children = [mkTitleString(name.get().toupper()), {size = static [flex(), 0]}] }
    : type(name) == "function" ? name : @() { size = FLEX_H flow = FLOW_HORIZONTAL children = [mkTitleString(name.toupper()), {size = static [flex(), 0]} ]}

function mkHeader(titleComp, buttons) {
  return {




    size = [flex(), screenTitleHeight]
    children = [
      
      {size = static [flex(), hdpx(1)] rendObj = ROBJ_SOLID color = mul_color(ConsoleBorderColor, 0.3) vplace = ALIGN_BOTTOM}
      {
        padding = static [0, hdpx(10), 0, hdpx(20)]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        size = flex()
        children = [
          titleComp
          buttons
        ]
      }
    ]
  }
}
let defPanelStyle = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ConsoleFillColor
  borderColor = ConsoleBorderColor
  borderWidth = static [hdpx(1), 0]
}

let mkPanel = @(header, content, style = {}) function() {
  let { size = null, showback = true, pos = [0, safeAreaVerPadding.get() / 2] } = style
  return {
    watch = [safeAreaAmount, safeAreaHorPadding, safeAreaVerPadding]
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = {
      size = size ?? [screenSize[0], screenSize[1] - safeAreaVerPadding.get()]
      pos
      padding = static [fsh(1),0,0,0]
      children = {
        size = flex()
        flow = FLOW_VERTICAL
        children = [
          header
          content
        ]
      }.__update(showback ? defPanelStyle : {})
    }
  }
}

let wrapButtons = @(...) {
  children = vargv
  gap = hdpx(2)
  flow = FLOW_HORIZONTAL
  hplace = ALIGN_RIGHT
}

let helpStyle = {
  fontSize = stdBtnFontSize
  size = stdBtnSize
  onHover = @(on) setTooltip(on ? loc("mainmenu/btnHelp") : null )
  skipDirPadNav = true
  sound = {
    click = "ui_sounds/button_help"
    hover = "ui_sounds/button_highlight"
  }
}

let helpCloseBtn = fontIconButton("icon_buttons/x_btn.svg", backNavScene, static {fontSize = stdBtnFontSize, size = stdBtnSize, skipDirPadNav = true})

function mkHelpButton(helpContent, title=null) {
  local scene
  let header = mkHeader({size=FLEX_H children = mkTitleString(title?.toupper())}, helpCloseBtn)
  let hotkey = static {hotkeys = [[$"Esc | {JB.B}", backNavScene]]}
  scene = {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    stopMouse = true
    size = flex()
    children = [
      mkPanel(header, helpContent)
      hotkey
      {
        size = flex()
        onClick = backNavScene
        behavior = Behaviors.Button
        skipDirPadNav=true
      }
    ]
  }
  return fontIconButton( "icon_buttons/q_btn.svg", @() addNavScene(scene), helpStyle )
}

function wrapInStdPanel(id, content, name, helpContent=null, custom_header=null, style = null){
  let helpBtn = helpContent != null ? mkHelpButton(helpContent, name) : null
  return mkPanel(
    custom_header ?? mkHeader(mkWndTitleComp(name), wrapButtons(helpBtn, mkCloseBtn(id))),
    content, style)
}

return freeze({ wrapInStdPanel, stdBtnSize, stdBtnFontSize, mkBackBtn, mkCloseBtn, mkCloseStyleBtn, mkPanel, mkHelpButton
  mkHeader, mkWndTitleComp, wrapButtons, screenSize })