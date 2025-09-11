from "%ui/login/login_chain.nut" import startLogin

from "%ui/ui_library.nut" import *


function loginRoot() {
  startLogin({})
  return {}
}

return {
  size = flex()
  children = loginRoot
}
