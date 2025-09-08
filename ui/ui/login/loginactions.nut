from "%ui/ui_library.nut" import *

let loginActions = {}

function setLoginActions(actionsTable){
  loginActions.__update(actionsTable)
}

let getLoginActions = @() freeze(clone loginActions)

return {getLoginActions, setLoginActions}