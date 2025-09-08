from "%ui/ui_library.nut" import *

let { BtnBgNormal, BtnBgActive, BtnBgHover } = require("%ui/components/colors.nut")
let scrollBarBgColor = Color(5, 5, 5, 200)

let minKnobSizePart = 0.005

let BarSound = freeze({ hover  = "ui_sounds/combobox_highlight" })

let defBarScrollStyle = freeze({
  rendObj = ROBJ_SOLID
  color = scrollBarBgColor
  _width = fsh(1)
  _height = fsh(1)
  sound = BarSound
  padding = [hdpx(1), hdpx(1)]
  skipDirPadNav = true
})

let defBarNoScrollStyle = freeze({
  rendObj = null
  _width = 0
  _height = 0
  skipDirPadNav = true
})

let colorKnobCalc = @(sf) sf & S_ACTIVE
  ? BtnBgActive
  : sf & S_HOVER ? BtnBgHover : BtnBgNormal

let knobSound = freeze({ active = "ui_sounds/combobox_action" })
let defStyling = freeze({
  BarNoScrollStyle = defBarNoScrollStyle
  BarHasScrollStyle = defBarScrollStyle
})

let reservePaddingBarNoScrollStyle = defBarNoScrollStyle.__merge({ _width = defBarScrollStyle._width _height = defBarScrollStyle._height})
let reservedPaddingStyle = freeze(defStyling.__merge({BarNoScrollStyle = reservePaddingBarNoScrollStyle}))

let overlappedBarScrollStyle = defBarScrollStyle.__merge({margin = [0, 0, 0, hdpx(4)]})
let overlappedStyle = freeze(defStyling.__merge({BarHasScrollStyle = overlappedBarScrollStyle}))

let thinBarScrollStyle = defBarScrollStyle.__merge({ _width = hdpx(5) _height = hdpx(5) })
let thinStyle = freeze(defStyling.__merge({BarHasScrollStyle = thinBarScrollStyle}))

let thinBarReservedPaddingNoScrollStyle = defBarNoScrollStyle.__merge({ _width = thinBarScrollStyle._width _height = thinBarScrollStyle._height })
let thinAndReservedPaddingStyle = freeze(thinStyle.__merge({BarNoScrollStyle = thinBarReservedPaddingNoScrollStyle}))

let calcBarSize = @(bar_style, isVertical) isVertical ? [bar_style._width, flex()] : [flex(), bar_style._height]


function mkScrollbar(scroll_handler, styling=null, needReservePlace=true, orientation=O_VERTICAL, isInteractive=true) {
  let stateFlags = Watched(0)
  styling  = styling ?? defStyling
  orientation = orientation ?? O_VERTICAL

  let isVertical = orientation == O_VERTICAL
  let elemSize = isVertical
    ? Computed(@() (scroll_handler.elem?.getHeight() ?? 0))
    : Computed(@() (scroll_handler.elem?.getWidth() ?? 0))
  let maxV = isVertical
    ? Computed(@() (scroll_handler.elem?.getContentHeight() ?? 0) - elemSize.get())
    : Computed(@() (scroll_handler.elem?.getContentWidth() ?? 0) - elemSize.get())
  let fValue = isVertical
    ? Computed(@() scroll_handler.elem?.getScrollOffsY() ?? 0)
    : Computed(@() scroll_handler.elem?.getScrollOffsX() ?? 0)
  let isElemFit = Computed(@() maxV.get() <= 0)
  let knob = @() {
    size = flex()
    color = colorKnobCalc(stateFlags.get())
    watch = stateFlags
    key = "knob"
    sound = knobSound
    rendObj = ROBJ_SOLID
  }

  function view() {
    let sizeMul = elemSize.get() == 0 || maxV.get() == 0 ? 1
      : elemSize.get() <= minKnobSizePart * maxV.get() ? 1.0 / maxV.get() / minKnobSizePart
      : 1.0 / elemSize.get()
    return {
      watch = [elemSize, maxV, fValue]
      size = flex()
      flow = isVertical ? FLOW_VERTICAL : FLOW_HORIZONTAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER

      children = [
        { size = array(2, flex(fValue.get() * sizeMul)) }
        knob
        { size = array(2, flex((maxV.get() - fValue.get()) * sizeMul)) }
      ]
    }
  }
  let {BarHasScrollStyle, BarNoScrollStyle} = styling

  return function scrollComp() {
    if (isElemFit.get()) {
      return BarNoScrollStyle.__merge({
        watch = isElemFit
        key = scroll_handler
        behavior = isInteractive ? Behaviors.Slider : null
        size = needReservePlace ? calcBarSize(BarNoScrollStyle, isVertical) : null
      })
    }
    return BarHasScrollStyle.__merge({
      watch = [isElemFit, maxV, elemSize]
      key = scroll_handler
      size = calcBarSize(BarHasScrollStyle, isVertical)

      behavior = isInteractive ? Behaviors.Slider : null
      orientation
      fValue = fValue.get()
      knob
      min = 0
      max = maxV.get()
      unit = 1
      pageScroll = (isVertical ? 1 : -1) * maxV.get() / 100.0 
      onChange = @(val) isVertical ? scroll_handler.scrollToY(val)
        : scroll_handler.scrollToX(val)
      onElemState = @(sf) stateFlags.set(sf)
      children = view
    })
  }
}


