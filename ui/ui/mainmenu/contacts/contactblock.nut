from "%ui/ui_library.nut" import *

let { sub_txt, fontawesome } = require("%ui/fonts_style.nut")
let { ContactNotReady, ContactInBattle, ContactLeader, ContactReady, ContactOffline, TeammateColor,
  UserNameColor, Inactive, Active, BtnBgHover, BtnTextVisualDisabled
} = require("%ui/components/colors.nut")
let {buttonSound} = require("%ui/components/sounds.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { squadMembers, isInvitedToSquad, enabledSquad } = require("%ui/squad/squadState.nut")
let { getContactNick, contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { friendsUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { mkContactOnlineStatus } = require("%ui/mainMenu/contacts/contactPresence.nut")
let { open } = require("%ui/mainMenu/contacts/contactContextMenu.nut")
let {isGamepad} = require("%ui/control/active_controls.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let {textButtonSmall} = require("%ui/components/button.nut")
let locByPlatform = require("%ui/helpers/locByPlatform.nut")
let { mkCheckEquipmentStateHandler } = require("%ui/mainMenu/startButton.nut")
let { isSquadLeader, myExtSquadData, isInSquad } = require("%ui/squad/squadManager.nut")
let { isInQueue, leaveQueue } = require("%ui/quickMatchQueue.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")

let presenceIconHeight = hdpxi(8)
let statusIconHeight = hdpxi(20)
let contactHeight = hdpx(56)


function squadReadyButton() {
  if (!isInSquad.get() || isSquadLeader.get())
    return { watch = [isSquadLeader, isInSquad] }
  let ready = myExtSquadData.ready
  function updateReady() {
    myExtSquadData.ready.set(!ready.get())
    if (!ready.get() && isInQueue.get())
      leaveQueue()
  }
  return {
    watch = [showCursor, ready, isSquadLeader, isInSquad]
    children = textButtonSmall(ready.get() ? loc("Set not ready") : loc("mainmenu/btnReady"),
      ready.get() ? updateReady : mkCheckEquipmentStateHandler(updateReady),
      {
        behavior = showCursor.get() ? Behaviors.Button : null
      }.__update(!ready.get() ? accentButtonStyle : {style = { TextNormal = BtnTextVisualDisabled }}))
    }
}

let mkUserNickname = @(contact, status) @(){
  watch = status
  rendObj = ROBJ_TEXT
  padding = [0, hdpx(4),0,0]
  color = contact.uid == userInfo.get()?.userId
    ? UserNameColor
    : status.get() ? Active : Inactive
  text = getContactNick(contact)
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
    margin = [0,0,hdpx(2), 0]
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
      children.append(squadReadyButton)
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
      size = [hdpx(4), flex()]
    }
  let color = TeammateColor[colorIdx]
  return {
    watch = orderedTeamNicks
    rendObj = ROBJ_SOLID
    size = [hdpx(6), flex()]
    margin = [hdpx(1), 0]
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
      mkTeammateColorLine(getContactNick(contact), { margin = 0, size = [hdpx(4), flex()]})
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
              size = [flex(), hdpx(29)]
              vplace = ALIGN_BOTTOM
              valign = ALIGN_CENTER
              padding = [0, hdpx(1),0,0]
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
      children.append(squadReadyButton)
  }

  return {
    watch
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_CENTER
    gap = hdpx(4)
    children
  }
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
    size = [SIZE_TO_CONTENT, hdpx(30)]
    fillColor = ((stateFlags.get() & S_HOVER) !=0) && showCursor.get()? mul_color(BtnBgHover, 0.3) : 0x01111111
    borderColor = BtnBgHover
    borderWidth = ((stateFlags.get() & S_HOVER) !=0 ) && showCursor.get() ? hdpx(1) : null
    padding = [0, hdpx(4), 0, hdpx(1)]
    behavior = isEnable.get() ? Behaviors.Button : null,
    valign = ALIGN_CENTER
    onClick = onContactClick
    onElemState = @(sf) stateFlags.set(sf)
    sound = buttonSound
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    children = [
      mkTeammateColorLine(getContactNick(contact))
      mkStatusBlock(contact, status)
      commonContactBlock
    ]
  }
}

return {
  mkContactWidgetBlock
  mkCommonContactBlock
  mkTeammateColorLine
}
