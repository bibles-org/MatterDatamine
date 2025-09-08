require ecs
require ecs.common
require math.random
require DagorSystem
require DagorRandom
require DagorDataBlock


[es(tag=server, on_appear)]
def bot_spawner_init(evt : Event;
                     var bot_spawner__generatedNames : StringList&;
                     bot_spawner__chiNamesPath : string;
                     bot_spawner__engNamesPath : string;
                     bot_spawner__botSuffix : string;
                     bot_spawner__namesFromFileCount : int = 200)
  let path = (dgs_get_settings() |> datablock_getBool("isChineseVersion", false)) ? bot_spawner__chiNamesPath : bot_spawner__engNamesPath
  var cur_names_count : int = 0
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, path)
      logerr("[Bot Spawner Init] can't load datablock from path : {path}")
      return
    datablock_get_block(blk, "am_bot_nicknames") <| $(am_bot_nicknames_blk)
      let namesCount = int(am_bot_nicknames_blk.paramCount)
      while cur_names_count < bot_spawner__namesFromFileCount
        let name : string = am_bot_nicknames_blk |> datablock_getStr(rnd_int(0, namesCount - 1)) + bot_spawner__botSuffix
        if !has_value(bot_spawner__generatedNames, name)
          bot_spawner__generatedNames |> push(name)
          ++cur_names_count
