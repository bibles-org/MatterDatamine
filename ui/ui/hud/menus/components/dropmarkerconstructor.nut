from "%ui/ui_library.nut" import *
let dropMarker = require("%ui/hud/menus/components/dropMarker.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")

function mkDropMarkerFunc(sf, can_drop_dragged_cb, draggedDataWatch, txt=null) {
  let forbidReason = Computed(@() draggedDataWatch.get() != null ? can_drop_dragged_cb?(draggedDataWatch.get()) : null)

  return function() {
    let reason = forbidReason.get()
    local children = []

    if (reason == MoveForbidReason.NONE) {
      children.append(dropMarker(sf.get(), false, txt))
    } else if (reason == MoveForbidReason.VOLUME) {
      children.append(dropMarker(sf.get(), true, txt))
    } else if (reason == MoveForbidReason.TRYING_PUT_INTO_ITSELF) {
      children.append(dropMarker(sf.get(), true, txt ?? loc("inventory/cannotPutContainerToItself")))
    }
    return {
      size = flex()
      watch = forbidReason
      children
    }
  }
}

return {
  mkDropMarkerFunc
}