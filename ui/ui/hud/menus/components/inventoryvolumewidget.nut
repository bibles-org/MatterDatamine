from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/components/colors.nut" import BtnBgActive
from "math" import fabs
from "das.inventory" import get_inventory_content_volume

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { focusedData, draggedData, isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

#allow-auto-freeze

let focusedItemVolumeTextColor = Color(224, 202, 58, 255)
let itemVolumeColor = Color(186, 186, 186, 255)
let overVolumeColor = Color(228, 72, 68, 255)

let volumeProgressBlinkInventory = [
  {prop = AnimProp.opacity, from = 0.4, to = 1.0, duration = 2.0 , loop = true, play = true, easing = CosineFull}
]

let mkProgress = function(progress, focused, maxVolume) {
  let currentProgress = progress.tofloat() / maxVolume.tofloat() * 100
  let overvolume = progress + focused > maxVolume
  let focusedProgress = overvolume ? 0 : focused.tofloat() / maxVolume.tofloat() * 100
  let hasFocused = focusedProgress != 0
  return {
    key = focused
    rendObj = ROBJ_SOLID
    size = static [ flex(), hdpx(4) ]
    color = Color(0, 0, 0, 50)
    children = [
      {
        rendObj = ROBJ_SOLID
        color = currentProgress > 100 ? overVolumeColor : itemVolumeColor
        size = [ pw(min(currentProgress, 100)), flex() ]
      },
      hasFocused ? {
        rendObj = ROBJ_SOLID
        size = [ pw(min(fabs(focusedProgress), 100)), flex() ]
        pos = [ pw(min(currentProgress + min(focusedProgress, 0), 100)), 0 ]
        color = focusedProgress > 0.0 ? BtnBgActive : Color(72, 228, 68, 255)
        animations = volumeProgressBlinkInventory
      } : null,
      overvolume ? {
        rendObj = ROBJ_SOLID
        size = [ pw(min((maxVolume.tofloat() - progress) / maxVolume.tofloat() * 100, 100)), flex() ]
        pos = [ pw(min(currentProgress, 100)), 0 ]
        color = overVolumeColor
      } : null
    ]
  }
}

function blinkingOverlay(eid){
  return{
    size = flex()
    rendObj = ROBJ_SOLID
    color = Color(255, 100, 50, 255)
    opacity = 0
    animations = [
      {prop = AnimProp.opacity, from = 0, to = 0.65, duration = 0.6, trigger = $"inventory_capacity_blink_{eid}"easing = DoubleBlink}
    ]
  }
}

function mkVolumeText(curvolume, maxVolume, focusedVolume) {
  let focusedStr = $"({focusedVolume > 0 ? "+" : ""}{fabs(focusedVolume)})"
  let overweight = curvolume + focusedVolume > maxVolume
  return {
    size = FLEX_H
    children = [
      {
        hplace = ALIGN_LEFT
        vplace = ALIGN_BOTTOM
        flow = FLOW_HORIZONTAL
        gap = hdpx(2)
        children = [
          mkText(curvolume, tiny_txt)
          !focusedVolume ? null
            : mkText(focusedStr, { color = overweight ? overVolumeColor : focusedItemVolumeTextColor }
                .__update(tiny_txt))
        ]
      }
      {
        hplace = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
        children = mkText(loc("desc/volume_no_dots"))
      }
      {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        children = mkText(maxVolume, tiny_txt)
      }
    ]
  }
}

let volumeHdrHeight = calc_comp_size(mkProgress(1,1,1))[1] + calc_comp_size(mkVolumeText(1,1,1))[1] + hdpx(2) 

function mkVolumeHdr(carried, max_volume, inventory_item_type, eid = ecs.INVALID_ENTITY_ID) {
  let focusedVolume = Computed(function() {

    if ( focusedData.get()?.itemTemplate == "small_safepack"
      || focusedData.get()?.trashBinItemOrigin.name == inventory_item_type || focusedData.get()?.canDrop
    )
      return 0.0

    let sign = (focusedData.get()?.fromList?.name ?? draggedData.get()?.fromList?.name ?? "") == inventory_item_type ? -1.0 : 1.0
    let usedFocused = focusedData.get()?.volume != null
    
    let focusedVolume = isShiftPressed.get() ? (focusedData.get()?.count ?? 1) * (focusedData.get()?.volume ?? 0.0)
      : focusedData.get()?.currentStackVolume ?? 0.0
    let draggedVolume = isShiftPressed.get() ? (draggedData.get()?.count ?? 1) * (draggedData.get()?.volume ?? 0.0)
      : draggedData.get()?.currentStackVolume ?? 0.0
    let contentVolume = inventory_item_type == STASH.name && sign == 1.0 
      ? get_inventory_content_volume((usedFocused ? focusedData.get()?.eid : draggedData.get()?.eid) ?? ecs.INVALID_ENTITY_ID)
      : 0.0
    return (usedFocused ? focusedVolume : draggedVolume) * sign + contentVolume
  })

  let size = [ flex(), volumeHdrHeight ]
  return @() {
    watch = [carried, max_volume, focusedVolume]
    valign = ALIGN_CENTER
    size
    children = max_volume.get() > 0.0 ? [
      blinkingOverlay(eid),
      {
        flow = FLOW_VERTICAL
        size
        gap = hdpx(2)
        children = [
          mkVolumeText(carried.get(), max_volume.get(), focusedVolume.get())
          mkProgress(carried.get().tofloat(), (focusedVolume.get()).tofloat(),
            max_volume.get().tofloat())
        ]
      }
    ] : []
  }
}


return {
  mkVolumeHdr
  volumeHdrHeight
  itemVolumeColor
}