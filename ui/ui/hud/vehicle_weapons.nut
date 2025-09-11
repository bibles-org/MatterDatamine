import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import fontawesome
from "%ui/hud/state/vehicle_turret_state.nut" import vehicleTurrets, turretsReload, turretsReplenishment, turretsAmmo, showVehicleWeapons
from "%ui/hud/vehicle_weapon_widget.nut" import vehicleWeaponWidget
from "%ui/control/active_controls.nut" import isGamepad
import "%ui/components/mkBulletTypeIcon.nut" as mkBulletTypeIcon
from "net" import get_sync_time
import "%ui/components/fontawesome.map.nut" as fa
from "%ui/hud/replay/replay_hud_layout.nut" import isReplay

from "%ui/hud/tips/tipComponent.nut" import mkInputHintBlock


let defBgHudBlurColor = Color(30,30,30,80)
let smallPadding = hdpxi(4)
let vehicleWeaponWidth = hdpxi(400)

let reloadProgressSize = fsh(4.0)
let reloadImg = Picture("ui/skin#round_border.svg:{0}:{0}:K".subst(reloadProgressSize.tointeger()))
let reloadMoreOne = freeze({
  size = [fontH(100), SIZE_TO_CONTENT]
  rendObj = ROBJ_INSCRIPTION
  font = fontawesome.font
  color = Color(255, 86, 86)
  text = fa["arrow-down"]
  fontSize = hdpxi(10)
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
})
let reloadLessOne = freeze({
  size = [fontH(100), SIZE_TO_CONTENT]
  rendObj = ROBJ_INSCRIPTION
  font = fontawesome.font
  color = Color(86, 255, 86)
  text = fa["arrow-up"]
  fontSize = hdpxi(10)
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
})

let mkReloadProgress = @(from, to, duration, key, perksMult, stowageMult) {
  margin = static [0, 0, 0, hdpx(10)]
  rendObj = ROBJ_PROGRESS_CIRCULAR
  image = reloadImg
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_CENTER
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  size = [reloadProgressSize, reloadProgressSize]
  fValue = 0
  key
  flow = FLOW_HORIZONTAL
  children =
    perksMult < 1. && stowageMult <= 1.
      ? reloadLessOne
      : [
          perksMult > 1. ? reloadMoreOne : null,
          stowageMult > 1. ? reloadMoreOne : null
        ]
  animations = [
    { prop = AnimProp.fValue, from, to, duration, play = true}
  ]
}

let triggerGroupTurretControlTips = ["Vehicle.Shoot", "Vehicle.ShootSecondary", "Vehicle.ShootMachinegun", "Vehicle.ShootGrenadeLauncher"]
let defaultTurretControlTips = ["Vehicle.Shoot", "Vehicle.ShootSecondary", "Vehicle.ShootMachinegun", "Vehicle.ShootTurret03"]

function turretControlTip(turret, index) {
  let hotkey = turret?.hotkey
  let triggerGroup = turret?.triggerGroup ?? -1
  let gunEid = turret?.gunEid ?? ecs.INVALID_ENTITY_ID
  let turretReloadState = Computed(@() turretsReload.get()?[gunEid] ?? {})

  return function() {
    let { progressStopped = -1, totalTime = -1, endTime = -1, perksReloadTimeMult = 1.0,
      ammoStowageReloadTimeMult = 1.0 } = turretReloadState.get()
    let reloadTimeLeft = max(0, endTime - get_sync_time())
    let isReloadStopped = progressStopped >= 0
    let startProgress = isReloadStopped ? progressStopped
      : totalTime > 0 ? max(0, 1 - reloadTimeLeft / totalTime)
      : 0
    let endProgress = isReloadStopped ? progressStopped : 1
    let isReloading = endTime > 0
    return {
      watch = turretReloadState
      vplace = ALIGN_CENTER
      children = isReloading ? mkReloadProgress(startProgress, endProgress, reloadTimeLeft,
        turretReloadState.get(), perksReloadTimeMult, ammoStowageReloadTimeMult)
        : mkInputHintBlock(hotkey
          ?? (triggerGroup != -1 ? triggerGroupTurretControlTips[triggerGroup]
          : defaultTurretControlTips?[index]))
    }
  }
}

let triggerGroupNextBulletTips = ["Vehicle.NextBulletType", "Vehicle.SecondaryNextBulletType"]
function turretNextBulletTip(triggerGroup) {
  return mkInputHintBlock(triggerGroupNextBulletTips?[triggerGroup] ?? triggerGroupNextBulletTips[0])
}

function turretIconCtor(weapon, width, baseHeight) {
  let height = (0.8 * baseHeight).tointeger()
  let size = [width, height]
  let bulletIcon = mkBulletTypeIcon(weapon, size)
  return {
    size = size
    rendObj = ROBJ_IMAGE
    imageHalign = ALIGN_CENTER
    imageValign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = bulletIcon.image
    color = bulletIcon.color
    keepAspect = KEEP_ASPECT_FIT
  }
}

function vehicleTurretBlock(turret, idx) {
  if (!turret?.isControlled && !isReplay.get())
    return null

  if (!turret.isWithSeveralShells)
    return vehicleWeaponWidget({
      width = vehicleWeaponWidth
      weapon = turret.__merge({ instant = !turret.isReloadable, showZeroAmmo = true })
      hint = turretControlTip(turret, idx)
      iconCtor = turretIconCtor
      turretsAmmo
      turretsReplenishment
    })

  return function() {
    let activeAmmoSets = turret.ammoSet
      .map(@(ammoSet, setId) ammoSet.__merge({setId}))
      .filter(@(ammoSet) (ammoSet?.maxAmmo ?? 0) > 0)
    let ammoSetsCount = activeAmmoSets.len()
    let nextAmmoSetIndex = activeAmmoSets.findindex(@(set) set.setId == turret.nextAmmoSetId) ?? 0
    let switchToBulletIdx = activeAmmoSets?[(nextAmmoSetIndex + 1) % max(ammoSetsCount, 1)].setId
    let children = activeAmmoSets.map(function(bt) {
      let setId = bt.setId
      let isCurrent = turret.currentAmmoSetId == setId
      let weapon = turret.__merge({
        isCurrent = isCurrent
        isNext = turret.nextAmmoSetId == setId
        name = $"{bt.type}/name/short"
        bulletType = bt.type
        setId
        instant = !isCurrent || !turret.isReloadable
      })
      return vehicleWeaponWidget({
        width = vehicleWeaponWidth
        weapon = weapon
        hint = !turret.isControlled ? null
          : isCurrent ? turretControlTip(turret, idx)
          : setId == switchToBulletIdx ? turretNextBulletTip(turret?.triggerGroup)
          : null
        iconCtor = turretIconCtor
        turretsAmmo
        turretsReplenishment
      })
    })
    return {
      watch = isGamepad
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = children
    }
  }
}

return function() {
  let turretsChildren = []
  
  
  if (showVehicleWeapons.get())
    turretsChildren.extend(vehicleTurrets.get()?.turrets.map(vehicleTurretBlock))
  let turrets = turretsChildren.len() != 0 ? {
    flow = FLOW_VERTICAL
    gap = smallPadding
    children = turretsChildren
  } : null

  return {
    
    watch = [vehicleTurrets, showVehicleWeapons]
    rendObj = ROBJ_WORLD_BLUR
    fillColor = defBgHudBlurColor
    children = turrets
  }
}