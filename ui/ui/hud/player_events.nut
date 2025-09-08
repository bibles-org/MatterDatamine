from "%ui/ui_library.nut" import *

let {playerEvents} = require("%ui/hud/state/eventlog.nut")
let {h2_txt, basic_text_shadow} = require("%ui/fonts_style.nut")
let {TextNormal} = require("%ui/components/colors.nut")

let defTextAnims = freeze([
  { prop=AnimProp.scale, from=[1,0], to=[1,1], duration=0.33, play=true, easing=OutCubic }
])

function makeDefText(item) {
  let color = item?.color ?? TextNormal
  let animations = item?.animations ?? defTextAnims
  let text = item?.text
  let children = {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    rendObj = ROBJ_TEXTAREA
    valign = ALIGN_CENTER
    behavior = Behaviors.TextArea
    text
    color
  }.__update(h2_txt, basic_text_shadow)

  return {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    animations
    key = item
    transform = { pivot = [0, 1] }
    children
  }
}

function makeItem(item){
  if ("ctor" in item)
    return item.ctor(item)
  return makeDefText(item)
}


function playerEventsRoot() {
  return {
    flow   = FLOW_VERTICAL
    halign = ALIGN_CENTER
    valign = ALIGN_BOTTOM
    size   = [pw(80), SIZE_TO_CONTENT]
    watch = playerEvents
    zOrder = Layers.MsgBox 
    children = playerEvents.get().map(makeItem)
  }
}


return playerEventsRoot
