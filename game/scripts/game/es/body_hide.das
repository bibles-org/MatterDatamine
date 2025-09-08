require ecs


[es(track=char_flags__hasSuitOn)]
def sync_suit_with_body(evt : Event; char_flags__hasSuitOn : bool; var human__selfVisible : bool&)
  human__selfVisible = !char_flags__hasSuitOn
