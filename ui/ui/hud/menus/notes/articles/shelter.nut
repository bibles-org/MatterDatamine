from "%ui/ui_library.nut" import *
let { get_paragraph_loc } = require("%ui/hud/menus/notes/articles/articles_common.nut")

function mkNote(id) {
  let paragraphs = [
    {t="paragraph", v=loc("notes/from/agency")}
    {t="paragraph", v=loc("notes/spacer")}
    {t="paragraph", v=loc("notes/spacer")}
  ]

  local idx = 1
  local contentLoc = get_paragraph_loc(id, idx)
  while(contentLoc != ""){
    paragraphs.append({t="paragraph", v=contentLoc})
    paragraphs.append({t="paragraph", v=loc("notes/spacer")})
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
    notificationText = loc($"notes/{id}/paragraph/1"),
    type = "shelter"
  }
}


let shelter = [
  mkNote("note_shelter_replicator"),
  mkNote("note_shelter_refiner"),
  mkNote("note_shelter_alters"),
  mkNote("note_shelter_market"),
  mkNote("note_shelter_storage"),
]

return {
  shelter
}