from "%ui/ui_library.nut" import *

function blueprintBackgroundSelector(size, is_active){
  if (size[0] > hdpx(80) && is_active)
    return Picture("!ui/blueprint.avif")
  else if (size[0] > hdpx(80) && !is_active)
    return Picture("!ui/blueprint_disabled.avif")
  else if (size[0] <= hdpx(80) && is_active)
    return Picture("!ui/skin#blueprint_small.avif")
  else
    return Picture("!ui/skin#blueprint_small_disabled.avif")
}

let blueprintBackground = @(size, progress) {
  rendObj = ROBJ_IMAGE
  image = blueprintBackgroundSelector(size, progress >= 1.0)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  keepAspect = true
  size = size
  children = (progress < 1.0) ? {
    size = size
    rendObj = ROBJ_PROGRESS_CIRCULAR
    fValue = progress
    image = blueprintBackgroundSelector(size, true)
  } : null
}

let overridedIcons = {
  [20000] = "ui/skin#lootbox_icons/lootbox_weapon.svg",
  [40000] = "ui/skin#lootbox_icons/lootbox_gear.svg",
  [50000] = "ui/skin#lootbox_icons/lootbox_medicine.svg",
  [-1] = "ui/skin#question.svg"
}

return {
  blueprintBackgroundSelector
  blueprintBackground
  overridedIcons
}