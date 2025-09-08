require ecs
require math.base
require DagorMath
require DagorDebug3D
require DagorEditor


let
  EDITOR_PREVIEW_COLOR_DEFAULT = E3DCOLOR(0x6042c3ff)
  EDITOR_PREVIEW_COLOR_SELECTED = E3DCOLOR(0xffff00ff)


def draw_debug_ident_bbox(transform : float3x4;
                          color : E3DCOLOR;
                          test_z : bool = true)
  begin_draw_cached_debug_lines(test_z, true, false)
  set_cached_debug_lines_wtm(transform)
  draw_cached_debug_box(IDENT_BBOX, color)
  end_draw_cached_debug_lines()



[es(tag=render, REQUIRE=(daeditor__selected, editor__selectedBoxPreview), no_order)]
def editor_selected_box_preview(info : UpdateStageInfoRenderDebug; transform : float3x4;
                                editor__previewColorSelected : E3DCOLOR = EDITOR_PREVIEW_COLOR_SELECTED)
  draw_debug_ident_bbox(transform, editor__previewColorSelected)


[es(tag=render, REQUIRE=editor__boxPreview, no_order)]
def editor_box_preview(info : UpdateStageInfoRenderDebug;
                       transform : float3x4;
                       daeditor__selected : Tag const?;
                       editor__selectedBoxPreview : Tag const?;
                       editor__previewColorDefault : E3DCOLOR = EDITOR_PREVIEW_COLOR_DEFAULT;
                       editor__previewColorSelected : E3DCOLOR = EDITOR_PREVIEW_COLOR_SELECTED)
  if !is_editor_activated() || (daeditor__selected != null && editor__selectedBoxPreview != null)
    return

  let color = daeditor__selected != null ? editor__previewColorSelected : editor__previewColorDefault
  draw_debug_ident_bbox(transform, color, false)


[es(tag=render, REQUIRE=editor__zonePreview, REQUIRE_NOT=sphere_zone__radius, no_order)]
def editor_box_zone_preview(info : UpdateStageInfoRenderDebug;
                            transform : float3x4;
                            daeditor__selected : Tag const?;
                            editor__selectedBoxPreview : Tag const?;
                            editor__previewColorDefault : E3DCOLOR = EDITOR_PREVIEW_COLOR_DEFAULT;
                            editor__previewColorSelected : E3DCOLOR = EDITOR_PREVIEW_COLOR_SELECTED)
  if !is_editor_activated() || (daeditor__selected != null && editor__selectedBoxPreview != null)
    return

  let color = daeditor__selected != null ? editor__previewColorSelected : editor__previewColorDefault
  draw_debug_ident_bbox(transform, color, false)


[es(tag=render, REQUIRE=editor__zonePreview, no_order)]
def editor_sphere_zone_preview(info : UpdateStageInfoRenderDebug;
                               transform : float3x4;
                               sphere_zone__radius : float;
                               daeditor__selected : Tag const?;
                               editor__previewColorDefault : E3DCOLOR = EDITOR_PREVIEW_COLOR_DEFAULT;
                               editor__previewColorSelected : E3DCOLOR = EDITOR_PREVIEW_COLOR_SELECTED)
  if !is_editor_activated()
    return

  let color = daeditor__selected != null ? editor__previewColorSelected : editor__previewColorDefault

  begin_draw_cached_debug_lines(false, true, false)
  set_cached_debug_lines_wtm(IDENT_TM)
  draw_cached_debug_sphere(transform[3], sphere_zone__radius, color, 12)
  end_draw_cached_debug_lines()