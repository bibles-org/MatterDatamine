options no_aot

require ecs
require app
require DagorMath
require DagorImgui
require DagorConsole
require DagorDebug3DSolid
require DagorEditor
require DagorSystem
require DngNet
require danetlibs.imgui_daeditor.daEditor.daEditor_common
require imgui/imgui_boost
require game.events.events_active_matter
require daslib/strings_boost
require daslib/static_let
require daslib/safe_addr


struct TeaserBotData
  index : int
  behTreeEnabled : bool
  aliveCount : int
  totalCount : int


[imgui_window(name="Bot Director", group="Teaser")]
def teaser_bot_director_window()
  if IsWindowCollapsed()
    return

  var groupsData : array<TeaserBotData>
  query() <| $ [es] (teaser_bot__group : int;
                     beh_tree__enabled : bool;
                     isAlive : bool)
    var groupFound = false
    for groupData in groupsData
      if groupData.index == teaser_bot__group
        groupFound = true
        if beh_tree__enabled
          groupData.behTreeEnabled = beh_tree__enabled
        if isAlive
          groupData.aliveCount++
        groupData.totalCount++
        break

    if !groupFound
      groupsData |> push(TeaserBotData(index = teaser_bot__group,
                                         behTreeEnabled = beh_tree__enabled,
                                         aliveCount = isAlive ? 1 : 0,
                                         totalCount = 1))
  sort(groupsData) <| $(lhs, rhs : TeaserBotData)
    return lhs.index < rhs.index

  imgui::Text("[Bot Groups]")

  let columnIdent = 50.0

  for groupData in groupsData

    static_let <|
      var activeCheck = false

    BeginGroup()
    imgui::Text("Group #{groupData.index}")
    EndGroup()

    SameLine()
    BeginGroup()
    imgui::Indent(columnIdent)
    activeCheck = groupData.behTreeEnabled
    if imgui::Checkbox("Enabled##{groupData.index}", safe_addr(activeCheck))
      console_command("teaser.enable_group {groupData.index} {activeCheck}")
    EndGroup()

    SameLine()
    BeginGroup()
    imgui::Indent(columnIdent)
    imgui::Text("Alive: {groupData.aliveCount}/{groupData.totalCount}")
    EndGroup()

    SameLine()
    BeginGroup()
    imgui::Indent(columnIdent)
    if groupData.aliveCount < groupData.totalCount
      if imgui::Button("Resurrect##{groupData.index}")
        console_command("teaser.resurrect_group {groupData.index}")
    EndGroup()


struct TeaserEpisodeData
  eid : EntityId
  index : int


[imgui_window(name="Episode Director", group="Teaser")]
def teaser_episode_director_window()
  if IsWindowCollapsed()
    return

  var episodesData : array<TeaserEpisodeData>
  query() <| $ [es] (eid aka episode_eid : EntityId;
                     teaser_episode__index : int)
    episodesData |> push(TeaserEpisodeData(eid = episode_eid,
                                             index := teaser_episode__index))

  sort(episodesData) <| $(lhs, rhs : TeaserEpisodeData)
    return lhs.index < rhs.index

  if imgui::BeginTable("Episodes", 3, ImGuiTableFlags.RowBg)

    imgui::TableNextRow()
    imgui::TableSetColumnIndex(0)
    imgui::Text("Name")
    imgui::TableSetColumnIndex(1)
    imgui::Text("Actions")
    imgui::TableSetColumnIndex(2)
    imgui::Text("Triggers")

    for episode in episodesData
      query(episode.eid) <| $ [es] (teaser_episode__index : int = -1;
                                    teaser_episode__name : string;
                                    teaser_episode__triggersCount : int = 0;
                                    teaser_episode__hasReset : bool = true)
        imgui::PushID(teaser_episode__name)
        imgui::TableNextRow()
        imgui::TableSetColumnIndex(0)
        let episodePrefix = (teaser_episode__index >= 0 && teaser_episode__index <= 999) ? "Episode {teaser_episode__index} -" : ""
        imgui::Text(" - {episodePrefix}{teaser_episode__name}")
        imgui::TableSetColumnIndex(1)
        if imgui::Button("Go To##{teaser_episode__name}")
          send_net_event(episode.eid, CmdTeaserGoToEpisodeRequest())
        if teaser_episode__hasReset
          SameLine()
          if imgui::Button("Reset##{teaser_episode__name}")
            send_net_event(episode.eid, CmdTeaserResetEpisodeRequest())
        imgui::TableSetColumnIndex(2)
        for triggerIndex in range(teaser_episode__triggersCount)
          if triggerIndex > 0
            SameLine()
          if imgui::Button("{triggerIndex}##{teaser_episode__name}")
            send_net_event(episode.eid, CmdTeaserEpisodeTriggerRequest(triggerIndex = triggerIndex))
        imgui::PopID()
    EndTable()
