require ecs
require strings
require game.es.message_queue_common


[es(on_event=EventLevelLoaded)]
def init_message_queue_action_id_data(evt : Event)
  if !(find_query() <| $ [es(REQUIRE=transaction_id)] () => true)
    let transactionId = genTransactionId()
    logMQ("Init transactionId = {format("0x%llx", transactionId)}")

    createEntity("message_queue") <| $(init)
      init |> set("transaction_id", transactionId)
