from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkText } = require("%ui/components/commonComponents.nut")
let { tiny_txt } = require("%ui/fonts_style.nut")
let { focusedData, draggedData, isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { BtnBgActive } = require("%ui/components/colors.nut")
let { fabs } = require("math")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")

let focusedItemVolumeTextColor = Color(224, 202, 58, 255)
let itemVolumeColor = Color(186, 186, 186, 255)
let overVolumeColor = Color(228, 72, 68, 255)

let volumeProgressBlinkInventory = [
  {prop = AnimProp.opacity, from = 0.4, to = 1.0, duration = 2.0 , loop = true, play = true, easing = CosineFull}
]

let mkProgress = function(progress, focused, maxVolume, override = {}) {
  let currentProgress = progress.tofloat() / maxVolume.tofloat() * 100
  let overvolume = progress + focused > maxVolume
  let focusedProgress = overvolume ? 0 : focused.tofloat() / maxVolume.tofloat() * 100
  let hasFocused = focusedProgress != 0
  return {
    key = focused
    rendObj = ROBJ_SOLID
    size = [ flex(), hdpx(4) ]
    color = Color(0, 0, 0, 50)
    children = [
      {
        rendObj = ROBJ_SOLID
        color = currentProgress > 100 ? overVolumeColor : itemVolumeColor
        size = [ pw(min(currentProgress, 100)), flex() ]
      }.__update(override),
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

function mkVolumeText(curvolume, maxVolume, focusedVolume, override = {}) {
  let focusedStr = $"({focusedVolume > 0 ? "+" : ""}{fabs(focusedVolume)})"
  let overweight = curvolume + focusedVolume > maxVolume
  return {
    size = [flex(), SIZE_TO_CONTENT]
    children = [
      {
        hplace = ALIGN_LEFT
        vplace = ALIGN_BOTTOM
        flow = FLOW_HORIZONTAL
        gap = hdpx(2)
        children = [
          mkText(curvolume, override.__update(tiny_txt))
          !focusedVolume ? null
            : mkText(focusedStr, { color = overweight ? overVolumeColor : focusedItemVolumeTextColor }
                .__update(tiny_txt, override))
        ]
      }
      {
        hplace = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
        children = mkText(loc("desc/volume_no_dots"), override)
      }
      {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        children = mkText(maxVolume, override.__update(tiny_txt))
      }
    ]
  }
}

let volumeHdrHeight = calc_comp_size(mkProgress(1,1,1))[1] + calc_comp_size(mkVolumeText(1,1,1))[1] + hdpx(2) 

function mkVolumeHdr(carried, max_volume, inventory_item_type, eid = ecs.INVALID_ENTITY_ID, override = {}) {
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
    return (usedFocused ? focusedVolume : draggedVolume) * sign
  })

  let trashBinVolume = Computed(function() {
    let itemsInTrash = trashBinItems.get()
    local itemsVolume = 0
    foreach (item in itemsInTrash) {
      let { volume = 0, trashBinItemOrigin = {}, count = 1 } = item
      if (inventory_item_type != trashBinItemOrigin?.name)
        continue
      itemsVolume += volume * count
    }
    if (itemsVolume == 0)
      return null
    return -itemsVolume
  })

  return @() {
    watch = [carried, max_volume, focusedVolume, trashBinVolume]
    size = const [ flex(), volumeHdrHeight ]
    valign = ALIGN_CENTER
    children = max_volume.get() > 0.0 ? [
      blinkingOverlay(eid),
      {
        flow = FLOW_VERTICAL
        size = const [ flex(), volumeHdrHeight ]
        gap = hdpx(2)
        children = [
          mkVolumeText(carried.get(), max_volume.get(), trashBinVolume.get() ?? focusedVolume.get(), override)
          mkProgress(carried.get().tofloat(), (trashBinVolume.get() ?? focusedVolume.get()).tofloat(),
            max_volume.get().tofloat(), override)
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