import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason

from "%ui/ui_library.nut" import *

function mkDropMarkerFunc(sf, can_drop_dragged_cb, draggedDataWatch, txt=null) {
  return function() {
    let reason = draggedDataWatch.get() ? can_drop_dragged_cb?(draggedDataWatch.get()) : null
    local children = []

    if (reason == MoveForbidReason.NONE)
      children.append(dropMarker(sf.get(), false, txt))
    else if (reason == MoveForbidReason.VOLUME)
      children.append(dropMarker(sf.get(), true, txt))
    else if (reason == MoveForbidReason.TRYING_PUT_INTO_ITSELF)
      children.append(dropMarker(sf.get(), true, txt ?? loc("inventory/cannotPutContainerToItself")))
    else if (reason == MoveForbidReason.FORBIDDEN)
      children.append(dropMarker(sf.get(), true, ""))
    else if (reason == MoveForbidReason.FORBIDDEN_QUEUE_STATUS)
      children.append(dropMarker(sf.get(), true, loc("inventory/cannotPutToContainerDuringSearch")))
    else if (reason == MoveForbidReason.FORBIDDEN_READY_STATUS)
      children.append(dropMarker(sf.get(), true, loc("inventory/cannotPutToContainerDuringReady")))
    else if (reason == MoveForbidReason.PARENT_VOLUME_OVERFLOW)
      children.append(dropMarker(sf.get(), true, loc("inventory/parentVolumeOverflow")))
    else if (reason == MoveForbidReason.FORBIDDEN_REFINER_IN_PROGRESS)
      children.append(dropMarker(sf.get(), true, loc("inventory/refinerInProgress")))
    else if (reason == MoveForbidReason.FORBIDDEN_FOR_CONTAINER)
      children.append(dropMarker(sf.get(), true, loc("inventory/invalidContainer")))

    return {
      size = flex()
      watch = draggedDataWatch
      children
    }
  }
}

function mkDropMarkerSmallArea(sf, can_drop_dragged_cb, draggedDataWatch) {
  return function() {
    let reason = draggedDataWatch.get() ? can_drop_dragged_cb?(draggedDataWatch.get()) : null
    local children = []

    if (reason == null || reason == MoveForbidReason.OTHER) {
      children = null
    }
    else if (reason == MoveForbidReason.NONE)
      children.append(dropMarker(sf.get(), false))
    else
      children.append(dropMarker(sf.get(), true, ""))

    return {
      size = flex()
      watch = draggedDataWatch
      children
    }
  }
}

return {
  mkDropMarkerFunc
  mkDropMarkerSmallArea
}