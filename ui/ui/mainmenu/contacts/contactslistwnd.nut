from "%dngscripts/platform.nut" import is_sony
from "%ui/mainMenu/contacts/contactsWatchLists.nut" import isInternalContactsAllowed
from "dasevents" import CmdHideUiMenu
from "%ui/fonts_style.nut" import body_txt, sub_txt
from "%ui/components/colors.nut" import ModalBgTint, WindowHeader, Inactive, WindowBlur, WindowContacts
from "%ui/viewConst.nut" import gap
from "%ui/components/textInput.nut" import textInput
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/components/button.nut" import fontIconButton
from "%ui/components/text.nut" import dtext as txt
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/mainMenu/contacts/contact.nut" import getContact, getContactNick
from "%ui/mainMenu/contacts/contactsState.nut" import searchContacts
import "%ui/mainMenu/contacts/buildCounter.nut" as buildCounter
from "%ui/helpers/remap_nick.nut" import remap_nick
import "%ui/helpers/locByPlatform.nut" as locByPlatform
from "%ui/mainMenu/contacts/contactPresence.nut" import isContactOnline
from "%ui/mainMenu/contacts/contactBlock.nut" import mkCommonContactBlock
from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkSelectPanelTextWithFaIconCtor
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")
let { INVITE_TO_PSN_FRIENDS, CANCEL_INVITE, APPROVE_INVITE, ADD_TO_BLACKLIST, INVITE_TO_FRIENDS, INVITE_TO_SQUAD, REMOVE_FROM_BLACKLIST, COMPARE_ACHIEVEMENTS, INVITE_TO_ROOM, REVOKE_INVITE, REJECT_INVITE, REMOVE_FROM_SQUAD, REMOVE_FROM_FRIENDS, PROMOTE_TO_LEADER, SHOW_USER_LIVE_PROFILE, REMOVE_FROM_BLACKLIST_PSN, REMOVE_FROM_BLACKLIST_XBOX } = require("%ui/mainMenu/contacts/contactActions.nut")
let { contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { approvedUids, psnApprovedUids, xboxApprovedUids, friendsOnlineUids, requestsToMeUids, myRequestsUids, rejectedByMeUids, blockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { isContactsVisible, searchContactsResults } = require("%ui/mainMenu/contacts/contactsState.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { onlineStatus } = require("%ui/mainMenu/contacts/contactPresence.nut")
let JB = require("%ui/control/gui_buttons.nut")

let windowPadding = fsh(2)
let searchPlayer = Watched("")

const CONTACTLIST_MODAL_UID = "contactsListWnd_modalUid"
let contactListWidth = hdpx(300)

let display = Watched("approved")

let hdrTxt = @(text,params={}) {
  padding = static [hdpx(2),fsh(1)]
  size = FLEX_H
  children = txt(text,params.__merge({
    behavior = [Behaviors.Marquee,Behaviors.Button]
    size = FLEX_H
    speed = hdpx(100)
    scrollOnHover = true
  }, sub_txt))
}






let closeWnd = @() removeModalPopup(CONTACTLIST_MODAL_UID)

function resetSearch() {
  display.set("approved")
  searchPlayer.set("")
  searchContactsResults.set({})
}

let closeButton = fontIconButton("icon_buttons/x_btn.svg", function() {
  resetSearch()
  closeWnd()
})


let header = @(){
  size = static [flex(), fsh(4)]
  watch = userInfo
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  gap = hdpx(8)
  padding = [hdpx(8),hdpx(8),hdpx(8),windowPadding]
  color = WindowHeader
  children = [
    @() {
      watch = [isStreamerMode, playerRandName]
      rendObj = ROBJ_TEXT
      text = isStreamerMode.get() ? playerRandName.get() : remap_nick(userInfo.get()?.name)
      size = FLEX_H
      color = Inactive
      clipChildren = true
      behavior = [Behaviors.Marquee, Behaviors.Button]
      scrollOnHover=true
    }.__update(body_txt)
    {size = static [hdpx(8),0]}
    closeButton
  ]
}

function searchCallback() {
  if (searchPlayer.get().len() > 0)
    display.set("search_results")
}

function doSearch(nick) {
  if (nick.len() == 0)
    resetSearch()
  else
    searchContacts(nick, searchCallback)
}

display.subscribe_with_nasty_disregard_of_frp_update(function(val){
  if (val == "search_results")
    return
  searchPlayer.set("")
  searchContactsResults.set({})
})

let exitSearchButton = fontIconButton("icon_buttons/x_btn.svg", resetSearch, {
  hplace = ALIGN_RIGHT
  vplace = ALIGN_CENTER
  margin = static [hdpx(1), fsh(0.5)]
  size=hdpx(20)
  borderWidth=0
})

function clearOrExitWnd() {
  if (searchPlayer.get() == "")
    closeWnd()
  else
    resetSearch()
}

let searchBlock = @() {
  watch = [display,searchPlayer]
  size = FLEX_H
  margin =[ hdpx(2), windowPadding]
  children = [
    textInput(searchPlayer, {
      placeholder = loc("Search for new friends...")
      textmargin = hdpx(5)
      onChange = doSearch
      onReturn = @() doSearch(searchPlayer.get())
      onEscape = clearOrExitWnd
    }.__update(sub_txt))
    display.get() != "search_results" || searchPlayer.get().len() == 0 ? null : exitSearchButton
  ]
}

let counterText = @(count) count > 0 ? count : null
let placeholder = txt(loc("contacts/list_empty"), {color=Inactive, margin = [fsh(1),windowPadding]}.__update(sub_txt))

let friendsKeys = []
if (isInternalContactsAllowed) {
  friendsKeys.append({
    name = "friends",
    uidsWatch = [approvedUids, xboxApprovedUids]
    placeholder
    inContactActions = [INVITE_TO_SQUAD],
    contextMenuActions = [
      INVITE_TO_PSN_FRIENDS, REMOVE_FROM_SQUAD, REVOKE_INVITE, INVITE_TO_ROOM,
      INVITE_TO_SQUAD, PROMOTE_TO_LEADER, COMPARE_ACHIEVEMENTS, SHOW_USER_LIVE_PROFILE, REMOVE_FROM_FRIENDS
    ]
  })
}

if (is_sony)
  friendsKeys.append({
    name = "contacts",
    uidsWatch = psnApprovedUids,
    inContactActions = [INVITE_TO_FRIENDS],
    contextMenuActions = [
      INVITE_TO_FRIENDS, ADD_TO_BLACKLIST,
      REMOVE_FROM_SQUAD, REVOKE_INVITE, INVITE_TO_SQUAD, PROMOTE_TO_LEADER, SHOW_USER_LIVE_PROFILE
    ]
  })

let invitesKeys = [
  { name = "requestsToMe",
    uidsWatch = requestsToMeUids,
    inContactActions = [APPROVE_INVITE],
    contextMenuActions = [APPROVE_INVITE, REJECT_INVITE, INVITE_TO_SQUAD, ADD_TO_BLACKLIST, COMPARE_ACHIEVEMENTS]
  }
  { name = "myRequests",
    uidsWatch = myRequestsUids,
    inContactActions = [CANCEL_INVITE],
    contextMenuActions = [CANCEL_INVITE, INVITE_TO_SQUAD, REVOKE_INVITE, ADD_TO_BLACKLIST, COMPARE_ACHIEVEMENTS]
  }
  { name = "rejectedByMe",
    uidsWatch = rejectedByMeUids,
    inContactActions = [],
    contextMenuActions = [APPROVE_INVITE, INVITE_TO_FRIENDS, INVITE_TO_SQUAD, ADD_TO_BLACKLIST, COMPARE_ACHIEVEMENTS]
  }
]

let nickToLower = memoize(@(v) getContactNick(v).tolower(), null, persist("stringsLowerCache", @() {}))
let sortContacts = @(contactsArr, onlineStatusVal) contactsArr.sort(@(a, b)
  isContactOnline(b.userId, onlineStatusVal) <=> isContactOnline(a.userId, onlineStatusVal) || nickToLower(a) <=> nickToLower(b)
)

let mkContactsGroupContent = @(groupKeys) function() {
  let children = []
  let watch = [onlineStatus, searchPlayer, contacts]
  let searchPlayerVal = searchPlayer.get().tolower()
  foreach (v in groupKeys) {
    let { name, uidsWatch, inContactActions, contextMenuActions } = v
    let watchesList = typeof uidsWatch == "array" ? uidsWatch : [uidsWatch]

    local contactsArr = []
    foreach (w in watchesList)
      contactsArr.extend(w.get().keys().map(@(userId) getContact(userId, contacts.get())))

    if (searchPlayerVal != "")
      contactsArr = contactsArr.filter(@(c) c.realnick.tolower().indexof(searchPlayerVal) != null)

    contactsArr = sortContacts(contactsArr, onlineStatus.get())
      .map(@(contact) mkCommonContactBlock(contact, inContactActions, contextMenuActions))

    children.append(hdrTxt(locByPlatform($"contacts/{name}")))
    if (contactsArr.len() == 0)
      children.append(placeholder)
    else
      children.extend(contactsArr)

    watch.extend(watchesList)
  }

  return {
    watch
    size = FLEX_H
    flow = FLOW_VERTICAL
    children
  }
}

function buildContactsButton(idx, symbol, mkCounter) {
  let ico = mkSelectPanelTextWithFaIconCtor(symbol)
  let children = @(params) {
    size = FLEX_H
    halign = ALIGN_CENTER
    children = [
      { hplace = ALIGN_CENTER children = ico(params), pos = [hdpx(4), 0] padding = static [hdpx(4), 0]},
      { pos = [-hdpx(8), hdpx(8)], size = flex(), halign = ALIGN_RIGHT, children=buildCounter(mkCounter?()) }
    ]
  }
  return mkSelectPanelItem({idx, state=display, children, visual_params={size=FLEX_H, margin=0, padding=0}})
}


let modesList = [
  { option = "approved", icon="users", mkCounter = @() Computed(@() counterText(friendsOnlineUids.get().len())) },
  { option = "invites", icon ="user-plus", mkCounter = @() Computed(@() counterText(requestsToMeUids.get().len() + myRequestsUids.get().len() + rejectedByMeUids.get().len()))},
  { option = "myBlacklist", icon = "user-times", mkCounter = @() Computed(@() counterText( blockedUids.get().len() ))}
]

function modeSwitcher() {
  return {
    size = FLEX_H
    padding = hdpx(4)
    gap = hdpx(1)
    flow = FLOW_HORIZONTAL
    children = modesList.map(@(m) buildContactsButton(m.option, m.icon, m?.mkCounter))
  }
}

let searchTbl = [{
  uidsWatch = searchContactsResults,
  name = "search_results",
  placeholder,
  inContactActions = [INVITE_TO_FRIENDS],
  contextMenuActions = [
    INVITE_TO_FRIENDS, INVITE_TO_PSN_FRIENDS, APPROVE_INVITE, INVITE_TO_SQUAD, CANCEL_INVITE,
    REMOVE_FROM_BLACKLIST, REMOVE_FROM_BLACKLIST_PSN, REMOVE_FROM_BLACKLIST_XBOX, ADD_TO_BLACKLIST,
    SHOW_USER_LIVE_PROFILE, COMPARE_ACHIEVEMENTS, REMOVE_FROM_FRIENDS
  ]
}]

let myBlackTbl = [{
  uidsWatch = [blockedUids]
  name = "myBlacklist",
  placeholder,
  inContactActions = [REMOVE_FROM_BLACKLIST, REMOVE_FROM_BLACKLIST_PSN, REMOVE_FROM_BLACKLIST_XBOX],
  contextMenuActions = [REMOVE_FROM_BLACKLIST, REMOVE_FROM_BLACKLIST_PSN,
    REMOVE_FROM_BLACKLIST_XBOX, SHOW_USER_LIVE_PROFILE, COMPARE_ACHIEVEMENTS]
}]

let isContactsWndVisible = Watched(false)

let tabsContent = {
  search_results = @() mkContactsGroupContent(searchTbl),
  myBlacklist    = @() mkContactsGroupContent(myBlackTbl),
  approved       = @() mkContactsGroupContent(friendsKeys),
  invites        = @() mkContactsGroupContent(invitesKeys)
}

let contactsBlock = @() {
  watch = [display]
  size = [contactListWidth, flex() ]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = WindowBlur
  valign = ALIGN_BOTTOM
  stopMouse = true
  key = "contactsBlock"
  onAttach = @() isContactsWndVisible.set(true)
  onDetach = @() isContactsWndVisible.set(false)
  hotkeys = [[$"^{JB.B} | Esc", { action = clearOrExitWnd }]]

  children = {
    size = flex()
    rendObj = ROBJ_SOLID
    color = WindowContacts
    flow = FLOW_VERTICAL
    children = [
      header
      {
        flow = FLOW_VERTICAL
        size = flex()
        children = [
          modeSwitcher
          searchBlock
          makeVertScroll(tabsContent?[display.get()]())
        ]
      }
    ]
  }
}


let getCurModeIdx = @() modesList.findindex(@(m) m.option == display.get()) ?? -1
let changeMode = @(delta) display.set(modesList[(getCurModeIdx() + delta + modesList.len()) % modesList.len()].option)

let btnContactsNav = @() {
  size = SIZE_TO_CONTENT
  children = {
    hotkeys = [
      ["^J:RB | Tab", {action = @() changeMode(1), description=loc("contacts/next_mode")} ],
      ["^J:LB | L.Shift Tab | R.Shift Tab", { action = @() changeMode(-1), description=loc("contacts/prev_mode")} ]
    ]
  }
}



let popupBg = { rendObj = ROBJ_WORLD_BLUR_PANEL, fillColor = ModalBgTint }

function showContactsWnd(){
  let bottomOffset = safeAreaVerPadding.get() + gap + fsh(2)
  let popupHeight = sh(95) - bottomOffset
  addModalPopup([sw(100), sh(100) - bottomOffset],
  {
    size = [SIZE_TO_CONTENT, popupHeight]
    uid = CONTACTLIST_MODAL_UID
    onDetach = function() {
      isContactsVisible.set(false)
      ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName=CONTACTLIST_MODAL_UID}))
    }
    onAttach = @() isContactsVisible.set(true)

    fillColor = Color(0,0,0)
    padding = 0
    popupFlow = FLOW_HORIZONTAL
    popupValign = ALIGN_BOTTOM
    popupOffset = 0
    margin = 0
    children = [
      contactsBlock,
      btnContactsNav
    ]
    popupBg = popupBg
  })
}

function showContactsIfNeeded(v) {
  if (v)
    showContactsWnd()
}

isContactsVisible.subscribe_with_nasty_disregard_of_frp_update(showContactsIfNeeded)
showContactsIfNeeded(isContactsVisible.get())

return {
  isContactsVisible
  showContactsWnd
  CONTACTLIST_MODAL_UID
  display
}
