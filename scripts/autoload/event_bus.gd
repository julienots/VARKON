extends Node
## Global signal hub. Systems emit here; UI listens. Keeps systems decoupled.

signal resources_changed
signal profile_changed
signal inventory_changed
signal collection_changed
signal king_changed
signal base_changed
signal lab_changed
signal missions_changed
signal pass_changed
signal stat_tracked(stat: String, amount: int)
signal toast(text: String, kind: String)
signal rewards_granted(entries: Array)
signal level_up(new_level: int)
signal settings_changed
signal sound_played(sfx_name: String)


func notify(text: String, kind: String = "info") -> void:
	toast.emit(text, kind)
