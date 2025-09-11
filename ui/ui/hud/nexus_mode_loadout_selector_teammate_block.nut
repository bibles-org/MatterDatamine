from "%ui/components/colors.nut" import BtnBdSelected, InfoTextValueColor, ItemIconBlocked, BtnBgDisabled,
  TextNormal, TextDisabled, RedWarningColor, BtnBdHover, TeammateColor, TEAM0_TEXT_COLOR, ConsoleFillColor

from "%ui/fonts_style.nut" import h2_txt, sub_txt
from "%ui/components/commonComponents.nut" import mkText, defSound
from "%ui/hud/state/teammates_es.nut" import teammatesGetWatched
from "%ui/helpers/remap_nick.nut" import remap_nick
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeAttachments
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/faComp.nut" as faComp
from "team" import TEAM_UNASSIGNED
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode
from "%ui/components/button.nut" import button
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import  ceil

let { nexusSelectedNames, mutedNexusPlayersList, nexusModeTeamColors, nexusModeEnemiesColors
} = require("%ui/hud/state/nexus_mode_state.nut")
let { teammatesSet } = require("%ui/hud/state/teammates_es.nut")
let { localPlayerEid, localPlayerTeam, localPlayerName } = require("%ui/hud/state/local_player.nut")
let { allNexusLoadouts } = require("%ui/hud/state/nexus_loadout_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { mapSize } = require("%ui/hud/map/map_state.nut")
let { mute_player = @(...) null, unmute_player = @(...) null } = require_optional("%ui/voiceChat/voiceStateHandlers.nut")

let nexusTeammatesPlayerLoadoutInfo = Watched({})
let nexusEnemiesList = Watched({})
let showTeammates = Watched(true)
let showEnemies = Watched(false)

let nexus_track_player_loadout_info = function(eid, comp) {
  if (localPlayerTeam.get() == TEAM_UNASSIGNED)
    return
  if (comp.team != localPlayerTeam.get()) {
    nexusEnemiesList.mutate(@(value) value[eid] <- comp.name)
    return
  }
  let spawned = comp.possessed != ecs.INVALID_ENTITY_ID

  let chosenIndex = max(comp.nexus_player_loadout__chosenIndex, comp.nexus_player_loadout__takenIndex)
  let playerData = {
    spawned
    chosenIndex
    name = comp.name
    possessed = comp.possessed
    eid
  }
  nexusTeammatesPlayerLoadoutInfo.mutate(@(value) value[eid] <- playerData)
}

let nexus_players_loadout_info_query = ecs.SqQuery("nexus_players_loadout_info",
  {
    comps_ro = [
      ["team", ecs.TYPE_INT],
      ["possessed", ecs.TYPE_EID],
      ["nexus_player_loadout__chosenIndex", ecs.TYPE_INT],
      ["nexus_player_loadout__takenIndex", ecs.TYPE_INT],
      ["name", ecs.TYPE_STRING]
    ]
  }
)

localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v != TEAM_UNASSIGNED)
    nexus_players_loadout_info_query.perform(nexus_track_player_loadout_info)
  else {
    nexusTeammatesPlayerLoadoutInfo.set({})
    nexusEnemiesList.set({})
  }
})

ecs.register_es("nexus_track_unspawned_players", {
  [["onInit", "onChange"]] = function(_evt, eid, comp) {
    nexus_track_player_loadout_info(eid, comp)
  }

  onDestroy = function(eid, _comp) {
    if (eid in nexusTeammatesPlayerLoadoutInfo.get())
      nexusTeammatesPlayerLoadoutInfo.mutate(@(value) value.$rawdelete(eid))
  }
}, {
  comps_track = [
    ["team", ecs.TYPE_INT],
    ["possessed", ecs.TYPE_EID],
    ["nexus_player_loadout__chosenIndex", ecs.TYPE_INT],
    ["nexus_player_loadout__takenIndex", ecs.TYPE_INT]
  ],
  comps_ro = [["name", ecs.TYPE_STRING]]
}, {tags = "gameClient"})


