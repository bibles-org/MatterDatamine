from "%ui/components/colors.nut" import ContactNotReady, ContactInBattle, ContactLeader, ContactReady,
  ContactOffline, TeammateColor, UserNameColor, Inactive, Active, BtnBgHover, BtnTextVisualDisabled
from "%ui/fonts_style.nut" import h1_txt, body_txt, h2_txt
from "base64" import decodeString
from "%ui/fonts_style.nut" import sub_txt, fontawesome
from "%ui/components/sounds.nut" import buttonSound
from "%ui/mainMenu/contacts/contact.nut" import getContactNick
from "%ui/mainMenu/contacts/contactPresence.nut" import mkContactOnlineStatus
from "%ui/mainMenu/contacts/contactContextMenu.nut" import open
from "%ui/components/button.nut" import textButtonSmall, button
import "%ui/helpers/locByPlatform.nut" as locByPlatform
from "%ui/quickMatchQueue.nut" import leaveQueue
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/mainMenu/consoleRaidMenu.nut" import GameMode
from "%ui/hud/hud_menus_state.nut" import openMenu
import "%ui/components/faComp.nut" as faComp
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/cursors.nut" import setTooltip
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/hud/menus/components/damageModel.nut" import mkHeroDoll, mkSuitPreview, mkIconAttachments
from "das.ribbons_color" import get_color_as_array_by_index
from "%ui/hud/menus/components/inventoryItemsHeroWeapons.nut" import mkEquipmentWeaponsSmall
from "%ui/mainMenu/offline_raid_widget.nut" import mkOfflineRaidIcon
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/fontawesome.map.nut" as fa

