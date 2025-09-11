import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *


let heroJetfuel = require("%ui/hud/state/hero_jetpack_state_es.nut").jetfuel
let heroJetfuelAlert = require("%ui/hud/state/hero_jetpack_state_es.nut").fuelAlert
let heroLockJetpackUse = require("%ui/hud/state/hero_jetpack_state_es.nut").lockUse
let showInBoosters = require("%ui/hud/state/hero_jetpack_state_es.nut").showInBoosters

let colorBg = Color(30, 30, 50, 40)
let colorFg = Color(255, 70, 80, 255)
let colorLocked = Color(64, 64, 64, 255)
let colorWarn = Color(200,200,40,180)


let warningAnimations = [{ prop=AnimProp.color, from=colorFg, to=colorWarn, duration=1.0, play=true, loop=true, easing=CosineFull }]
let size = static [sw(7), fsh(0.4)]
let showJetFuel = Computed(@() heroJetfuel.get() != null && heroJetfuel.get() >= 0 && showInBoosters.get())
let showJetFuelAmount = Computed(@() heroJetfuel.get() != null && heroJetfuel.get() > 0 && heroJetfuel.get() < 100)

function jetfuelAmount(){
  if (!showJetFuelAmount.get())
    return {watch = showJetFuelAmount}

  let ratio = heroJetfuel.get() / 100.0
  let lowFuelWarning = heroJetfuelAlert.get() ? {
    rendObj = ROBJ_SOLID
    color = colorFg
    size = [size[0] * ratio, size[1]]
    animations = warningAnimations
  } : null

  return {
    rendObj = ROBJ_SOLID
    size = size
    color = colorBg
    halign = ALIGN_RIGHT
    valign = ALIGN_BOTTOM
    watch = [heroLockJetpackUse, heroJetfuel, showJetFuel, showJetFuelAmount]
    children = [
      {
        rendObj = ROBJ_SOLID
        color = heroLockJetpackUse.get() ? colorLocked : colorFg
        size = [size[0] * ratio, size[1]]
      }
      lowFuelWarning
    ]
    pos = [0, hdpx(6)]
  }
}

let icon = @() faComp("rocket", {
  watch = [heroLockJetpackUse,heroJetfuel]
  color = heroLockJetpackUse.get() || heroJetfuel.get() == 0 ? colorLocked : colorFg
  fontSize = hdpx(12)
})

function jetfuel() {
  let res = { watch = [heroJetfuel, heroJetfuelAlert, showJetFuel] }
  if (!showJetFuel.get())
    return res
  return res.__update({
    gap = hdpx(2)
    margin = static [0, 0, 0, fsh(1)]
    halign = ALIGN_RIGHT
    valign = ALIGN_BOTTOM
    children = [
      icon
      jetfuelAmount
    ]
  })
}

return jetfuel
