from "%ui/ui_library.nut" import *
let { get_paragraph_loc } = require("%ui/hud/menus/notes/articles/articles_common.nut")

function mkNote(id) {
  let paragraphs = [
    {t="paragraph", v=loc($"notes/{id}/hint_text")}
    {t="paragraph", v=loc("notes/spacer")}
    {t="paragraph", v=loc($"notes/{id}/sector")}
    {t="paragraph", v=loc("notes/spacer")}
  ]

  local idx = 1
  local contentLoc = get_paragraph_loc(id, idx)
  while(contentLoc != ""){
    paragraphs.append({t="paragraph", v=contentLoc})
    idx += 1
    contentLoc = get_paragraph_loc(id, idx)
  }
  return {
    id,
    title = loc($"notes/{id}/title"),
    content = [
      {t="h1" v=loc($"notes/{id}/title")}
      {t="columns", preset="two_97_3", v=[
        {t="column", v=paragraphs}
        {t="column", v=[]}
      ]}
    ],
    isRaidNote = true,
    notificationText = loc($"notes/{id}/paragraph/1"),
    type = "world"
  }
}


let world_records = [
  mkNote("note_remains_with_chronogenes"),
  mkNote("note_saturated_item_on_pickup"),
  mkNote("note_cargoport_investigation_report"),
  mkNote("firestation"),
]

return {
  world_records
}