let DEF_SIDE_SCROLL_OPTIONS = freeze({
  styling = defStyling
  rootBase = null
  scrollAlign = ALIGN_RIGHT
  orientation = O_VERTICAL
  size = flex()
  maxWidth = null
  maxHeight = null
  needReservePlace = true 
  clipChildren  = true
  joystickScroll = true
  scrollHandler = null
  isInteractive = true
})

function makeSideScroll(content, options = DEF_SIDE_SCROLL_OPTIONS) {
  options = DEF_SIDE_SCROLL_OPTIONS.__merge(options)
  let {scrollAlign, size, styling, orientation, rootBase, clipChildren, maxHeight, maxWidth, needReservePlace,
    joystickScroll, isInteractive} = options
  let scrollHandler  = options?.scrollHandler ?? ScrollHandler()
  function contentRoot() {
    return {wheelStep = 0.8 size = flex() skipDirPadNav = true}.__update(
      rootBase ?? {},
      {
        size = options.size
        behavior = !isInteractive ? null
          : [Behaviors.WheelScroll, Behaviors.ScrollEvent].extend(rootBase?.behavior ?? [])
        scrollHandler
        orientation
        joystickScroll
        children = content
      })
  }

  let scrollComp = mkScrollbar(scrollHandler, styling, needReservePlace, orientation, isInteractive)
  let children = scrollAlign == ALIGN_LEFT || scrollAlign == ALIGN_TOP
    ? [scrollComp, contentRoot]
    : [contentRoot, scrollComp]

  return {
    size = size
    maxHeight
    maxWidth
    flow = (orientation == O_VERTICAL) ? FLOW_HORIZONTAL : FLOW_VERTICAL
    clipChildren
    children
  }
}



let makeHVScrolls = kwarg(function(content, scrollHandler=null, rootBase=null, needReservePlace=false, styling=null) {
  styling = styling ?? defStyling
  scrollHandler = scrollHandler ?? ScrollHandler()
  rootBase = rootBase ?? {}

  function contentRoot() {
    return rootBase.__merge({
      behavior = [Behaviors.WheelScroll, Behaviors.ScrollEvent].extend(rootBase?.behavior ?? [])
      scrollHandler = scrollHandler
      joystickScroll = true

      children = content
    })
  }

  return {
    size = flex()
    flow = FLOW_VERTICAL

    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        clipChildren = true
        children = [
          contentRoot
          mkScrollbar(scrollHandler, styling, needReservePlace, O_VERTICAL)
        ]
      }
      mkScrollbar(scrollHandler, styling, needReservePlace, O_HORIZONTAL)
    ]
  }
})


return {
  mkScrollbar
  makeHorizScroll = @(content) makeSideScroll(content, {orientation = O_HORIZONTAL, scrollAlign = ALIGN_BOTTOM})
  makeVertScrollExt = makeSideScroll
  makeVertScroll = @(content) makeSideScroll(content)
  makeHVScrolls
  reservedPaddingStyle
  overlappedStyle
  thinStyle
  thinAndReservedPaddingStyle
}
