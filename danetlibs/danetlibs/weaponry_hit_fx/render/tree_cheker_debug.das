options no_aot
require ecs
require ecs.common
require strings
require DagorSystem
require Dacoll
require RendInst
require DngCamera
require DagorMath
require DagorConsole
require DagorDebug3D


def is_list_contains_string(tree_name_list : StringList; new_tree : string)
  return find_index(tree_name_list, new_tree) >= 0

[console_cmd(name="vegetation.correct_destr_fx_checker", hint="<debug_mode 0 - off, 1 - on [radius=1000] [frames=100]")]
def debug_tree_checker(debug_mode = 0; radius = 1000.0; frames = 100)
  query(get_cur_cam_entity()) <| $ [es] (transform : float3x4)
    let center = transform[3]
    var totalChecks = 0
    //we can't use size more then that because we have restriction to size of bbox on cheking intersection
    let boxSize = 42.0
    let width = int(floor(radius / boxSize))
    using() <| $(var supportList : StringList)
      for x in range(-width, width + 1)
        for y in range(-width, width + 1)
          totalChecks = totalChecks + 1
          let offset = float2(float(x), float(y)) * boxSize
          let pos = float2(center.x, center.z) + offset
          let ht = traceht_hmap(pos)
          let sampledPos = float3(pos.x, ht, pos.y)
          let bbox = BBox3(sampledPos, boxSize)
          if (debug_mode > 0)
            let debugRad = 3.5f
            draw_debug_box_buffered(bbox, E3DCOLOR(0xFF00FFFF), frames)
            draw_debug_sphere_buffered(sampledPos, debugRad, E3DCOLOR(0xFFFF0000), 12, frames)
          rendinst_foreachTreeInBox(bbox) <| $(coll_info : CollisionInfo)
            let riDesc = coll_info.desc
            let fxName = getRIGenDestrFxTemplateName(riDesc)
            if empty(fxName)
              let riName = getRIGenResName(riDesc)
              if (!is_list_contains_string(supportList, riName))
                push(supportList, riName)
      if (empty(supportList))
        return
      var resultString = ""
      for riName in supportList
        resultString += "{riName}; "
      logerr("List of rendInts vegetation has empty destrFxTemplate <{resultString}>")