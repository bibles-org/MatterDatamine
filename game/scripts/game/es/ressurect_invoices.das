require ecs


[es(tag=gameClient, on_appear, track=resurrection__targetPlayerEid,
  REQUIRE=(watched_invoice, interactable_invoice__nameSrc))]
def set_resurrect_invoice_name_ui(evt : Event;
                                  resurrection__targetPlayerEid : EntityId;
                                  var interactable_invoice__name : das_string&)
  query(resurrection__targetPlayerEid) <| $ [es] (name : string)
    interactable_invoice__name := name
