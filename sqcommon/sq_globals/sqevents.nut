let {registerUnicastEvent, registerBroadcastEvent } = require("%dngscripts/ecs.nut")

let broadcastEvents = {}
foreach(name, payload in {
    EventDebugChatMessageAllClients = { text = "" }
  })
  broadcastEvents.__update(registerBroadcastEvent(payload, name))

let unicastEvents = {}
foreach (name, payload in {
    CmdEnableDedicatedLogger = { on = true },
  })
  unicastEvents.__update(registerUnicastEvent(payload, name))


return freeze(broadcastEvents.__merge(unicastEvents))