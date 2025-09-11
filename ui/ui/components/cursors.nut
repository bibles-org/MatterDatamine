from "%dngscripts/platform.nut" import is_sony, is_xbox, is_mobile

import "%ui/components/tooltipBox.nut" as tooltipBox

from "%ui/ui_library.nut" import *

let { isGamepad } = require("%ui/control/active_controls.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")

let tooltipComp = {content = null, elemPos = null}
#allow-auto-freeze

let tooltipGen = Watched(0)
const MAX_GEN_INT = 1000
function setTooltip(val, elemPos = null){
  
  if (!isEqual(tooltipComp.content, val) || tooltipComp.elemPos != elemPos){
    tooltipComp.content = val
    tooltipComp.elemPos = elemPos
    tooltipGen.set(tooltipGen.get() > MAX_GEN_INT ? 0 : tooltipGen.get() + 1)
  }
}

let getTooltip = @() tooltipComp.content
#forbid-auto-freeze
let cursors = {getTooltip, setTooltip, tooltip = {}}
#allow-auto-freeze
let { cursorOverStickScroll, cursorOverClickable } = gui_scene
let showGamepad = Computed(@() isGamepad.get() || is_xbox || is_sony)
let hideCursor = is_mobile
let gamepadPos = [hdpx(28), hdpx(40)]
let pcPose = [hdpx(12), hdpx(28)]

let safeAreaBorders = Computed(@() [safeAreaVerPadding.get()+fsh(1), safeAreaHorPadding.get()+fsh(1)])

function getTooltipPositioning(vplace, tooltipChildren) {
  if (vplace == ALIGN_BOTTOM)
    return [0, 0]

  let posToUse = showGamepad.get() ? gamepadPos : pcPose
  let elemPos = tooltipComp.elemPos?.targetRect
  if (!elemPos)
    return posToUse

  let rootSizeHeight = elemPos.b - elemPos.t
  local posY = ((rootSizeHeight * 0.5) + 0.5).tointeger()
  let tooltipPrecalcRect = calc_comp_size(tooltipChildren)
  let critPosY = elemPos.b + tooltipPrecalcRect[1]
  if (critPosY >= (sh(100) - safeAreaBorders.get()[0])) {
    let curPos = get_mouse_cursor_pos()
    posY = elemPos.t - curPos.y - tooltipPrecalcRect[1]
  }
  return [posToUse[0], posY]
}

let mkTooltipCmp = @(align) function() {
  let children = type(getTooltip()) == "string"
    ? tooltipBox({
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        maxWidth = hdpxi(500)
        text = getTooltip()
        color = Color(180, 180, 180, 120)
      })
    : getTooltip()

  if (children == null)
    return { watch = tooltipGen }
  let pos = getTooltipPositioning(align, children)
  return {
    watch = [tooltipGen, showGamepad, safeAreaBorders]
    key = "tooltip"
    pos
    behavior = Behaviors.BoundToArea
    transform = {}
    safeAreaMargin = safeAreaBorders.get()
    vplace = align
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    children
  }
}

cursors.tooltip.cmp <- mkTooltipCmp(ALIGN_TOP)
cursors.tooltip.cmpTop <- mkTooltipCmp(ALIGN_BOTTOM)



















let getEvenIntegerHdpx = @(px) hdpxi(0.5 * px) * 2

let scroll_size = getEvenIntegerHdpx(20)

let round_cursor = static [
  [VECTOR_WIDTH, hdpx(1.4)],
  [VECTOR_FILL_COLOR, Color(70, 80, 90, 90)],
  [VECTOR_COLOR, Color(100, 100, 100, 50)],
  [VECTOR_ELLIPSE, 50, 50, 50, 50],
  [VECTOR_WIDTH, hdpx(1.5)],
  [VECTOR_FILL_COLOR, 0],
  [VECTOR_COLOR, Color(0, 0, 0, 60)],
  [VECTOR_ELLIPSE, 50, 50, 43, 43],
  [VECTOR_WIDTH, hdpx(1.5)],
  [VECTOR_COLOR, Color(100, 100, 100, 50)],
  [VECTOR_ELLIPSE, 50, 50, 46, 46],
]

let joyScrollCursorImage = {
  key = "scroll-cursor"
  rendObj = ROBJ_IMAGE
  size = scroll_size
  image = Picture($"!ui/skin#cursor_scroll.svg:{scroll_size}:{scroll_size}:K")
  keepAspect = true
  pos = static [hdpx(20), hdpx(30)]
  opacity = 1

  transform = static {}

  animations = static [
    { prop=AnimProp.opacity,  from=0.0,    to=1.0,     duration=0.3,  play=true, easing=OutCubic }
    { prop=AnimProp.opacity,  from=1.0,    to=0.0,     duration=0.1,  playFadeOut=true, easing=OutCubic }
    { prop=AnimProp.scale,    from=[0, 0], to=[1, 1],  duration=0.15, play=true, easing=OutCubic }
    { prop=AnimProp.scale,    from=[1, 1], to=[0, 0],  duration=0.1,  playFadeOut=true, easing=OutCubic }
  ]
}

let cursorSzNormal = getEvenIntegerHdpx(32)

let normalCursorPic = Picture("!ui/skin#cursor.svg:{0}:{0}:P".subst(cursorSzNormal))

let cursorImageComp = {
  rendObj = ROBJ_IMAGE
  image = normalCursorPic
  size = [cursorSzNormal, cursorSzNormal]
}

function mkPcCursor(children){
  children = children ?? []
  if (type(children) != "array")
    children = [children]
  children = clone children
  children.append(cursorImageComp)
  return {
    size = 0
    children = children
    watch = [showGamepad, cursorOverStickScroll]
  }
}

let gamepadCursorSize = static [hdpxi(40), hdpxi(40)]

let gamepadOnClickAnimationComp = static {
  animations = [
    {prop=AnimProp.scale, from=[0.5, 0.5], to=[1, 1],  duration=0.5, play=true, loop=true }
  ]
  commands = round_cursor
  rendObj = ROBJ_VECTOR_CANVAS
  size = gamepadCursorSize
  halign = ALIGN_CENTER
  transform = {pivot=[0.5,0.5]}
  opacity = 0.5
}

let gamepadComp = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = gamepadCursorSize
  commands = round_cursor
}

function mkGamepadCursor(children){
  children = clone children
  children.append(gamepadComp)
  if (cursorOverClickable.get())
    children.append(gamepadOnClickAnimationComp)
  return {
    hotspot = static [hdpx(20), hdpx(20)]
    watch = [showGamepad, cursorOverStickScroll, cursorOverClickable]
    size = gamepadCursorSize
    children = children
    halign = ALIGN_CENTER
    transform = static {
      pivot = [0.5, 0.5]
    }
  }
}

function mkHiddenCursor(children){
  return {
    children = children
    watch = [showGamepad, cursorOverStickScroll]
  }
}

function mkCursorWithTooltip(children){
  #forbid-auto-freeze
  if (type(children) != "array")
    children = [children]
  if (cursorOverStickScroll.get() && showGamepad.get())
    children.append(joyScrollCursorImage)
  return showGamepad.get() ? mkGamepadCursor(children)
                           : hideCursor ? mkHiddenCursor(children)
                           : mkPcCursor(children)
}

cursors.normal <- Cursor(@() mkCursorWithTooltip(cursors.tooltip.cmp))


return cursors
