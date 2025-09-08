import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tiny_txt} = require("%ui/fonts_style.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let {CmdDeleteMapUserPoint, sendNetEvent} = require("dasevents")
let { tiledMapExist } = require("%ui/hud/minimap/tiled_map_ctx.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { TeammateColor } = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")

let markSz = [fsh(2), fsh(2.6)]

function mkPointMarkerCtor(params = {image = null, colors = {myHover = Color(250,250,180,250), myDef = Color(250,250,50,250), foreignHover = Color(220,220,250,250), foreignDef = Color(180,180,250,250)}}){
  return function(eid, marker, options) {
    let {byLocalPlayer = false, customIcon = null, playerNick = null, name = ""} = marker

    let colorIdx = orderedTeamNicks.get().findindex(@(v) v == playerNick)
    let size = params?.size ?? markSz
    let pin = watchElemState(function(sf) {
      local color = TeammateColor?[colorIdx]
      if (color == null) {
        if (byLocalPlayer) {
          color = (sf & S_HOVER) ? params?.colors.myHover : params?.colors.myDef
        } else {
          color = (sf & S_HOVER) ? params?.colors.foreignHover : params?.colors.foreignDef
        }
      }

      return {
        size = size
        rendObj = ROBJ_IMAGE
        color = color
        image = params?.image ?? customIcon
        behavior = hudIsInteractive.get() && byLocalPlayer ? Behaviors.Button : null
        onClick = byLocalPlayer ? @()sendNetEvent(eid, CmdDeleteMapUserPoint()) : null
      }
    })

    let icon = {
      size
      
      pos = tiledMapExist.get() ? [0, -size[1]/2] : [-hdpx(12), 0]
      halign = ALIGN_CENTER
      valign = params?.valign ?? ALIGN_BOTTOM
      transform = options?.transform
      children = pin
    }

    let blurPanel = {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      pos = [0, -size[1]/2 - hdpx(2)]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = mkText(name, { fontFxFactor = hdpx(25) })
    }

    return {
      key = eid
      data = {
        eid = eid
        clampToBorder = true
      }
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      transform = {}

      children = [
        blurPanel
        icon
      ]
    }
  }
}

let getPlayerNickQuery = ecs.SqQuery("getPlayerplayerNickQuery", {comps_ro = [["name", ecs.TYPE_STRING]], comps_rq=["player"]})
function getPlayerplayerNick(playerEid) {
  if (playerEid == ecs.INVALID_ENTITY_ID)
    return null
  let playerNick = getPlayerNickQuery.perform(playerEid, @(_eid, comp) comp.playerNick)
  if (playerNick != null)
    return remap_nick(playerNick)
  return null
}

let getUserPointOwnerQuery = ecs.SqQuery("getUserPointOwnerQuery", {comps_ro = [["userPointOwner", ecs.TYPE_EID]]})
function getUserPointOwner(pointEid) {
  if (pointEid == ecs.INVALID_ENTITY_ID)
    return ecs.INVALID_ENTITY_ID
  return getUserPointOwnerQuery.perform(pointEid, @(_eid, comp) comp.userPointOwner)
}

function mkSpawnPointLabel(playerEid, color) {
  return {
    hplace = ALIGN_CENTER
    vplace = ALIGN_TOP
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    transform = {
      translate = [0, sh(1.6)]
    }
    size = [sh(20), SIZE_TO_CONTENT]
    borderRadius = hdpx(4)
    fillColor = Color(10,10,10,5)
    children = [
      {
        margin = [hdpx(3), hdpx(2)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        text = getPlayerplayerNick(playerEid)
        color = color
      }.__update(tiny_txt)
    ]
  }
}

function mkSpawnPointMarkerCtor(params = {image = null, colors = {myHover = Color(250,250,180,250), myDef = Color(250,250,50,250), foreignHover = Color(220,220,250,250), foreignDef = Color(180,180,250,250)}}){
  return function(eid, marker, options) {
    let {byLocalPlayer=false, customIcon = null} = marker

    let pin = watchElemState(function(sf) {
      local color
      if (byLocalPlayer) {
        color = (sf & S_HOVER) ? params?.colors.myHover : params?.colors.myDef
      } else {
        color = (sf & S_HOVER) ? params?.colors.foreignHover : params?.colors.foreignDef
      }

      let label = mkSpawnPointLabel(getUserPointOwner(eid), color)
      return {
        size = params?.size ?? markSz
        rendObj = ROBJ_IMAGE
        color = color
        image = params?.image ?? customIcon
        behavior = hudIsInteractive.get() && byLocalPlayer ? Behaviors.Button : null
        onClick = byLocalPlayer ? @()sendNetEvent(eid, CmdDeleteMapUserPoint()) : null

        children = byLocalPlayer ? null : label
      }
    })

    let icon = {
      size = [0, SIZE_TO_CONTENT]
      pos = [-hdpx(12), 0]
      halign = ALIGN_CENTER
      valign = params?.valign ?? ALIGN_BOTTOM
      transform = options?.transform
      children = [
        pin
      ]
    }

    return {
      key = eid
      data = {
        eid = eid
        clampToBorder = true
      }
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      transform = {}

      children = [icon]
    }
  }
}

return {
  mkPointMarkerCtor
  mkSpawnPointMarkerCtor
  mkSpawnPointLabel
}
