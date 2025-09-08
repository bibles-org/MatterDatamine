from "%ui/ui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")

let list = []

eventbus_subscribe("app.shutdown", function(...) {
  foreach(func in list)
    func()
})

return {
  add = @(func) list.append(func)
  remove = function(func) {
    let idx = list.indexof(func)
    if (idx != null)
      list.remove(idx)
  }
}
