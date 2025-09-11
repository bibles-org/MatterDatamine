import "%ui/components/contextMenu.nut" as contextMenu
import "%ui/helpers/locByPlatform.nut" as locByPlatform
from "%ui/mainMenu/contacts/externalIdsManager.nut" import searchContactByInternalId

from "%ui/ui_library.nut" import *

let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { consoleCompare } = require("%ui/helpers/platformUtils.nut")

let expanderForUserId = Watched(null)

function openContextMenu(userId, event, actions) {
  let actionsButtons = (actions ?? []).reduce(function(res, action) {
    let isVisible = action.mkIsVisible(userId)
    if (isVisible.get())
      return res.append({
        isVisible
        text = locByPlatform(action.locId)
        action = @() action.action(userId)
      })
    return res
  }, [])

  if (actionsButtons.len()) {
    expanderForUserId.set(userId)
    contextMenu(event.screenX + 1, event.screenY + 1, fsh(30), actionsButtons, @() expanderForUserId.set(null))
  }
}

function open(contactValue, event, actions) {
  if (contactValue.userId in uid2console.get()) {
    openContextMenu(contactValue.userId, event, actions)
    return
  }

  foreach (_platform, data in consoleCompare)
    if (data.isPlatform && data.isFromPlatform(contactValue.realnick)) {
      searchContactByInternalId(contactValue.userId, function() {
        openContextMenu(contactValue.userId, event, actions)
      })
      return
    }

  openContextMenu(contactValue.userId, event, actions)
}


return {
  open = open
  expanderForUserId
}