from "auth" import get_user_info
from "%ui/login/stages/auth_helpers.nut" import status_cb

from "%ui/ui_library.nut" import *


return {
  id = "auth_result"
  function action(_state, cb) {
    status_cb(cb)(get_user_info())
  }
}
