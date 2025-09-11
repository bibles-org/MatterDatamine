from "%ui/squad/squadManager.nut" import inviteToSquad, dismissSquadMember, transferSquad, revokeSquadInvite, leaveSquad
from "%ui/state/roomState.nut" import isInMyRoom, inviteToRoom
from "%ui/components/colors.nut" import InfoTextValueColor
from "%ui/mainMenu/contacts/contactsWatchLists.nut" import isInternalContactsAllowed
from "%ui/helpers/platformUtils.nut" import canInterractCrossPlatform, canInterractCrossPlatformByCrossplay
import "%ui/charClient/charClient.nut" as char
from "%ui/components/openUrl.nut" import openUrl
from "%ui/state/clientState.nut" import appId
from "%ui/mainMenu/contacts/contactsState.nut" import execContactsCharAction, getContactsInviteId
from "%ui/mainMenu/contacts/contact.nut" import getContactRealnick
from "app" import get_circuit
from "settings" import get_setting_by_blk_path
from "%ui/mainMenu/contacts/showUserInfo.nut" import showUserInfo, canShowUserInfo
from "%ui/mainMenu/mailboxState.nut" import removeNotifyById
from "%ui/ui_library.nut" import *
from "%sqstd/frp.nut" import WatchedRo
from "%ui/components/msgbox.nut" import showMsgbox
import "%ui/components/colorize.nut" as colorize

import "%ui/components/fontawesome.map.nut" as fa

