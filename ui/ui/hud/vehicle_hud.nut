from "%ui/fonts_style.nut" import fontawesome, basic_text_shadow
from "math" import fabs
from "%ui/components/commonComponents.nut" import mkText
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa

let { isDriver, inShip, inPlane } = require("%ui/hud/state/vehicle_state.nut")
let {gear, neutralGear, rpm, speed, isAutomaticTransmission,
  bodyHpRel, engineHpRel, transmissionHpRel} = require("%ui/hud/state/vehicle_view_state.nut")
let { vehicleFuel, vehicleMaxFuel, vehicleFuelAlert } = require("%ui/hud/state/vehicle_fuel_state.nut")


let colorFg = Color(235, 120, 40)
let colorBg = Color(80, 60, 40)
let colorWarn1 = Color(255, 180, 140, 255)
let colorWarn2 = Color(255, 180, 140, 0)

let warningAnimations = [{ prop=AnimProp.color, from=colorWarn1, to=colorWarn2, duration=1.0, play=true, loop=true, easing=CosineFull }]
let pbSize = [hdpx(120), hdpx(8)]

let textStyle = {minWidth = fsh(4)}.__update(basic_text_shadow)
let mkLabel = @(txt) mkText(txt, textStyle)

let mkRow = @(children, gap = 0) {
  children = children
  valign = ALIGN_BOTTOM
  flow = FLOW_HORIZONTAL
  gap
}

let mkGear = @(g, neutral) g < neutral ? $"R{g == 0 ? "" : neutral-g}" : g == neutral ? "N" : $"{g-neutral}"


function mkProgressBar(value, maxValue, fgColor, bgColor) {
  return @(){
    size = pbSize
    margin = static [0,0,0, hdpx(2)]
    vplace = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = bgColor
    watch = [value, maxValue]
    children = {
      size = flex()
      rendObj = ROBJ_SOLID
      color = fgColor
      transform = {
        scale = [maxValue.get() > 0 ? (value.get() / maxValue.get()) : 0, 1.0]
        pivot = [0.0, 0.5]
      }
    }
  }
}


function fuelPb(){
  return @(){
    vplace = ALIGN_CENTER
    watch = [vehicleFuelAlert]
    children = [
      vehicleFuelAlert.get() ? {
        rendObj = ROBJ_SOLID
        color = colorFg
        size = [pbSize[0] + hdpx(4), pbSize[1] + hdpx(4)]
        animations = warningAnimations
      } : null
      mkProgressBar(vehicleFuel, vehicleMaxFuel, colorFg, colorBg)
    ]
  }
}

let damagePartWarningColorPecent = 0.5
let damagePartCriticalColorPecent = 0.25

function getDamagedPartIconColor(hp_rel) {
  if (hp_rel > damagePartWarningColorPecent)
    return Color(255, 255, 255)
  else if (hp_rel > damagePartCriticalColorPecent)
    return Color(252, 209, 42)
  else if (hp_rel > 0.0)
    return Color(255, 95, 31)

  return Color(255, 10, 10)
}

function mkDamagedPartIcon(icon_name, hp_rel, icon_scale = 1.0){
  let iconSize = sh(2 * icon_scale)
  return @(){
    rendObj = ROBJ_IMAGE
    image = Picture("!ui/skin#{0}.svg:{1}:{1}:K".subst(icon_name, sh(3)))
    size = iconSize
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    color = getDamagedPartIconColor(hp_rel)
  }
}

function mkDamagedPartIconFontAwesome(icon_name, hp_rel, icon_scale = 1.0){
  let fontSize = fsh(1.5 * icon_scale)
  return @(){
    size = SIZE_TO_CONTENT
    rendObj = ROBJ_TEXT
    font = fontawesome.font
    text = fa[icon_name]
    fontSize
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    color = getDamagedPartIconColor(hp_rel)
  }
}
let noHpColor = Color(255, 10, 10)
return @() {
  size = FLEX_H
  flow = FLOW_VERTICAL
  watch = [gear, rpm, speed, isAutomaticTransmission, isDriver, bodyHpRel, engineHpRel, transmissionHpRel]
  children = !isDriver.get() || inShip.get() || inPlane.get() ? null : [
    mkRow([
      mkLabel(loc("hud/vehicle_gb_type", "Gearbox manager"))
      isAutomaticTransmission.get()
        ? mkText(loc("hud/vehicle_gb_at", "Game"))
        : mkText(loc("hud/vehicle_gb_manual", "Player"), { color = Color(64, 255, 64) })
    ])
    mkRow([
      mkLabel(loc("hud/vehicle_gear", "Gear"))
      isAutomaticTransmission.get() || gear.get() != neutralGear.get()
        ? mkText(mkGear(gear.get(), neutralGear.get()))
        : mkText(mkGear(gear.get(), neutralGear.get()), { color = Color(255, 64, 64) })
    ])
    mkRow([
      mkLabel(loc("hud/vehicle_rpm", "RPM"))
      mkText($"{rpm.get()}")
    ])
    mkRow([
      mkLabel(loc("hud/vehicle_speed", "SPD"))
      mkText("{0} {1}".subst(fabs(speed.get() ?? 0), loc("hud/vehicle_spd_dimension", "km/h")))
    ])
    vehicleMaxFuel.get() > 0 ?
      mkRow([
        mkLabel(loc("hud/vehicle_fuel", "Fuel"))
        fuelPb()
      ]) : null
    mkRow([
      bodyHpRel.get()<= damagePartWarningColorPecent ? mkDamagedPartIconFontAwesome("automobile", bodyHpRel.get()) : null
      engineHpRel.get() <= damagePartWarningColorPecent ? mkDamagedPartIcon("engine", engineHpRel.get()) : null
      transmissionHpRel.get() <= damagePartWarningColorPecent ? mkDamagedPartIconFontAwesome("gears", transmissionHpRel.get()) : null
      vehicleMaxFuel.get() > 0 && vehicleFuel.get() / vehicleMaxFuel.get() <= damagePartWarningColorPecent ? mkDamagedPartIcon("gas-station", vehicleFuel.get() / vehicleMaxFuel.get(), 0.8) : null
      ], 5.0)
    engineHpRel.get() <= 0.0 ?
      mkRow([
        mkText(loc("hud/vehicle_engine_broken", "Engine is broken"), { color = noHpColor })
      ]) : null
    transmissionHpRel.get() <= 0.0 ?
      mkRow([
        mkText(loc("hud/vehicle_transmission_broken", "Transmission is broken"), { color = noHpColor })
      ]) : null
    bodyHpRel.get() <= 0.0 ?
      mkRow([
        mkText(loc("hud/vehicle_car_broken", "Car is broken"), { color = noHpColor })
      ]) : null
  ]
}
