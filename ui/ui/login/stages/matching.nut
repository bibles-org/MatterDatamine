from "%ui/matchingClient.nut" import startLogin
from "eventbus" import eventbus_subscribe_onehit

from "%ui/ui_library.nut" import *


return {
  id = "matching"
  function action(processState, cb) {
    let stageResult = processState.stageResult
    let uinfo = {
      userId = stageResult.auth_result.userId
      name = stageResult.auth_result.name
      chardToken = stageResult.char.chard_token
    }
    eventbus_subscribe_onehit("matching.logged_in", @(...) cb({}))
    eventbus_subscribe_onehit("matching.login_failed", cb)
    startLogin(uinfo)
  }
  function actionOnReload(_state, cb) {
    eventbus_subscribe_onehit("matching.logged_in", @(...) cb({}))
    eventbus_subscribe_onehit("matching.login_failed", cb)
  }
}