let statusIconSize = hdpx(20)
let chooseMilitantStatusIcon = function(isAlive, isDowned) {
  return isDowned && isAlive
    ? static faComp("distress.svg", { color = Color(120,120,120), size = statusIconSize})
    : isAlive
      ? static faComp("heartbeat.svg", {color = Color(90, 230, 240), size = statusIconSize})
      : static faComp("skull.svg", {color = Color(20,20,20,140), size = statusIconSize})
}

let mkNotSpawnedIcon = chooseMilitantStatusIcon(false, false)
let weaponIconSize = static [hdpxi(70), hdpxi(35)]

function mkTeammateIcon(teammateWatched) {
  if (teammateWatched == null)
    return null
  return function() {
    let {isAlive=false, isDowned=false, possessedByPlr=null} = teammateWatched.get()
    return {
      watch = teammateWatched
      halign = ALIGN_CENTER
      padding = static [0, hdpx(2)]
      children = possessedByPlr == ecs.INVALID_ENTITY_ID
        ? mkNotSpawnedIcon
        : chooseMilitantStatusIcon(isAlive, isDowned)
      }
  }
}

let isSelected = @(name) name in nexusSelectedNames.get()

let mkSelectedLine = @(name) @() {
  rendObj = ROBJ_SOLID
  size = static [hdpx(4), flex()]
  margin = static [hdpx(2), hdpx(1)]
  watch = nexusSelectedNames
  color = isSelected(name) ? TEAM0_TEXT_COLOR : BtnBgDisabled
}

function mkSelectedWeaponComp(templateName, attachments, group){
  let image = itemIconNoBorder(templateName,
    static {
      width = weaponIconSize[0]
      height = weaponIconSize[1]
      silhouette = ItemIconBlocked
      shading = "full"
      vplace = ALIGN_CENTER
      margin = static [hdpx(4), 0, hdpx(4), 0]
    }, mkFakeAttachments(attachments))
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template?.getCompValNullable("item__name")
  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = static hdpx(8)
    valign = ALIGN_CENTER
    clipChildren = true
    children = [
      image
      mkText(loc(itemName), {
        size = FLEX_H
        scrollOnHover = true
        group
        behavior = Behaviors.Marquee
      }.__update(sub_txt) )
    ]
  }
}

function mkSelectedWeapon(loadoutData, group) {
  let { items = [] } = loadoutData
  let weapon = items.findvalue(@(v) v?.slotName == "weapon_0")
  if (weapon == null)
    return null
  let { itemId, templateName } = weapon
  let attachments = items
    .filter(@(v) v?.parentItemId == itemId)
    .map(@(v) v?.templateName)
  return mkSelectedWeaponComp(templateName, attachments, group)
}

let getSelWeaponPlaceHolder = @() {size = calc_comp_size(mkSelectedWeaponComp("hk_mp5n_gun", [], null))}


function muteUnmuteButton(name, isInteractive) {
  let isPlayerMuted = Computed(@() name in mutedNexusPlayersList.get())
  let muteBtnStateFlag = Watched(0)
  return function() {
    if (name == localPlayerName.get())
      return {
        watch = localPlayerName
        size = static [hdpx(32), flex()]
      }
    let color = isPlayerMuted.get() ? RedWarningColor : TextNormal
    let sf = muteBtnStateFlag.get()
    return {
      watch = [isPlayerMuted, muteBtnStateFlag, localPlayerName]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = FLEX_V
      behavior = isInteractive ? Behaviors.Button : null
      onElemState = function(s) {
        muteBtnStateFlag.set(s)
        local tip = null
        if (s & S_HOVER)
          tip = isPlayerMuted.get() ? loc("player/unmute") : loc("player/mute")
        setTooltip(tip)
      }
      sound = defSound
      onClick = function() {
        if (!isPlayerMuted.get()) {
          mute_player?(name)
          mutedNexusPlayersList.mutate(@(v) v[name] <- true)
        }
        else {
          unmute_player?(name)
          mutedNexusPlayersList.mutate(@(v) v.$rawdelete(name))
        }
      }
      children = {
        rendObj = ROBJ_BOX
        size = FLEX_V
        borderWidth = sf & S_HOVER ? hdpx(2) : 0
        borderColor = BtnBdHover
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        padding = static [0, hdpx(6)]
        children = [
          faComp("volume-up", { color, size = statusIconSize })
          !isPlayerMuted.get() ? null : {
            rendObj = ROBJ_VECTOR_CANVAS
            size = [statusIconSize, statusIconSize]
            commands = [
              [VECTOR_COLOR, color],
              static [VECTOR_LINE, 0, 0, 100, 100],
              static [VECTOR_LINE, 0, 100, 100, 0]
            ]
          }
        ]
      }
    }
  }
}

