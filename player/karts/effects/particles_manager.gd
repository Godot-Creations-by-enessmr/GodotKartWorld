class_name ParticlesManager extends Node3D

@export var drift_stage_1_color : Color 
@export var drift_stage_2_color : Color 
@export var sparks_material : StandardMaterial3D
@onready var drift_sparks_parent =  $DriftSparks
var drift_spark_particles : Array[GPUParticles3D]

@onready var drifting_sliding_particles_parent =  $SlidingParticles
var drifting_sliding_particles : Array[GPUParticles3D]

@onready var boost_particles_parent =  $Boost
var boost_particles : Array[GPUParticles3D]


func _ready() -> void:
	for child in drift_sparks_parent.get_children(true):
		if child is GPUParticles3D:
			drift_spark_particles.append(child)
			
	for child in drifting_sliding_particles_parent.get_children(true):
		if child is GPUParticles3D:
			drifting_sliding_particles.append(child)
	
	for child in boost_particles_parent.get_children(true):
		if child is GPUParticles3D:
			boost_particles.append(child)
			
	set_boost(false)
	set_sliding_particles(false)

# 0 : no drift
# 1 : sliding drift
# 2 : blue
# 3 : orange
func set_drifing_stage(stage : int) -> void:	
	match stage:
		0:
			set_sliding_particles(false)
			drift_sparks_parent.visible = false
		1:
			set_sliding_particles(true)
			drift_sparks_parent.visible = false
		2:
			set_sliding_particles(false)
			sparks_material.emission = drift_stage_1_color
			drift_sparks_parent.visible = true
		3:
			set_sliding_particles(false)
			sparks_material.emission = drift_stage_2_color
			drift_sparks_parent.visible = true

func set_sliding_particles(enabled: bool) -> void:
	for particle in drifting_sliding_particles:
		particle.emitting = enabled

func set_boost(enabled: bool) -> void:
	for particle in boost_particles:
		particle.emitting = enabled
	
