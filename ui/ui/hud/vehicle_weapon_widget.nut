import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let iconWidget = require("%ui/components/icon3d.nut")
let { get_sync_time } = require("net")
let { sub_txt } = require("%ui/fonts_style.nut")

let smallPadding = hdpxi(4)
let ammoColor = Color(100,100,100,50)
let curColor = Color(180,200,230,180)
let color = Color(168,168,168,150)
let curBorderColor = Color(235,155,50,120)
let nextBorderColor = Color(200, 200, 200, 100)


function itemAppearing(duration=0.2) {
  return {prop=AnimProp.opacity, from=0, to=1, duration=duration, play=true, easing=InOutCubic}
}
let wWidth = hdpx(280)
let aHgt = calc_str_box("A", sub_txt)[1]*2 
let wHeight = max(aHgt+hdpxi(2), hdpxi(40))


function weaponId(weapon, turretsAmmo) {
  let loadedGunInGroupEid = Computed(@() turretsAmmo.get()?[weapon.groupName].firstLoadedGunInGroup)
  return @() {
    watch = loadedGunInGroupEid
    size = FLEX_H
    vplace = ALIGN_CENTER
    halign = ALIGN_RIGHT
    rendObj = ROBJ_TEXT
    color = weapon?.isCurrent ? curColor : color
    text = loc(weapon?.namesInGroup[loadedGunInGroupEid.get()] ?? weapon.name)
    fontFx = FFT_BLUR
    fontFxColor = Color(0,0,0,80)
    behavior = Behaviors.Marquee
  }.__update(sub_txt)
}


function weaponAmmo(weapon, turretsAmmo) {
  let combinedAmmo = Computed(function() {
    let data = turretsAmmo.get()
    return (data?[weapon.gunEid] ?? {}).__merge({
      groupAmmo = data?[weapon.groupName].groupAmmo
      reloadAmmo = data?[weapon.groupName].reloadAmmo
    })
  })

  let instant = weapon?.instant
  let showZeroAmmo = weapon?.showZeroAmmo ?? false
  return function() {
    local { curAmmo = 0, totalAmmo = 0, ammoByBullet = [], reloadAmmo = 0,
      groupAmmo = 0, firstStageAmmo = 0 } = combinedAmmo.get()
    let setAmmo = ammoByBullet?[weapon?.setId]
    totalAmmo = reloadAmmo ?? totalAmmo
    if (setAmmo != null) {
      curAmmo = weapon?.isReloadable && weapon?.isCurrent ? curAmmo : 0
      totalAmmo = weapon?.isReloadable && weapon?.isCurrent ? totalAmmo
        : ammoByBullet?[weapon?.setId] ?? totalAmmo
    }
    curAmmo = groupAmmo ?? curAmmo
    local firstStage = ""
    if (!weapon?.isCurrent)
      firstStageAmmo = 0
    else if (firstStageAmmo > 0) {
      firstStageAmmo = min(firstStageAmmo, totalAmmo)
      firstStage = $"{firstStageAmmo}+"
      totalAmmo = totalAmmo - firstStageAmmo
    }
    let ammo_string = (totalAmmo + curAmmo + firstStageAmmo <= 0 && !showZeroAmmo) ? ""
      : instant ? $"{firstStage}{(totalAmmo + curAmmo)}"
      : (weapon?.isReloadable ?? false) ? $"{curAmmo}/{firstStage}{totalAmmo}"
      : $"{firstStage}{totalAmmo}"
    return {
      watch = combinedAmmo
      size = FLEX_H
      children = {
        size = FLEX_H
        rendObj = ROBJ_TEXT
        text = ammo_string
        color = weapon?.isCurrent ? curColor : ammoColor
        fontFx = FFT_BLUR
        fontFxColor = Color(0,0,0,80)
        key = totalAmmo + curAmmo
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        transform  = { pivot = [0.5,0.5] }
        animations = [{ prop = AnimProp.scale, from = [1.1,1.3], to = [1,1],
          duration = 0.2, play = true, easing = OutCubic }]
      }.__update(sub_txt)
    }
  }
}


let silhouetteDefColor=[200,200,200,200]
let silhouetteInactiveColor=[0,0,0,200]
let outlineDefColor=[0,0,0,0]
let outlineInactiveColor=[200,200,200,0]

