from "%ui/hud/menus/notes/articles/articles_common.nut" import get_paragraph_loc

from "%ui/ui_library.nut" import *

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


let world_records = freeze([
  mkNote("note_remains_with_chronogenes"),
  mkNote("note_saturated_item_on_pickup"),
  mkNote("note_cargoport_investigation_report"),
  mkNote("firestation"),
  mkNote("note_tf_shopping_list"),
  mkNote("note_lore_soldier_letter"),
  mkNote("note_lore_prayer1"),
  mkNote("note_lore_prayer2"),
  mkNote("note_lore_denunciation"),
  mkNote("note_lore_love_letter"),
  mkNote("note_lore_search_report1"),
  mkNote("note_lore_search_report2"),
  mkNote("note_lore_quartermaster_letter"),
  mkNote("note_lore_researcher_diary1"),
  mkNote("note_lore_researcher_diary1_2"),
  mkNote("note_lore_researcher_diary2"),
  mkNote("note_lore_researcher_diary2_2"),
  mkNote("note_lore_researcher_diary3"),
  mkNote("note_lore_researcher_diary3_2"),
  mkNote("note_lore_researcher_diary4"),
  mkNote("note_lore_researcher_diary4_2"),
  mkNote("note_lore_evacuation_drill"),
  mkNote("note_lore_troitsky_to_platon"),
  mkNote("note_lore_platon_to_troitsky"),
  mkNote("note_lore_soldier_am_contact1"),
  mkNote("note_lore_soldier_am_contact2"),
  mkNote("note_lore_Savushkina_letter1"),
  mkNote("note_lore_Savushkina_letter2"),
  mkNote("note_lore_revvol_to_sokolov"),
  mkNote("note_lore_sokolov_to_revvol"),
  mkNote("note_lore_garage_warning"),
])

return {
  world_records
}