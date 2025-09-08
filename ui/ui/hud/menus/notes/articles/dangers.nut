from "%ui/ui_library.nut" import *
let { get_paragraph_loc } = require("%ui/hud/menus/notes/articles/articles_common.nut")

function mkNote(id) {
  let paragraphs = [
    {t="paragraph", v=loc("notes/date/unknown")}
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
      {t="h1" v=loc($"notes/{id}/title")},
      {t="columns", preset="four_37_3_57_3", v=[
        {t="column", v=[
          {t="image", v=$"ui/notes/{id}", width=500, height=500}
        ]},
        {t="column", v=[]},
        {t="column", v=paragraphs},
        {t="column", v=[]}
      ]}
    ],
    notificationText = loc($"notes/{id}/paragraph/1")
    type = "dangers"
  }
}


let dangers = [
  mkNote("note_distorted"),
  mkNote("note_hellhound"),
  mkNote("note_invisible"),
  mkNote("note_dendroid"),
  mkNote("note_flowerman"),
  mkNote("note_devourer"),
  mkNote("note_swarm"),
  mkNote("note_turned_soldier"),
  mkNote("note_turned_operative"),
  mkNote("note_statue"),
  mkNote("note_thunderball"),
  mkNote("note_seeds"),
  mkNote("note_furnace"),
  mkNote("note_teleport"),
  mkNote("note_jump_pad")
]

return {
  dangers
}