from "%ui/ui_library.nut" import *

let {startLogin} = require("%ui/login/login_chain.nut")

function loginRoot() {
  startLogin({})
  return {}
}

return {
  size = flex()
  children = loginRoot
}