let { squadMembers, isInvitedToSquad, enabledSquad, squadLeaderState, allMembersState } = require("%ui/squad/squadState.nut")
let { contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { friendsUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isSquadLeader, myExtSquadData, isInSquad } = require("%ui/squad/squadManager.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { Missions_id, selectedPlayerGameModeOption, prevSelectedZonesPerGameMode } = require("%ui/mainMenu/consoleRaidMenu.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")

let presenceIconHeight = hdpxi(8)
let statusIconHeight = hdpxi(15)
let contactHeight = hdpx(56)
let smallContactHeight = hdpx(30)


function squadReadyStatus() {
  if (!isInSquad.get() || isSquadLeader.get())
    return { watch = [isSquadLeader, isInSquad] }
  let ready = myExtSquadData.ready
  return {
    watch = [showCursor, ready, isSquadLeader, isInSquad]
    vplace = ALIGN_CENTER
    children = !ready.get() ? null : mkText(loc("mainmenu/btnReady"), { color = ContactReady })
  }
}

let mkUserNickname = @(contact, status) @() {
  watch = [status, userInfo, isStreamerMode, playerRandName]
  rendObj = ROBJ_TEXT
  padding = static [0, hdpx(4),0,0]
  color = contact.uid == userInfo.get()?.userId
    ? UserNameColor
    : status.get() ? Active : Inactive
  text = isStreamerMode.get() && contact.userId == userInfo.get().userId.tostring()
    ? playerRandName.get()
    : getContactNick(contact)
}.__update(sub_txt)

let mkPresenceIcon = memoize(@(status, fontSize=presenceIconHeight) @() {
  watch = status
  rendObj = ROBJ_INSCRIPTION
  size = [statusIconHeight, statusIconHeight]
  validateStaticText = false
  font = fontawesome.font
  halign = ALIGN_CENTER
  padding = hdpx(5)
  fontSize
  valign = ALIGN_CENTER
  color = status.get() == null ? Color(104, 86, 86)
    : status.get() ? Color(31, 205, 39)
    : Color(154, 26, 26)
  text = status.get() != null ? fa["circle"] : fa["circle-o"]
})

function contactActionButton(action, userId, sf) {
  let isVisible = action.mkIsVisible(userId)
  return @() {
    watch = isVisible
    margin = static [0,0,hdpx(2), 0]
    skipDirPadNav = true
    children = (isVisible.get() && (sf & S_HOVER))
      ? textButtonSmall(locByPlatform(action.locId), @() action.action(userId), { key = userId, skipDirPadNav = true })
      : null
  }
}

function getContactStatus(squadMember, isInvited, userId, friends, status) {
  local iconParams = null
  local textParams = null
  let isOnline = status == true
  if (squadMember) {
    if (squadMember.state?.inBattle) {
      iconParams = { color = ContactInBattle, text = fa["gamepad"], fontSize = statusIconHeight }
      textParams = { text = loc("contact/inBattle") }
    }
    else if (squadMember.isLeader) {
      iconParams = { color = ContactLeader, text = fa["star"], fontSize = statusIconHeight  }
      textParams = { text = loc("squad/Chief") }
    }
    else if (!isOnline) {
      iconParams = { color = ContactOffline, text = fa["times"], fontSize = statusIconHeight  }
      textParams = { text = loc("contact/Offline") }
    }
    else if (squadMember.state?.ready) {
      iconParams = { color = ContactReady, text = fa["check"], fontSize = statusIconHeight  }
      textParams = { text = loc("contact/Ready") }
    }
    else {
      iconParams = { color = ContactNotReady, text = fa["times"], fontSize = statusIconHeight  }
      textParams = { text = loc("contact/notReady") }
    }
  }
  else if (isInvited?[userId]) {
    iconParams = {
      key = userId
      color = ContactOffline
      fontSize = hdpxi(18)
      text = fa["spinner"]
      transform = {}
      animations = [
        { prop=AnimProp.rotate, from = 0, to = 360, duration = 1, play = true, loop = true, easing = Discrete8 }
      ]
    }
    textParams = { text = loc("contact/Invited") }
  }
  else if (userId in friends)
    textParams = { text = status == true ? loc("contact/Online")
      : status == null ? loc("contact/Unknown")
      : loc("contact/Offline") }
  return {
    iconParams
    textParams
  }
}

let mkCommonStatusBlock = @(contact, status) function() {
  let watch = [enabledSquad, isInvitedToSquad, status, friendsUids, userInfo, isSquadLeader, contacts]
  let { userId, uid } = contact
  let squadMember = enabledSquad.get() && squadMembers.get()?[uid]
  let needReadyBtn = uid == userInfo.get().userId && !isSquadLeader.get()

  let { iconParams = null, textParams = null } = getContactStatus(squadMember, isInvitedToSquad.get(),
    userId, friendsUids.get(), status.get())
  let children = []
  if (iconParams)
    children.append({
      rendObj = ROBJ_INSCRIPTION
      validateStaticText = false
    }.__update(fontawesome, iconParams))
  if (textParams) {
    if (needReadyBtn)
      children.append(squadReadyStatus)
    else
      children.append({
        rendObj = ROBJ_TEXT
        color = ContactOffline
      }.__update(sub_txt, textParams))
  }

  return {
    watch
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    gap = hdpx(4)
    children
  }
}

let mkTeammateColorLine = @(name, override = {}) function () {
  let colorIdx = orderedTeamNicks.get().findindex(@(v)v == name)
  if (colorIdx == null)
    return {
      watch = orderedTeamNicks
      size = static [hdpx(4), flex()]
    }
  let color = TeammateColor[colorIdx]
  return {
    watch = orderedTeamNicks
    rendObj = ROBJ_SOLID
    size = static [hdpx(6), flex()]
    margin = static [hdpx(1), 0]
    color
  }.__update(override)
}

function mkCommonContactBlock(contact, inContactActions, contextMenuActions) {
  let { userId } = contact
  let stateFlags = Watched(0)
  let status = mkContactOnlineStatus(userId)

  function onContactClick(event) {
    if (event.button >= 0 && event.button <= 2)
      open(contact, event, contextMenuActions)
  }

  let commonContactBlock = {
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    vplace = ALIGN_TOP
    children = [
      mkPresenceIcon(status)
      mkUserNickname(contact, status)
    ]
  }

  return @() {
    watch = stateFlags
    rendObj = ROBJ_BOX
    size = [flex(), contactHeight]
    fillColor = (stateFlags.get() & S_HOVER) ? mul_color(BtnBgHover, 0.3) : null
    borderColor = BtnBgHover
    borderWidth = stateFlags.get() & S_HOVER ? hdpx(1) : null
    behavior = Behaviors.Button
    onClick = onContactClick
    onElemState = @(sf) stateFlags.set(sf)
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    sound = buttonSound
    children = [
      mkTeammateColorLine(getContactNick(contact), { margin = 0, size = static [hdpx(4), flex()]})
      {
        size = flex()
        children = [
          commonContactBlock
          function() {
            let actionsButtons = {
              flow = FLOW_HORIZONTAL
              hplace = ALIGN_RIGHT
              vplace = ALIGN_BOTTOM
              children = inContactActions.map(@(action) contactActionButton(action, userId, stateFlags.get()))
            }
            return {
              watch = isGamepad
              size = static [flex(), hdpx(29)]
              vplace = ALIGN_BOTTOM
              valign = ALIGN_CENTER
              padding = static [0, hdpx(1),0,0]
              children = [
                mkCommonStatusBlock(contact, status)
                !isGamepad.get() ? actionsButtons : null
              ]
            }
          }
        ]
      }
    ]
  }
}

let mkStatusBlock = @(contact, status) function() {
  let watch = [enabledSquad, isInvitedToSquad, status, friendsUids, userInfo, isSquadLeader, contacts]
  let { userId, uid } = contact
  let squadMember = enabledSquad.get() && squadMembers.get()?[uid]
  let needReadyBtn = uid == userInfo.get().userId && !isSquadLeader.get()

  let { iconParams = null, textParams = null } = getContactStatus(squadMember, isInvitedToSquad.get(),
    userId, friendsUids.get(), status.get())
  let children = []
  if (iconParams)
    children.append({
      rendObj = ROBJ_INSCRIPTION
      validateStaticText = false
    }.__update(fontawesome, iconParams))
  if (textParams) {
    if (needReadyBtn)
      children.append(squadReadyStatus)
  }

  return {
    watch
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    gap = hdpx(4)
    children
  }
}


function mkRaidSelectionNotif() {
  let selectedRaidBySquadLeader = Computed(@() squadLeaderState.get()?.leaderRaid)
  return function() {
    let { raidData = null, isOffline = false } = selectedRaidBySquadLeader.get()
    if (!isInSquad.get())
      return { watch = isInSquad }
    let leaderRaid = raidData
    if (leaderRaid == null)
      return {
        watch = [selectedRaidBySquadLeader, isSquadLeader, isInSquad, hudIsInteractive]
        vplace = ALIGN_CENTER
        children = textButtonSmall(isSquadLeader.get() ? loc("missions/selectLeaderRaidWidget") : loc("missions/waitingLeaderSelection"),
          function() {
            if (isSquadLeader.get()) {
              showMsgbox({ text = loc("missions/leaderSelectionRequired") })
              openMenu(Missions_id)
            }
            else
              showMsgbox({ text = loc("missions/waitingLeaderSelectionDesc") })
          },
          { isInteractive = hudIsInteractive.get() })
      }
    return {
      watch = [selectedRaidBySquadLeader, isSquadLeader, isInSquad, hudIsInteractive]
      size = FLEX_V
      vplace = ALIGN_CENTER
      children = button({
        flow = FLOW_HORIZONTAL
        gap = static hdpx(4)
        valign = ALIGN_CENTER
        children = [
          static faComp("star", {
            color = ContactLeader
            fontSize = statusIconHeight
          })
          mkText(loc(leaderRaid.locId))
          isOffline ? mkOfflineRaidIcon({ fontSize = statusIconHeight, color = ContactLeader }) : null
        ]
      },
        function() {
          let isNexus = leaderRaid?.extraParams.nexus ?? false
          selectedPlayerGameModeOption.set(isNexus ? GameMode.Nexus : GameMode.Raid)
          selectedRaid.set(leaderRaid)
          prevSelectedZonesPerGameMode[selectedPlayerGameModeOption.get()] <- leaderRaid
          openMenu(Missions_id)
        },
        {
          size = [SIZE_TO_CONTENT, smallContactHeight]
          padding = static [0, hdpx(4)]
          onHover = @(on) setTooltip(on ? loc("missions/squadLeaderRaid") : null)
          isInteractive = hudIsInteractive.get()
        }.__update(accentButtonStyle))
    }
  }
}

function makeTeammateHoverHint(data, contact) {
  let { ribbons = null, mainAlter = null, level = 0, weaponsList = null, attachedEquipment = null } = data
  if (!ribbons || !mainAlter || !weaponsList || !attachedEquipment)
    return null

  let suitType = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(mainAlter)?.getCompValNullable("suit__suitType") ?? 0
  let animchar = suitType == 0 ? "am_trooper_empty_model_male_char" : "am_trooper_empty_model_female_char"
  let ribbonColors = {
    primaryColor = get_color_as_array_by_index(ribbons.primary)
    secondaryColor = get_color_as_array_by_index(ribbons.secondary)
  }
  let content = tooltipBox({
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    children = [
      {
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [
          function() {
            let name = isStreamerMode.get() && contact.userId == userInfo.get().userId.tostring()
              ? playerRandName.get()
              : getContactNick(contact)
            return {
              watch = [isStreamerMode, playerRandName]
              children = mkText(name, h2_txt)
            }
          }
          mkText($"{loc("player_progression/currentLevel")} : {level + 1}", body_txt)
          mkHeroDoll(animchar, mkIconAttachments(attachedEquipment, ribbonColors), static [hdpx(400), hdpx(596)], null, ribbonColors)
        ]
      }
      mkEquipmentWeaponsSmall(weaponsList)
    ]
  })
  return content
}


function mkContactWidgetBlock(contact, contextMenuActions, isEnable) {
  let { userId } = contact
  let stateFlags = Watched(0)
  let status = mkContactOnlineStatus(userId)

  function onContactClick(event) {
    if (event.button >= 0 && event.button <= 2)
      open(contact, event, contextMenuActions)
  }

  let commonContactBlock = {
    valign = ALIGN_CENTER
    children = [
      { pos = [hdpx(4), -hdpx(10)]  children = mkPresenceIcon(status, hdpx(5)) hplace = ALIGN_RIGHT}
      {
        flow = FLOW_VERTICAL
        valign = ALIGN_CENTER
        gap = hdpx(2)
        children = [
          mkUserNickname(contact, status)
        ]
      }
    ]
  }

  return @() {
    watch = [stateFlags, isEnable, contacts, showCursor]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = static [SIZE_TO_CONTENT, smallContactHeight]
    fillColor = ((stateFlags.get() & S_HOVER) !=0) && showCursor.get()? mul_color(BtnBgHover, 0.3) : 0x01111111
    borderColor = BtnBgHover
    borderWidth = ((stateFlags.get() & S_HOVER) !=0 ) && showCursor.get() ? hdpx(1) : null
    padding = static [0, hdpx(4), 0, hdpx(1)]
    behavior = isEnable.get() ? Behaviors.Button : null,
    valign = ALIGN_CENTER
    onClick = onContactClick
    onElemState = @(sf) stateFlags.set(sf)
    sound = buttonSound
    flow = FLOW_HORIZONTAL
    gap = static hdpx(4)
    onHover = function(on) {
      let data = allMembersState.get()?[contact.uid].playersData
      if (data == null)
        return
      setTooltip(!on ? null : makeTeammateHoverHint(data, contact))
    }
    children = [
      mkTeammateColorLine(getContactNick(contact))
      mkStatusBlock(contact, status)
      commonContactBlock
    ]
  }
}

return {
  mkRaidSelectionNotif
  mkContactWidgetBlock
  mkCommonContactBlock
  mkTeammateColorLine
}
