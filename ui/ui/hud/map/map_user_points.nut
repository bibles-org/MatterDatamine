from "%ui/components/colors.nut" import TextNormal, RedWarningColor, BtnBgActive, BtnBgDisabled, SelBgNormal, MapIconHover, MapIconEnable, TextNormal, TeammateColor
from "%ui/components/commonComponents.nut" import mkText
from "%ui/hud/state/interactive_state.nut" import hudIsInteractive
from "%ui/hud/state/user_points.nut" import user_points, teammatesPointsOpacity, playerPointsOpacity
from "%ui/squad/squad_colors.nut" import orderedTeamNicks
from "%ui/ui_library.nut" import *
from "dasevents" import CmdDeleteMapUserPoint, sendNetEvent


let markSz = [hdpxi(20), hdpxi(20)]
let number_st = {textPos = [0, hdpx(-2)], pos = [0, -0.5 * markSz[1]] }

let user_points_icons = freeze({
  pin_1 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "1" }.__update(number_st)
  pin_2 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "2" }.__update(number_st),
  pin_3 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "3" }.__update(number_st),
  pin_4 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "4" }.__update(number_st),
  pin_5 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "5" }.__update(number_st),
  pin_6 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "6" }.__update(number_st),
  pin_7 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "7" }.__update(number_st),
  pin_8 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "8" }.__update(number_st),
  pin_9 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "9" }.__update(number_st),
  pin_0 = { icon = "ui/uiskin/user_points/map_pin.svg", text = "0" }.__update(number_st),

  box_a = { icon = "ui/uiskin/user_points/map_box.svg", text = "A" }
  box_b = { icon = "ui/uiskin/user_points/map_box.svg", text = "B" }
  box_c = { icon = "ui/uiskin/user_points/map_box.svg", text = "C" }
  box_d = { icon = "ui/uiskin/user_points/map_box.svg", text = "D" }
  box_e = { icon = "ui/uiskin/user_points/map_box.svg", text = "E" }
  box_f = { icon = "ui/uiskin/user_points/map_box.svg", text = "F" }
  box_g = { icon = "ui/uiskin/user_points/map_box.svg", text = "G" }
  box_h = { icon = "ui/uiskin/user_points/map_box.svg", text = "H" }
  box_i = { icon = "ui/uiskin/user_points/map_box.svg", text = "I" }
  box_j = { icon = "ui/uiskin/user_points/map_box.svg", text = "J" }

  operative = { icon = "ui/uiskin/user_points/operative.svg" }
  turned_soldier = { icon = "ui/uiskin/user_points/turned_soldier.svg" }
  distorted = { icon = "ui/uiskin/user_points/distorted.svg" }
  flowerman = { icon = "ui/uiskin/user_points/flowerman.svg" }
  dendroid = { icon = "ui/uiskin/user_points/dendroid.svg" }
  devourer = { icon = "ui/uiskin/user_points/devourer.svg" }
  invisible = { icon = "ui/uiskin/user_points/invisible.svg" }
  hellhound = { icon = "ui/uiskin/user_points/hellhound.svg" }
  mimic = { icon = "ui/uiskin/user_points/mimic.svg" }
  mothman = { icon = "ui/uiskin/user_points/mothman.svg" }

  lightning = { icon = "ui/uiskin/user_points/lightning.svg" }
  seed = { icon = "ui/uiskin/user_points/seed.svg" }
  grav = { icon = "ui/uiskin/user_points/grav.svg" }
  flame = { icon = "ui/uiskin/user_points/flame.svg" }
  statue = { icon = "ui/uiskin/user_points/statue.svg" }
  swarm = { icon = "ui/uiskin/user_points/swarm.svg" }
  boss = { icon = "ui/uiskin/user_points/boss.svg" }
  unknown = { icon = "ui/uiskin/user_points/unknown.svg" }
  activity_helper_point = { icon = "ui/skin#eye.svg" }
  research = { icon = "ui/uiskin/user_points/research.svg" }

  squad_1 = { icon = "ui/uiskin/user_points/squad_1.svg" }
  squad_2 = { icon = "ui/uiskin/user_points/squad_2.svg" }
  squad_3 = { icon = "ui/uiskin/user_points/squad_3.svg" }
  squad_4 = { icon = "ui/uiskin/user_points/squad_4.svg" }
  dif_easy = { icon = "ui/uiskin/user_points/dif_easy.svg" }
  dif_norm = { icon = "ui/uiskin/user_points/dif_norm.svg" }
  dif_hard = { icon = "ui/uiskin/user_points/dif_hard.svg" }
  pvp_assault = { icon = "ui/uiskin/user_points/pvp_assault.svg" }
  pvp_clash = { icon = "ui/uiskin/user_points/pvp_clash.svg" }
  pvp_domination = { icon = "ui/uiskin/user_points/pvp_domination.svg" }

  pvp = { icon = "ui/uiskin/user_points/pvp.svg" }
  assault = { icon = "ui/uiskin/user_points/assault.svg" }
  collect = { icon = "ui/uiskin/user_points/collect.svg" }
  defend = { icon = "ui/uiskin/user_points/defend.svg" }
  hunt = { icon = "ui/uiskin/user_points/hunt.svg" }
  battleroyale = { icon = "ui/uiskin/user_points/battleroyale.svg" }
})

