let {matching_listen_notify=null, matching_listen_rpc=null, matching_send_response=null} = require_optional("matching.api")
let { eventbus_subscribe } = require("eventbus")

let subscriptions = {}

matching_listen_notify?("mrpc.generic_notify")
matching_listen_rpc?("mrpc.generic_rpc")

eventbus_subscribe("mrpc.generic_notify", function(ev) {
  subscriptions?[ev?.from].each(@(handler) handler(ev))
})

eventbus_subscribe("mrpc.generic_rpc", function(reqctx) {
  matching_send_response?(reqctx, {})
  let ev = reqctx.request
  subscriptions?[ev?.from].each(@(handler) handler(ev))
})

function subscribe(from, handler) {
  if (from not in subscriptions)
    subscriptions[from] <- []
  subscriptions[from].append(handler)
}

function unsubscribe(from, handler) {
  if (from not in subscriptions)
    return
  let idx = subscriptions[from].indexof(handler)
  if (idx != null)
    subscriptions[from].remove(idx)
}

return {
  subscribe
  unsubscribe
}