function mkTeammateBlock(data) {
  let { name, possessed, eid, chosenIndex = null} = data
  function onClick() {
    if (name not in nexusSelectedNames.get())
      nexusSelectedNames.mutate(@(v) v[name] <- true)
    else
      nexusSelectedNames.mutate(@(v) v.$rawdelete(name))
  }
  function onHover(on) {
    if (on && eid != localPlayerEid.get())
      setTooltip(isSelected(name) ? loc("nexus/deselectPlayer") : loc("nexus/selectPlayer"))
    else
      setTooltip(null)
  }
  let selLine = mkSelectedLine(name)
  let teammateWatched = teammatesGetWatched(possessed)
  let group = ElemGroup()
  return @() {
    watch = static [hudIsInteractive, localPlayerEid]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    children = [
      muteUnmuteButton(name, hudIsInteractive.get())
      {
        size = FLEX_H
        behavior = hudIsInteractive.get() && eid != localPlayerEid.get() ? Behaviors.Button : null
        onHover
        group
        onClick
        padding = static [0, hdpx(4)]
        flow = FLOW_HORIZONTAL
        rendObj = ROBJ_WORLD_BLUR_PANEL
        children = [
          selLine,
          @() {
            size = FLEX_H
            flow = FLOW_HORIZONTAL
            gap = static hdpx(4)
            valign = ALIGN_CENTER
            children = [
              mkTeammateIcon(teammateWatched),
              @() {
                size = static [flex(2), SIZE_TO_CONTENT]
                flow = FLOW_HORIZONTAL
                watch = [teammateWatched, localPlayerEid]
                gap = static hdpx(6)
                valign = ALIGN_CENTER
                padding = static hdpx(4)
                clipChildren = true
                children = mkText(remap_nick(name), {
                    size = FLEX_H
                    behavior = Behaviors.Marquee
                    color = localPlayerEid.get() == possessed
                      ? InfoTextValueColor
                      : (teammateWatched?.get().isAlive ?? true) ? TextNormal : TextDisabled
                  }.__update(sub_txt))
              },
              @() {
                size = static [flex(3), SIZE_TO_CONTENT]
                watch = [allNexusLoadouts, teammateWatched]
                children  = !(teammateWatched?.get().isAlive ?? true) || allNexusLoadouts.get()?[eid][chosenIndex] == null
                  ? getSelWeaponPlaceHolder()
                  : mkSelectedWeapon(allNexusLoadouts.get()[eid][chosenIndex], group)
              }
            ]
          }
        ]
      }
    ]
  }
}

nexusTeammatesPlayerLoadoutInfo.subscribe_with_nasty_disregard_of_frp_update(function(data) {
  if (!isStreamerMode.get() || (data.len() ?? {}) <= 0)
    return
  data.values().each(function(player) {
    let { name } = player
    if (name != localPlayerName.get())
      mutedNexusPlayersList.mutate(@(v) v[name] <- true)
  })
})

