class_name ParticlesManager extends Node3D

@export var drift_stage_1_color : Color 
@export var drift_stage_2_color : Color 
@export var drift_stage_3_color : Color
@export var sparks_material : StandardMaterial3D
@onready var drift_sparks_parent =  $"../Visual/Kart/Particles/DriftSparks"
var drift_spark_particles : Array[GPUParticles3D]

@onready var drifting_sliding_particles_parent =  $"../Visual/Kart/Particles/SlidingParticles"
var drifting_sliding_particles : Array[GPUParticles3D]

@onready var boost_particles_parent =  $"../Visual/Kart/Particles/Boost"
var boost_particles : Array[GPUParticles3D]

@onready var trick_particle_sparks : GPUParticles3D = $"Trick/Sparks"

@onready var water_spray_particles_parent =  $"../Visual/Kart/Particles/WaterParticles"
var water_spray_particles : Array[GPUParticles3D]

var rainbow_hue := 0.0
var is_rainbow_mode := false

func _process(delta: float) -> void:
	if is_rainbow_mode:
		rainbow_hue = fmod(rainbow_hue + delta * 0.3, 1.0)
		if sparks_material:
			sparks_material.emission = Color.from_hsv(rainbow_hue, 1.0, 1.0)


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
			
	for child in water_spray_particles_parent.get_children(true):
		if child is GPUParticles3D:
			water_spray_particles.append(child)
			
	set_boost(false)
	set_water_spray(false)
	set_sliding_particles(false)

# 0 : no drift
# 1 : sliding drift
# 2 : blue
# 3 : orange
# 4 : purple (it will be rainbow)
func set_drifing_stage(stage : int) -> void:	
	match stage:
		0:
			set_sliding_particles(false)
			drift_sparks_parent.visible = false
			is_rainbow_mode = false
		1:
			set_sliding_particles(true)
			drift_sparks_parent.visible = false
			is_rainbow_mode = false
		2:
			set_sliding_particles(false)
			sparks_material.emission = drift_stage_1_color
			drift_sparks_parent.visible = true
			is_rainbow_mode = false
		3:
			set_sliding_particles(false)
			sparks_material.emission = drift_stage_2_color
			drift_sparks_parent.visible = true
			is_rainbow_mode = false

		4:
			set_sliding_particles(false)
			drift_sparks_parent.visible = true
			is_rainbow_mode = true
			sparks_material.emission = Color.RED

func set_sliding_particles(enabled: bool) -> void:
	for particle in drifting_sliding_particles:
		particle.emitting = enabled

func set_boost(enabled: bool) -> void:
	for particle in boost_particles:
		particle.emitting = enabled

func set_rainbow_mode(enabled: bool) -> void:
	is_rainbow_mode = enabled
	if not enabled and sparks_material:
		sparks_material.emission = Color.WHITE

func set_water_spray(enabled: bool) -> void:
	for particle in water_spray_particles:
		particle.emitting = enabled
		
func play_trick_particles() -> void:
	trick_particle_sparks.emitting = true
