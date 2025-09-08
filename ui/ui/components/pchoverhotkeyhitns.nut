from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { cursorPresent } = gui_scene
let { isGamepad } = require("%ui/control/active_controls.nut")
let mkMouseHint = require("%ui/hud/menus/components/mkMouseHint.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")

let hoverHotkeysWatchedList = Watched(null)

let panel_ver_padding = fsh(1)
let height = sub_txt.fontSize

function getHotkeyHints(hotkeys, forTooltip = false) {
  let hotkeysToShow = hotkeys.filter(function(v) {
    if ( v == null || (forTooltip && v?.showInTooltip != true) )
      return false
    return true
  })
  hotkeysToShow.sort(@(a, b) (a?.order ?? 0) <=> (b?.order ?? 0))
  return hotkeysToShow.map(@(v) mkMouseHint(loc(v.locId), v.hotkeys, v?.faIcon))
}

let watch = [hoverHotkeysWatchedList, cursorPresent, isGamepad, safeAreaVerPadding]
function hoverHotkeyHints() {
  let showPcHoverHotkeys = cursorPresent.get()
    && !isGamepad.get()
    && hoverHotkeysWatchedList.get() != null
    && previewPreset.get() == null
  if (!showPcHoverHotkeys)
    return { watch }

  let children = getHotkeyHints(hoverHotkeysWatchedList.get())
  if (children.len() == 0)
    return { watch }
  let hotkeysBarHeight = height + panel_ver_padding
    + max(panel_ver_padding, safeAreaVerPadding.get())
  return {
    watch
    size = [SIZE_TO_CONTENT, hotkeysBarHeight]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    padding = [0, fsh(4),panel_ver_padding + fsh(2), max(fsh(5), safeAreaHorPadding.get())]
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    children
  }
}

function tooltipHotkeyHints() {
  let showPcHoverHotkeys = cursorPresent.get()
    && !isGamepad.get()
    && hoverHotkeysWatchedList.get() != null
    && previewPreset.get() == null
  if (!showPcHoverHotkeys)
    return { watch }

  let children = getHotkeyHints(hoverHotkeysWatchedList.get(), true)

  if (children.len() == 0)
    return { watch }
  return {
    watch
    vplace = ALIGN_BOTTOM
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    margin = fsh(1)
    children
  }
}

return {
  hoverHotkeysWatchedList
  hoverHotkeyHints
  tooltipHotkeyHints
}