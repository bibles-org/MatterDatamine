from "%ui/hud/menus/notes/articles/articles_common.nut" import get_paragraph_loc

from "%ui/ui_library.nut" import *

function mkNote(id) {
  let paragraphs = [
    {t="paragraph", v=loc($"notes/{id}/date")}
  ]

  local idx = 1
  local contentLoc = get_paragraph_loc(id, idx)
  while(contentLoc != ""){
    paragraphs.append({t="paragraph", v=contentLoc})
    paragraphs.append({t="paragraph", v=loc("notes/spacer")})
    idx += 1
    contentLoc = get_paragraph_loc(id, idx)
  }
  let photo_id = loc($"notes/{id}/photo")
  return {
    id,
    title = loc($"notes/{id}/title"),
    content = [
      {t="h1" v=loc($"notes/{id}/title")}
      photo_id != ""
        ? {t="columns", preset="four_37_3_57_3", v=[
            {t="column", v=[
              {t="image", v=$"ui/notes/{photo_id}", width=500, height=500}
            ]},
            {t="column", v=[]},
            {t="column", v=paragraphs},
            {t="column", v=[]}
          ]}
        : {t="columns", preset="two_97_3", v=[
            {t="column", v=paragraphs}
            {t="column", v=[]}
          ]}
    ],
    isRaidNote = true,
    notificationText = loc($"notes/{id}/hint_text"),
    type = "newspaper"
  }
}


let newspaper = freeze([
  mkNote("note_newspaper_komsomol_01"),
  mkNote("note_newspaper_komsomol_02"),
  mkNote("note_newspaper_komsomol_03"),
  mkNote("note_newspaper_komsomol_04"),
  mkNote("note_newspaper_komsomol_05"),
  mkNote("note_newspaper_komsomol_06"),
  mkNote("note_newspaper_komsomol_07"),
  mkNote("note_newspaper_komsomol_08"),
  mkNote("note_newspaper_komsomol_09"),
  mkNote("note_newspaper_komsomol_10"),
])

return {
  newspaper
}