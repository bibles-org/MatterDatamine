require DngDm
require dm
require ecs
options indenting = 2

[generic]
def DamageDesc(damage_type : DamageType;
               delta_hp : float;
               hit_pos : float3;
               hit_dir : float3 = float3();
               hit_norm : float3 = float3();
               shell_id : int = -1;
               gun_props_id : int = -1;
               coll_node_id : int = -1;
               stopping_power : float = 0.0;
               action_props_id : int = -1;
               dmg_mult : float = 1.0;
               armor_mult : float = 1.0;
               penetration : float = 0.0;
               shatter_count : uint8 = uint8(0);
               caused_bleeding : float = 0.0)
  return _builtin_make_damage_desc(damage_type, delta_hp, hit_pos, hit_dir, hit_norm, int16(shell_id), int16(gun_props_id), int16(coll_node_id), stopping_power, int16(action_props_id), dmg_mult, armor_mult, penetration, shatter_count, caused_bleeding)


[generic]
def get_gun_component_by_props_id(props_id : int; comp_name : string) : string
  let templateName = get_gun_template_by_props_id(props_id)
  if templateName == ""
    return ""
  let templ = getTemplateByName(templateName)
  if templ == null
    return ""
  let str = get_ecs_string(getTemplateComponent(*templ, comp_name, ecs_hash(comp_name)))
  return str != null ? string(*str) : ""

[generic]
def find_meta_part_id_by_name(damage_model : DamageModel; meta_part_name : string)
  for i, metaPartProps in iter_range(damage_model.metaPartProps), damage_model.metaPartProps
    if get_meta_part_prop_name(metaPartProps) == meta_part_name
      return i
  return -1
