from "%ui/ui_library.nut" import *

let {curWeapon} = require("%ui/hud/state/hero_weapons.nut")
let {totalGrenades} = require("%ui/hud/state/inventory_grenades_es.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")

let noHideShowWeapons = Watched(false)
let showWeapons = Computed(@() noHideShowWeapons.get() && !hideHud.get())

let offShowWeapons = @() noHideShowWeapons.set(false)

function activateShowWeapons(){
  noHideShowWeapons.set(true)
}

function activateShowWeaponsTimer(){
  gui_scene.resetTimeout(3, offShowWeapons)
}

function activateShowWeaponsWithTimer(){
  activateShowWeapons()
  activateShowWeaponsTimer()
}


function getCurrentWeaponShort(val = null) {
  let cweap = val ?? curWeapon.get()
  return {
    name = cweap?.name
    firingMode = cweap?.firingMode
  }
}

local prevWeapon = getCurrentWeaponShort()

curWeapon.subscribe(function(v) {
  let new_val = getCurrentWeaponShort(v)
  if (!isEqual(prevWeapon, new_val)) {
    activateShowWeaponsWithTimer()
  }
  prevWeapon = new_val
})

totalGrenades.subscribe(@(_) activateShowWeaponsWithTimer())

return{
  showWeapons
  activateShowWeapons
  activateShowWeaponsTimer
}