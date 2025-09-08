from "%ui/ui_library.nut" import *
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let iconWidget = require("%ui/components/icon3d.nut")


let inventoryImageParams = {
  width=hdpx(62)
  height=hdpx(62)
  transform = {}
  animations=[]
  slotSize = [ itemHeight, itemHeight ]
}

let weaponIconParams  = {
  width=hdpx(320)
  height=hdpx(140)
  slotSize = [ hdpx(320), hdpx(140) ]
}
let weaponModIconParams = {
  animations=[]
  width=hdpx(62)
  height=hdpx(62)
  slotSize = [itemHeight, itemHeight ]
  outline=[64,64,64,12]
}
let smallInventoryImageParams = {
  width=hdpx(36)
  height=hdpx(36)
  transform = {}
  animations=[]
  slotSize = [ itemHeight / 1.5, itemHeight / 1.5 ]
}
let largeInventoryImageParams = {
  width=hdpx(240)
  height=hdpx(240)
  transform = {}
  animations=[]
  slotSize = [ hdpx(240), hdpx(240) ]
}
let highInventoryImageParams = {
  width=hdpx(190)
  height=hdpx(320)
  transform = {}
  animations=[]
  slotSize = [ hdpx(190), hdpx(320) ]
}
let smallHighInventoryImageParams = {
  width=hdpx(45)
  height=hdpx(itemHeight)
  transform = {}
  animations=[]
  slotSize = [ hdpx(45), hdpx(itemHeight) ]
}

function itemIconImage(icon, imageSize, iconImageColor) {
  local imageName = icon
  if (icon && icon.contains(".svg")) {
    let height = imageSize[1].tointeger()
    imageName = $"{icon}:{height}:{height}:K"
  }
  return {
    size = imageSize
    rendObj = ROBJ_IMAGE
    image = icon ? Picture($"!ui/{imageName}?Ac") : null
    keepAspect = true
    color = iconImageColor
  }
}

return {
  function inventoryItemImage(item, itemIconParams=inventoryImageParams) {
    let empty = (item?.itemTemplate == "" || item?.itemTemplate == null) && item?.template == null
    local icon = null
    if (empty) {
      let imageSize = [ itemIconParams?.width ?? 0, itemIconParams?.height ?? 0 ]
      let nonItemImage = item?.iconImage ?? item?.defaultIcon
      icon = nonItemImage == "" ? null
        : itemIconImage(nonItemImage, imageSize, item?.iconImageColor ?? Color(255, 255, 255, 255))
    }
    else {
      icon = iconWidget(item, itemIconParams)
    }
    return {
      size = itemIconParams.slotSize
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = icon
      opacity = item?.opacity ?? 1.0
    }
  }

  function iconWeapon(weaponSlot) {
    return {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        opacity = weaponSlot?.isDefaultStubItem ? 0.6 : 1.0
        size = [SIZE_TO_CONTENT, SIZE_TO_CONTENT]
        children = iconWidget(weaponSlot, weaponIconParams)
      }
  }

  inventoryImageParams
  weaponModIconParams
  smallInventoryImageParams
  largeInventoryImageParams
  highInventoryImageParams
  smallHighInventoryImageParams
}