let generic_user_points_order = freeze([
  "pin_1",
  "pin_2",
  "pin_3",
  "pin_4",
  "pin_5",
  "pin_6",
  "pin_7",
  "pin_8",
  "pin_9",
  "pin_0",

  "box_a",
  "box_b",
  "box_c",
  "box_d",
  "box_e",
  "box_f",
  "box_g",
  "box_h",
  "box_i",
  "box_j",
])

let user_points_order = freeze([].extend(generic_user_points_order, [
  "operative",
  "turned_soldier",
  "distorted",
  "flowerman",
  "dendroid",
  "devourer",
  "invisible",
  "hellhound",
  "mimic",
  "mothman",

  "lightning",
  "seed",
  "grav",
  "flame",
  "statue",
  "swarm",
  "boss",
  "unknown",
  "activity_helper_point",
  "research",

  "squad_1",
  "squad_2",
  "squad_3",
  "squad_4",
  "dif_easy",
  "dif_norm",
  "dif_hard",
  "pvp_assault",
  "pvp_clash",
  "pvp_domination",

  "pvp",
  "assault",
  "collect",
  "defend",
  "hunt",
  "battleroyale",
]))

function mkMark(eid, marker) {
  let { byLocalPlayer = false, playerNick = null } = marker
  let size = markSz
  let iconDesc = user_points_icons?[marker.userPointType]
  let iconName = iconDesc?.icon ?? user_points_icons.pin_1

  let sf = Watched(0)

  let watch = byLocalPlayer ? [playerPointsOpacity, sf, orderedTeamNicks] : [teammatesPointsOpacity, sf, orderedTeamNicks]
  let icon = function() {
    let colorIdx = orderedTeamNicks.get().findindex(@(v) v == playerNick) ?? 0
    let color = TeammateColor?[colorIdx]
    return {
      watch
      size
      onElemState = @(s) sf.set(s)
      rendObj = ROBJ_IMAGE
      color = sf.get() & S_HOVER ? MapIconHover : color
      image = Picture($"{iconName}:{markSz[0]}:{markSz[1]}:P")
      behavior = hudIsInteractive.get() ? Behaviors.Button : null
      onClick = byLocalPlayer ? @() sendNetEvent(eid, CmdDeleteMapUserPoint()) : null
      opacity = byLocalPlayer ? playerPointsOpacity.get() : teammatesPointsOpacity.get()
      pos = iconDesc?.pos
      children = iconDesc?.text ? mkText(iconDesc?.text, {
        color = sf.get() & S_HOVER ? MapIconHover : color
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        size = flex()
        pos = iconDesc?.textPos
      }) : null
    }
  }

  return {
    key = eid
    data = {
      eid
      clampToBorder = true
    }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    transform = static {}

    children = icon
  }
}


let mkUserPoints = @(state) {
  watch = state
  function ctor(_) {
    let res = []
    foreach(eid, info in state.get())
      res.append(mkMark(eid, info))

    return res
  }
}

return {
  markSz
  userPoints = mkUserPoints(user_points)
  user_points_order
  generic_user_points_order
  user_points_icons
}
