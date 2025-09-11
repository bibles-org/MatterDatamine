from "das.human_weap" import unload_ammo_from_gun_to_inventory, is_inventory_have_volume_for_ammo, try_load_weapon_ammo_from_inventory

from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/state/inventory_eids_common.nut" import getInventoryEidByListType

from "%ui/ui_library.nut" import *

let { HERO_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

#allow-auto-freeze

let ammoPic = Picture("ui/skin#bullet.svg:{0}:{0}:P".subst(hdpxi(15)))
let unloadAmmoPic = Picture("ui/skin#unload_magazine.svg:{0}:{0}:P".subst(hdpxi(15)))
let loadAmmoPic = Picture("ui/skin#load_magazine.svg:{0}:{0}:P".subst(hdpxi(15)))
let BtnInactiveColor = Color(128, 128, 128)
let BtnActiveColor = Color(255, 255, 255)


function bulletInBarrelIndicator() {
  return {
    behavior = Behaviors.Button
    skipDirPadNav = true
    onHover = @(on) setTooltip(on ? loc("Inventory/bullet_in_barrel") : null)
    rendObj = ROBJ_IMAGE
    image = ammoPic
    size = static [ hdpx(7), hdpx(16) ]
    color = BtnInactiveColor
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
  }
}

function unloadAmmoAction(weapon, gun_slot) {
  let inventoryEid = getInventoryEidByListType(HERO_ITEM_CONTAINER)
  if (is_inventory_have_volume_for_ammo(inventoryEid, (weapon?.ammo.template ?? ""), (weapon?.curAmmo ?? 0)))
    unload_ammo_from_gun_to_inventory(gun_slot, inventoryEid)
  else
    anim_start($"inventory_capacity_blink_{inventoryEid}")
}

function unloadableBulletInBarrelIndicator(weapon, gun_slot) {
  let unloadBtnStateFlags = Watched(0)
  return @() {
    watch = unloadBtnStateFlags
    behavior = Behaviors.Button
    skipDirPadNav = true
    onClick = @() unloadAmmoAction(weapon, gun_slot)
    onElemState = @(s) unloadBtnStateFlags.set(s)
    sound = {
      click  = "ui_sounds/button_click"
    }
    onHover = @(on) setTooltip(on ? loc("Inventory/unload_bullet_from_barrel") : null)
    rendObj = ROBJ_IMAGE
    image = unloadAmmoPic
    size = hdpx(15)
    color = ((unloadBtnStateFlags.get() & S_HOVER)) ? BtnActiveColor : BtnInactiveColor
    margin = static [0,hdpx(3),hdpx(3),0]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
  }
}

function loadableBulletInBarrelIndicator(gun_slot) {
  let loadBtnStateFlags = Watched(0)
  function onLoadAmmoClick(){
    let inventoryEid = getInventoryEidByListType(HERO_ITEM_CONTAINER)
    try_load_weapon_ammo_from_inventory(gun_slot, inventoryEid)
  }

  return @() {
    watch = [ loadBtnStateFlags ]
    behavior = Behaviors.Button
    skipDirPadNav = true
    onClick = onLoadAmmoClick
    onElemState = @(s) loadBtnStateFlags.set(s)
    sound = {
      click  = "ui_sounds/button_click"
    }
    onHover = @(on) setTooltip(on ? loc("Inventory/load_bullet_to_barrel") : null)
    rendObj = ROBJ_IMAGE
    image = loadAmmoPic
    size = hdpx(15)
    color = ((loadBtnStateFlags.get() & S_HOVER)) ? BtnActiveColor : BtnInactiveColor
    margin = static [0,hdpx(3),hdpx(3),0]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
  }
}


return {
  bulletInBarrelIndicator
  unloadableBulletInBarrelIndicator
  unloadAmmoAction
  loadableBulletInBarrelIndicator
}
