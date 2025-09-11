import "auth" as auth
import "%ui/login/stages/auth_helpers.nut" as ah
from "eventbus" import eventbus_subscribe_onehit
from "app" import get_circuit

from "%ui/ui_library.nut" import *


const id = "auth_go"

return {
  id
  function action(state, cb) {
    eventbus_subscribe_onehit(id, ah.status_cb(cb))

    let params = state.params.__merge({
      circuit = get_circuit()
    })
    let loginMethod = params?.two_step_code != null ? auth.login_2step : auth.login
    loginMethod(params, id)
  }
  actionOnReload = @(_state, _cb) null
}
