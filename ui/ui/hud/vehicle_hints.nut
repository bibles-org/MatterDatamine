from "%ui/fonts_style.nut" import sub_txt
from "%ui/control/active_controls.nut" import isGamepad
from "%ui/components/commonComponents.nut" import mkText
from "%ui/hud/state/teammates_es.nut" import teammatesGetWatched
from "math" import min
from "%ui/components/colors.nut" import TEAM0_TEXT_COLOR, TeammateColor, RedFailColor, TextNormal
from "%ui/components/controlHudHint.nut" import controlHudHint
from "%ui/squad/squad_colors.nut" import orderedTeamNicks
from "%ui/hud/state/nexus_mode_state.nut" import nexusSelectedNames
from "%ui/hud/state/local_player.nut" import localPlayerName
from "%ui/hud/state/controlled_hero.nut" import controlledHeroEid
from "%ui/hud/state/watched_hero.nut" import watchedHeroEid
from "%ui/hud/state/vehicle_state.nut" import inVehicle, inPlane, isVehicleAlive
from "%ui/hud/state/actions_state.nut" import useActionType
from "%ui/hud/human_actions.nut" import ACTION_USE


import "%ui/hud/state/vehicle_seats.nut" as vehicleSeatsState
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isAlive } = require("%ui/hud/state/health_state.nut")

let maxSeatsCountToShow = 10

function getPlayerNameColor(name, isPlayerAlive, orderedNicks, nexusSelectedList, localPName) {
  if (!isPlayerAlive)
    return RedFailColor
  let colorIdx = orderedNicks.findindex(@(v) v == name)
  if (colorIdx != null)
    return TeammateColor[colorIdx]
  let color = name in nexusSelectedList ? TEAM0_TEXT_COLOR
    : name == localPName ? TeammateColor[0]
    : TextNormal
  return color
}

function getSeatData(seatDesc, orderedNicks, nexusSelectedList, localPName) {
  let { owner, seat } = seatDesc
  local playerName = ""
  local color = TEAM0_TEXT_COLOR
  let teammateWatched = teammatesGetWatched(owner.eid)
  if (teammateWatched?.get() != null) {
    let { name = "" } = teammateWatched.get()
    color = getPlayerNameColor(name, teammateWatched.get()?.isAlive ?? true, orderedNicks,
      nexusSelectedList, localPName)
    playerName = name
  }
  let locId = seat?.locName ?? (seat?.name ? $"vehicle_seats/{seat.name}" : "")
  let place = loc(locId)
  return { name = playerName, place, color }
}

let seatHint = @(seat) function() {
  return {
    watch = isGamepad
    children = !seat.order.canPlaceManually || isGamepad.get()
      ? static { size = [0, hdpx(28)] }
      : controlHudHint({
          id = $"Human.Seat0{seat.order.seatNo + 1}"
          hplace = ALIGN_RIGHT
          text_params = sub_txt
        })
    }
}

let mkSeat = @(seat) function() {
  let { name, place, color } = getSeatData(seat, orderedTeamNicks.get(), nexusSelectedNames.get(), localPlayerName.get())
  return {
    watch = [orderedTeamNicks, nexusSelectedNames, localPlayerName]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_HORIZONTAL
    padding = static [0,0,0, hdpx(4)]
    valign = ALIGN_CENTER
    gap = static hdpx(4)
    children = [
      {
        flow = FLOW_HORIZONTAL
        gap = mkText(" — ")
        children = [
          name == "" ? null : mkText(name, { color })
          mkText(place)
        ]
      }
      seatHint(seat)
    ]
  }
}

function vehicleSeats() {
  let hasVehicleSeats = vehicleSeatsState.get().data.len() > 0
  if (!hasVehicleSeats)
    return { watch = vehicleSeatsState }

  let seatsToShow = min(vehicleSeatsState.get().data.len(), maxSeatsCountToShow)
  return {
    watch = vehicleSeatsState
    flow = FLOW_VERTICAL
    halign = ALIGN_RIGHT
    children = vehicleSeatsState.get().data
      .slice(0, seatsToShow)
      .map(mkSeat)
  }
}

let allowHints = Computed(@() controlledHeroEid.get() == watchedHeroEid.get()
  && controlledHeroEid.get() != ecs.INVALID_ENTITY_ID
  && inVehicle.get()
  && isVehicleAlive.get()
  && isAlive.get())

let showLeaveVehicleAction = Computed(@()
  allowHints.get()
  && !inPlane.get()
  && useActionType.get() == ACTION_USE)

function leaveVehicle() {
  if (!showLeaveVehicleAction.get())
    return { watch = [showLeaveVehicleAction] }
  return {
    watch = [showLeaveVehicleAction]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    flow = FLOW_HORIZONTAL
    padding = static [0,0,0, hdpx(4)]
    valign = ALIGN_CENTER
    gap = static hdpx(4)
    children = [
      mkText(loc("hud/leaveVehicle"))
      controlHudHint({
        id ="Human.Use"
        text_params = sub_txt
      })
    ]
  }
}


function vehicleHintsBlock() {
  if (!inVehicle.get())
    return { watch = inVehicle }

  return {
    flow = FLOW_VERTICAL
    gap = static hdpx(60)
    halign = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
    children = [
      vehicleSeats
      leaveVehicle
    ]
  }
}

return {
  vehicleHintsBlock
}