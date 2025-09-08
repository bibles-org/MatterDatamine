from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")



let textDefColor = Color(255, 255, 255)
let itemDefBgColor = Color(35,35,35,205)



let defTransform = {}


let make_help_text = @(text) {
  rendObj = ROBJ_TEXTAREA
  text = loc(text)
  color = textDefColor
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  halign = ALIGN_LEFT
  valign = ALIGN_CENTER
}

let make_help_title = @(text) {
  rendObj = ROBJ_TEXT
  text = loc(text)
  color = textDefColor
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  padding = [hdpx(4), hdpx(4)]
}

let help_title_icon = {
  image = Picture($"ui/skin#info/info_icon.svg:22:22:K"),
  rendObj = ROBJ_IMAGE
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
}

let help_ctor = function(params) {
  if (!params.isVisible)
    return null
  let eid = params.eid
  return {
    data = {
      eid
      minDistance = params.minDistance
      maxDistance = params.maxDistance
    }
    rendObj = ROBJ_BOX
    fillColor = itemDefBgColor,
    borderColor = itemDefBgColor,
    borderWidth = hdpx(1),
    borderRadius = params.borderRadius
    flow = FLOW_VERTICAL
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = defTransform
    key = eid
    watch = [watchedHeroEid]
    children = params.children
    size = params.size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    sortOrder = params.sortOrder
    padding = hdpx(10)
  }
}

let minimum_sort_order = 80000

let help_text_ctor = function(eid, help) {
  return function() {
    let help_text = make_help_text(help.text)
    return help_ctor({
      isVisible = help.help__visible && (!help.requireTrace || help.traceSuccess)
      eid
      minDistance = 0.1
      maxDistance = help.maxFullDistance
      children = [help_text]
      size = [sw(help.width), SIZE_TO_CONTENT]
      sortOrder = minimum_sort_order + 1
      borderRadius = hdpx(6)
    })
  }
}

let help_title_ctor = function(eid, help) {
  return function() {
    let title = make_help_title(help.title)
    return help_ctor({
      isVisible = help.help__visible && (!help.requireTrace || help.traceSuccess)
      eid
      minDistance = help.maxFullDistance
      maxDistance = help.maxShortDistance
      children = [help_title_icon, title]
      size = null
      sortOrder = minimum_sort_order
      borderRadius = hdpx(40)
    })
  }
}

return {
    help_ctors = [help_text_ctor, help_title_ctor]
}
