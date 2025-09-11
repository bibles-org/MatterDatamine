from "%dngscripts/platform.nut" import is_xbox

import "%ui/components/msgbox.nut" as msgbox

from "%ui/components/colors.nut" import Alert
from "%ui/helpers/remap_nick.nut" import remap_nick

from "%ui/ui_library.nut" import *


let getMembersNames = @(members) members.map(@(m) remap_nick(m.state.get().name))

local showCrossnetworkChatRestrictionMsgBox = @() msgbox.showMsgbox({ text = loc("contacts/msg/crossnetworkChatRestricted", {color = Alert})})
if (is_xbox) {
  let { check_privilege = @(...) null, Communications = -1 } = require_optional("gdk.user")
  showCrossnetworkChatRestrictionMsgBox = @() check_privilege(Communications, true, "")
}

return {
  showSquadMembersCrossPlayRestrictionMsgBox = @(members) msgbox.showMsgbox({
    text = "{0}\n{1}".subst(
      loc("squad/action_not_available_crossnetwork_play", {color = Alert}),
      ", ".join(getMembersNames(members))
    )})

  showSquadVersionRestrictionMsgBox = @(members) msgbox.showMsgbox({
    text = "{0}\n{1}".subst(
      loc("squad/action_not_available_version", {color = Alert}),
      ", ".join(getMembersNames(members))
    )})

  showVersionRestrictionMsgBox = @() msgbox.showMsgbox({ text = loc("msg/gameMode/unsupportedVersion", {color = Alert})})
  showCrossnetworkChatRestrictionMsgBox
}