from "%ui/squad/squadManager.nut" import leaveSquad

from "%ui/fonts_style.nut" import body_txt
from "%ui/mainMenu/contacts/contact.nut" import getContact
from "%ui/mainMenu/contacts/contactsListWnd.nut" import showContactsWnd
from "%ui/components/button.nut" import squareIconButton
from "%ui/mainMenu/contacts/contactBlock.nut" import mkContactWidgetBlock, mkRaidSelectionNotif

from "%ui/ui_library.nut" import *

let { isInSquad, squadMembers, isInvitedToSquad, squadId, isLeavingWillDisbandSquad, enabledSquad, canInviteToSquad } = require("%ui/squad/squadManager.nut")
let maxSquadSize = require("%ui/state/queueState.nut").availableSquadMaxMembers
let { contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { display } = require("%ui/mainMenu/contacts/contactsListWnd.nut")
let { INVITE_TO_FRIENDS, INVITE_TO_PSN_FRIENDS, REMOVE_FROM_SQUAD, PROMOTE_TO_LEADER, REVOKE_INVITE, SHOW_USER_LIVE_PROFILE, LEAVE_SQUAD } = require("%ui/mainMenu/contacts/contactActions.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

let ADD_BLINK_ANIM = "ADD_USER_BUTTON"
local stopBlinkTimerCb = null
function addUserButton(needBlink = false) {
  if (needBlink && !stopBlinkTimerCb) {
    stopBlinkTimerCb = @() anim_request_stop(ADD_BLINK_ANIM)
    gui_scene.setTimeout(5, stopBlinkTimerCb)
  }

  return squareIconButton({
    onClick = function () {
      showContactsWnd()
      display.set("invites")
    }
    tooltipText = loc("tooltips/addUser")
    iconId = "user-plus"
    needBlink = needBlink
    blinkAnimationId = ADD_BLINK_ANIM
    isEnable = showCursor
  })
}

let height = calc_str_box({rendObj = ROBJ_TEXT text="A"}.__update(body_txt))[1]

let squadControls = function() {
  let controls = []

  if (!isOnboarding.get()) {
    if (squadMembers.get().len() < maxSquadSize.get() && canInviteToSquad.get()) {
      controls.append(addUserButton())
    }
    if (squadMembers.get().len() > 0)
      controls.append(squareIconButton({
        onClick = @() leaveSquad()
        tooltipText = loc("tooltips/disbandSquad")
        iconId = "user-times"
        isEnable = showCursor
      }))
  }

  return {
    watch = [isOnboarding, squadMembers, maxSquadSize, isInSquad, isLeavingWillDisbandSquad, canInviteToSquad]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    children = controls
  }
}

let contextMenuActions = [INVITE_TO_FRIENDS, INVITE_TO_PSN_FRIENDS, REMOVE_FROM_SQUAD, PROMOTE_TO_LEADER, REVOKE_INVITE, SHOW_USER_LIVE_PROFILE, LEAVE_SQUAD]
let horizontalContact = @(contact) {
  children = mkContactWidgetBlock(contact, contextMenuActions, showCursor)
}

let squadMembersUi = function() {
  let squadList = [mkRaidSelectionNotif()]
  let sortedMembers = squadMembers.get().values().sort(@(a, b)
    (b.userId == userInfo.get().userId) <=> (a.userId == userInfo.get().userId)
    || b.isLeader <=> a.isLeader)

  foreach (_id, member in sortedMembers){
    squadList.append(horizontalContact(getContact(member.userId.tostring(), contacts.get())))}

  foreach(uid, _val in isInvitedToSquad.get())
    squadList.append(horizontalContact(getContact(uid.tostring(), contacts.get())))

  return {
    watch = [squadMembers, contacts, isInvitedToSquad, squadId, userInfo]
    size = [SIZE_TO_CONTENT, height]
    halign = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = squadList
  }
}

function squadWidget() {
  if (isInBattleState.get())
    return { watch = isInBattleState }
  return {
    watch = [enabledSquad, showCursor, isInBattleState]
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
    gap = hdpx(4)
    hplace = ALIGN_RIGHT
    padding = static [hdpx(2),0,0,0]
    children = enabledSquad.get() ? [
        squadMembersUi
        squadControls
      ]
    : null
  }
}

return {
  squadWidget
}