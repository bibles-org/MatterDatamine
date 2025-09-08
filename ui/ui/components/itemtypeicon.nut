from "%ui/ui_library.nut" import *

let itemSvgsTable = {
  assault_rifle = "assault_rifle.svg"
  pistol = "pistol.svg"
  rifle = "sniper_rifle.svg"
  semiauto = "semiauto_rifle.svg"
  machine_gun = "machine_gun.svg"
  submachine_gun = "submachine_gun.svg"
  shotgun = "shotgun.svg"
  launcher = "launcher.svg"
  melee = "melee.svg"
  flamethrower = "flamethrower.svg"
  scope = "scope.svg"
  mod = "artifact.svg"
  magazine = "ammunition.svg"
  armor = "armor.svg"
  food = "medkit_icon.svg"
  bag = "bagpack_icon.svg"
  grenade = "grenade.svg"
  heart = "heart.svg"
}

function mkItemTypeIcon(itemType, iconHeight){
  let itemSvg = itemSvgsTable?[itemType]
  return (itemSvg != null) ? Picture("ui/skin#{0}:{1}:{1}:K".subst(itemSvg, iconHeight.tointeger())) : null
}

return {
  mkItemTypeIco = memoize(mkItemTypeIcon)
}