let teammatesContent = @() {
  watch = [teammatesSet, nexusTeammatesPlayerLoadoutInfo, showTeammates]
  size = static [hdpx(340), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = static hdpx(4)
  halign = ALIGN_CENTER
  children = !showTeammates.get() ? null
    : nexusTeammatesPlayerLoadoutInfo.get().values()
      .sort(@(a, b) teammatesGetWatched(b?.possessed)?.get().isAlive <=> teammatesGetWatched(a?.possessed)?.get().isAlive || a.name <=> b.name)
      .map(@(data) mkTeammateBlock(data))
}

let teammateColor = @() {
  watch = nexusModeTeamColors
  flow = FLOW_VERTICAL
  rendObj = ROBJ_BOX
  fillColor = Color(0, 0, 0)
  size = static [hdpx(50), flex()]
  gap = hdpx(1)
  padding = hdpx(1)
  children = [
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeTeamColors.get()[0]
      size = flex()
    },
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeTeamColors.get()[1]
      size = flex()
    }
  ]
}

let teammatesHeader = @() {
  watch = [showTeammates, hudIsInteractive]
  size = FLEX_H
  children = button({
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    size = FLEX_H
    children = [
      mkText(loc("nexus/playerTeam"), h2_txt)
      faComp(showTeammates.get() ? "chevron-down" : "chevron-up", { size = statusIconSize })
      {size = flex()}
      teammateColor
    ]
  }, @() showTeammates.modify(@(v) !v), {
    size = FLEX_H
    padding = static hdpx(4)
    isInteractive = hudIsInteractive.get()
    style = { BtnBgNormal = ConsoleFillColor }
  })
}

function teammatesBlock() {
  let mapGap = hdpxi(mapSize[0] * 0.025)
  let blockHeight = mapSize[1] + mapGap * 3 + hdpx(32)
  return {
    minHeight = blockHeight
    flow = FLOW_VERTICAL
    gap = static hdpx(8)
    vplace = ALIGN_CENTER
    children = [
      teammatesHeader
      teammatesContent
    ]
  }
}

let enemiesColor = @() {
  watch = nexusModeEnemiesColors
  flow = FLOW_VERTICAL
  rendObj = ROBJ_BOX
  fillColor = Color(0, 0, 0)
  size = static [hdpx(50), flex()]
  gap = hdpx(1)
  padding = hdpx(1)
  children = [
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeEnemiesColors.get()[0]
      size = flex()
    },
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeEnemiesColors.get()[1]
      size = flex()
    }
  ]
}

let enemiesHeader = @() {
  watch = [showEnemies, hudIsInteractive]
  size = FLEX_H
  children = button({
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    size = FLEX_H
    children = [
      mkText(loc("nexus/enemyTeam"), h2_txt)
      faComp(showEnemies.get() ? "chevron-down" : "chevron-up", { size = statusIconSize })
      {size = flex()}
      enemiesColor
    ]
  }, @() showEnemies.modify(@(v) !v), {
    size = FLEX_H
    padding = static hdpx(4)
    isInteractive = hudIsInteractive.get()
    style = { BtnBgNormal = ConsoleFillColor }
  })
}

let mkEnemiesBlock = @(name) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = static [flex(), hdpx(43)]
  padding = static [0, hdpx(4)]
  valign = ALIGN_CENTER
  children = mkText(remap_nick(name), {
    size = FLEX_H
    behavior = Behaviors.Marquee
  })
}

let enemiesContent = @() {
  watch = [nexusEnemiesList, showEnemies]
  size = static [hdpx(230), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = static hdpx(4)
  halign = ALIGN_CENTER
  children = !showEnemies.get() ? null
    : nexusEnemiesList.get().len() <= 0 ? mkText(loc("controls/activeSearchEmpty"))
    : nexusEnemiesList.get().values()
        .sort(@(a, b) a <=> b)
        .map(@(name) mkEnemiesBlock(name))
}

let mapGap = hdpxi(mapSize[0] * 0.025)
let blockHeight = mapSize[1] + mapGap * 3 + hdpx(32)
function enemiesBlock() {
  return {
    minHeight = blockHeight
    flow = FLOW_VERTICAL
    gap = hdpx(8)
    vplace = ALIGN_CENTER
    children = [
      enemiesHeader
      enemiesContent
    ]
  }
}

return {
  teammatesBlock
  enemiesBlock
}