let weaponWidgetAnims = [
  {prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true}
  itemAppearing()
]

function iconCtorDefault(weapon, width, height) {
  return iconWidget(weapon, {
    width = width
    height = height
    hplace = ALIGN_CENTER
    shading = "silhouette"
    silhouette = silhouetteDefColor
    outline = outlineDefColor
    silhouetteInactive = silhouetteInactiveColor
    outlineInactive = outlineInactiveColor
  })
}

let currentBorder = {
  size = flex(),
  rendObj = ROBJ_WORLD_BLUR_PANEL,
  borderWidth = 1,
  borderColor = curBorderColor,
  fillColor = 0x50000000
}
let nextBorder = {
  size = flex(),
  rendObj = ROBJ_BOX,
  borderWidth = 1,
  borderColor = nextBorderColor,
  fillColor = 0x20000000
  key = {},
  animations = [{ prop = AnimProp.opacity, from = 0.5, to = 1, duration = 1, play = true, loop = true, easing = CosineFull }]
}

let mkReplenishmentProgress = @(from, to, duration, key) {
  rendObj = ROBJ_PROGRESS_LINEAR
  imageHalign = ALIGN_CENTER
  imageValign = ALIGN_CENTER
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  fValue = 0
  size = flex()
  fgColor = Color(0,255,0)
  bgColor = Color(0,150,0)
  key
  animations = [
    { prop = AnimProp.fValue, from, to, duration, play = true }
  ]
}

function turretStowageReplenishmentTip(weapon, turretsReplenishment) {
  if (!weapon?.isControlled || !weapon?.isCurrent)
    return null
  let gunEid = weapon?.gunEid ?? ecs.INVALID_ENTITY_ID
  let turretReplenishmentState = Computed(@() turretsReplenishment.get()?[gunEid] ?? {})

  return function() {
    let { totalTime = -1, endTime = -1 } = turretReplenishmentState.get()
    let timeLeft = max(0, endTime - get_sync_time())
    let startProgress = totalTime > 0 ? max(0, 1 - timeLeft / totalTime) : 0
    let endProgress = 1
    let isReplenishing = endTime > 0
    return isReplenishing ? {
      watch = turretReplenishmentState
      valign = ALIGN_CENTER
      vplace = ALIGN_CENTER
      hplace = ALIGN_RIGHT
      margin = static [ 0, 0, 0, hdpxi(20) ]
      size = static [flex(), hdpxi(3)]
      children = mkReplenishmentProgress(startProgress, endProgress, timeLeft, turretReplenishmentState.get())
    } : { watch = turretReplenishmentState }
  }
}


function weaponWidget(weapon, turretsAmmo, turretsReplenishment, hint = null,
  width = wWidth, height = wHeight, iconCtor = iconCtorDefault
) {
  let markAsSelected = weapon?.isEquiping || (weapon?.isCurrent && !weapon?.isHolstering)
  let borderComp = markAsSelected ? currentBorder
    : weapon?.isNext ? nextBorder
    : null

  let iconWidth = (height * 1.3).tointeger()
  let iconHeight = (height - smallPadding * 2).tointeger()

  return {
    size = [width, height]
    animations = weaponWidgetAnims
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = smallPadding
    children = [
      {
        size = flex()
        clipChildren = true
        children = [
          borderComp
          {
            size = flex()
            clipChildren = true
            valign = ALIGN_CENTER
            children = ((weapon?.name ?? "") != "")
              ? {
                  size = flex()
                  padding = smallPadding
                  flow = FLOW_HORIZONTAL
                  gap = smallPadding
                  children = [
                    {
                      size = static [hdpx(90), SIZE_TO_CONTENT]
                      flow = FLOW_VERTICAL
                      vplace = ALIGN_CENTER
                      children = [
                        weaponAmmo(weapon, turretsAmmo)
                        turretStowageReplenishmentTip(weapon, turretsReplenishment)
                      ]
                    }
                    weaponId(weapon, turretsAmmo)
                    iconCtor(weapon, iconWidth, iconHeight)
                  ]
                }
              : null
          }
        ]
      }
      hint
    ]
  }
}

let vehicleWeaponWidget = kwarg(weaponWidget)

return {
  vehicleWeaponWidget
  wWidth
  wHeight
  weaponWidgetAnims
}