let { isInSquad, isSquadLeader, squadMembers, isInvitedToSquad, enabledSquad, canInviteToSquad } = require("%ui/squad/squadManager.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { canInviteToRoom, playersWaitingResponseFor } = require("%ui/state/roomState.nut")
let { availableSquadMaxMembers } = require("%ui/state/queueState.nut")
let platform = require("%dngscripts/platform.nut")
let { approvedUids, myRequestsUids, requestsToMeUids, rejectedByMeUids, myBlacklistUids, meInBlacklistUids, psnApprovedUids, psnBlockedUids, xboxBlockedUids, friendsUids, blockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { consoleCompare } = require("%ui/helpers/platformUtils.nut")

let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { open_player_profile = @(...) null, PlayerAction = null
} = platform.is_sony? require("sony.social") : null

let { canCrossnetworkChatWithAll, canCrossnetworkChatWithFriends, crossnetworkPlay } = require("%ui/state/crossnetwork_state.nut")



let myUserId = Computed(@() userInfo.get()?.userIdStr ?? "")
let isInMySquad = @(userId, members) members.get()?[userId.tointeger()] != null

let achievementTestUrl = "http://achievement-test.gaijin.ops/achievement/?app={0}&nick={1}"
let achievementUrl = get_setting_by_blk_path("achievementsUrl") ?? "https://achievements.gaijin.net/?app={0}&nick={1}"

return freeze({
  INVITE_TO_SQUAD = {
    locId = "Invite to squad"
    icon = fa["handshake-o"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && canInviteToSquad.get()
      && !isInMySquad(userId, squadMembers)
      && availableSquadMaxMembers.get() > 1
      && !isInvitedToSquad.get()?[userId.tointeger()]
      && userId in friendsUids.get()
      && canInterractCrossPlatformByCrossplay(
        getContactRealnick(userId),
        crossnetworkPlay.get()
      )
      && userId not in meInBlacklistUids.get()
      && userId not in blockedUids.get()
    )
    action = @(userId) inviteToSquad(userId.tointeger())
  }

  INVITE_TO_ROOM = {
    locId = "Invite to room"
    mkIsVisible = @(userId) Computed(@() canInviteToRoom.get()
      && userId.tointeger() not in playersWaitingResponseFor.get()
      && !isInMyRoom(userId.tointeger())
      && canInterractCrossPlatformByCrossplay(
        getContactRealnick(userId),
        crossnetworkPlay.get()
      ))
    action = @(userId) inviteToRoom(userId.tointeger())
  }

  INVITE_TO_FRIENDS = {
    locId = "Invite to friends"
    icon = fa["user-plus"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && isInternalContactsAllowed
      && userId not in blockedUids.get()
      && userId not in friendsUids.get()
      && userId not in myRequestsUids.get()
      && userId not in rejectedByMeUids.get()
      && userId not in requestsToMeUids.get()
    )
    function action(userId) {
      function addToFriends(id) {
        
        if (platform.is_xbox && canShowUserInfo(id.tointeger(), getContactRealnick(id)))
          showUserInfo(id)
        else
          execContactsCharAction(id, "contacts_request_for_contact")
      }
      char?.contacts_can_add(userId, addToFriends)
    }
  }

  INVITE_TO_PSN_FRIENDS = {
    locId = "contacts/psn/friends/request"
    icon = fa["user-plus"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && (platform.is_sony && consoleCompare.psn.isFromPlatform(getContactRealnick(userId)))
      && userId not in psnApprovedUids.get()
      && userId not in blockedUids.get()
      && userId not in meInBlacklistUids.get()
    )
    action = @(userId) open_player_profile(
      (uid2console.get()?[userId] ?? "-1").tointeger(),
      PlayerAction?.REQUEST_FRIENDSHIP,
      "PlayerProfileDialogClosed",
      {}
    )
  }

  CANCEL_INVITE = {
    locId = "Cancel Invite"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get() && userId in myRequestsUids.get())
    action      = @(userId) execContactsCharAction(userId, "contacts_cancel_request")
  }

  APPROVE_INVITE = {
    locId = "Approve Invite"
    icon = fa["user-plus"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && (userId in requestsToMeUids.get() || userId in rejectedByMeUids.get())
      && canInterractCrossPlatformByCrossplay(
        getContactRealnick(userId),
        crossnetworkPlay.get()
      )
    )
    action      = function(userId) {
      removeNotifyById(getContactsInviteId(userId))
      execContactsCharAction(userId, "contacts_approve_request")
    }
  }

  REJECT_INVITE = {
    locId = "Reject Invite"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && userId in requestsToMeUids.get())
    action      = function(userId) {
      removeNotifyById(getContactsInviteId(userId))
      execContactsCharAction(userId, "contacts_reject_request")
    }
  }

  REMOVE_FROM_FRIENDS = {
    locId = "Break approval"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@()
      canInterractCrossPlatform(
        getContactRealnick(userId),
        canCrossnetworkChatWithFriends.get()
      )
      && userId != myUserId.get()
      && userId in friendsUids.get()
      && userId not in psnApprovedUids 
    )
    function action(userId) {
      if (platform.is_xbox && canShowUserInfo(userId.tointeger(), getContactRealnick(userId)))
        showUserInfo(userId) 
      else
        showMsgbox({
          text = loc("contacts/friendRemoveConfirm", {nick = colorize(InfoTextValueColor, getContactRealnick(userId))})
          buttons = [
            {
              text = loc("Yes")
              action = @() execContactsCharAction(userId, "contacts_break_approval_request")
              isCurrent = true
            },
            {
              text = loc("No")
              isCancel = true
            }
          ]
        })
    }
  }

  ADD_TO_BLACKLIST = {
    locId = "Add to blacklist"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@()
      canInterractCrossPlatform(
        getContactRealnick(userId),
        userId in friendsUids.get()
          ? canCrossnetworkChatWithFriends.get()
          : canCrossnetworkChatWithAll.get()
      )
      && userId != myUserId.get()
      && userId not in blockedUids.get()
      && userId not in approvedUids.get())
    function action(userId) {
      if (platform.is_sony && consoleCompare.psn.isFromPlatform(getContactRealnick(userId)))
        open_player_profile(
          (uid2console.get()?[userId] ?? "-1").tointeger(),
          PlayerAction?.BLOCK_PLAYER,
          "PlayerProfileDialogClosed",
          {}
        )
      else if (platform.is_xbox && canShowUserInfo(userId.tointeger(), getContactRealnick(userId)))
        showUserInfo(userId) 
      else
        execContactsCharAction(userId, "contacts_add_to_blacklist")
    }
  }


  REMOVE_FROM_BLACKLIST = {
    locId = "Remove from blacklist"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get() && userId in myBlacklistUids.get())
    action      = @(userId) execContactsCharAction(userId, "contacts_remove_from_blacklist")
  }

  REMOVE_FROM_BLACKLIST_XBOX = {
    locId = "Remove from blacklist"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get()
      && userId in xboxBlockedUids.get()
      && canShowUserInfo(userId.tointeger(), getContactRealnick(userId))
    )
    action      = showUserInfo
  }

  REMOVE_FROM_BLACKLIST_PSN = {
    locId = "Remove from blacklist"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() userId != myUserId.get() && userId in psnBlockedUids.get())
    action      = @(userId) open_player_profile(
      (uid2console.get()?[userId] ?? "-1").tointeger(),
      PlayerAction?.DISPLAY,
      "PlayerProfileDialogClosed",
      {}
    )
  }

  REMOVE_FROM_SQUAD = {
    locId = "Remove from squad"
    mkIsVisible = @(userId) Computed(@() enabledSquad.get()
      && userId != myUserId.get() && isSquadLeader.get() && isInMySquad(userId, squadMembers))
    action      = @(userId) dismissSquadMember(userId.tointeger())
  }

  PROMOTE_TO_LEADER = {
    locId = "Promote to squad chief"
    mkIsVisible = @(userId) Computed(@() enabledSquad.get()
      && userId != myUserId.get() && isSquadLeader.get() && isInMySquad(userId, squadMembers))
    action      = @(userId) transferSquad(userId.tointeger())
  }

  REVOKE_INVITE = {
    locId = "Revoke invite"
    icon = fa["remove"]
    mkIsVisible = @(userId) Computed(@() isSquadLeader.get()
      && !isInMySquad(userId, squadMembers) && (isInvitedToSquad.get()?[userId.tointeger()] ?? false))
    action      = @(userId) revokeSquadInvite(userId.tointeger())
  }

  LEAVE_SQUAD = {
    locId = "Leave squad"
    mkIsVisible = @(userId) Computed(@() enabledSquad.get() && userId == myUserId.get() && isInSquad.get())
    action      = @(_userId) leaveSquad()
  }

  COMPARE_ACHIEVEMENTS = {
    locId = "Compare achievements"
    mkIsVisible = @(userId) Computed(@() platform.is_pc && achievementUrl != "" && userId != myUserId.get())
    action      = @(userId)
      openUrl(
        ["am-test"].contains(get_circuit())
          ? achievementTestUrl.subst(appId, getContactRealnick(userId))
          : achievementUrl.subst(appId, getContactRealnick(userId))
      )
  }

  SHOW_USER_LIVE_PROFILE = {
    locId = "show_user_live_profile"
    icon = fa["id-card"]
    mkIsVisible = @(userId) WatchedRo(canShowUserInfo(userId.tointeger(), getContactRealnick(userId)))
    action      = showUserInfo
  }
})

