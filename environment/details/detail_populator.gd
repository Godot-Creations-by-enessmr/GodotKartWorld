@tool
extends Node3D
@export var terrain_mesh_instance : MeshInstance3D 
@export var terrain_texture : Texture2D 
var terrain_image : Image
var mesh_data : MeshDataTool

@export_group("Detail", "detail_")
@export var detail_grid_size : float = 0.5
@export var detail_mesh : Mesh
@export var detail_material : Material

@export_group("Generation Rules", "rules_")
@export var rules_vertical_range : Vector2 = Vector2(1, 1e6);

@export_group("Visibility", "visibility_")
@export var visibility_max_range : float = 64.0

@export_group("Bounds", "bounds_")
@export var bounds_size : Vector3 = Vector3(256, 256, 256)
@export var bounds_center : Vector3
@export var bounds_subdivsion : Vector3i = Vector3i(16,1,16)

@export_tool_button("Generate Details")
var generate_details := func (): _populate()

@export_tool_button("Clear Details")
var clear_details := func (): _clear()

func _clear() -> void:
	for child in get_children():
		child.queue_free()

func _populate() -> void:
	_clear()
	
	mesh_data = MeshDataTool.new()
	mesh_data.create_from_surface(terrain_mesh_instance.mesh, 0)
	
	terrain_image = terrain_texture.get_image()
	if terrain_image.is_compressed():
		terrain_image.decompress()
	
	var grid_corner = bounds_center - bounds_size * 0.5
		
	var chunk_size := Vector3(bounds_size.x / bounds_subdivsion.x, bounds_size.y, bounds_size.z / bounds_subdivsion.z);	
	for x in range(bounds_subdivsion.x): 
		for z in range(bounds_subdivsion.z):
			var corner = grid_corner + Vector3(chunk_size.x * x, chunk_size.y * 0, chunk_size.z * z)
			var chunk := generate_chunk(chunk_size, corner)
			if chunk:
				add_child(chunk)
				chunk.owner = get_tree().edited_scene_root
			
func sample_image_billinear(image : Image, uv : Vector2) -> Color:
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Color.BLACK

	var px : Vector2 = floor(uv * Vector2(image.get_size()))
	var frac := uv - px

	var x := int(px.x)
	var y := int(px.y)

	var v00 := image.get_pixel(x,     y    )
	var v10 := image.get_pixel(x + 1, y    )
	var v01 := image.get_pixel(x,     y + 1)
	var v11 := image.get_pixel(x + 1, y + 1)

	# Bilinear interpolation
	var v0 = lerp(v00, v10, frac.x)
	var v1 = lerp(v01, v11, frac.x)
	return lerp(v0, v1, frac.y)
	
func get_vertex_positions_normals_uvs_of_face(index: float) -> Array:
	var data: Array = []
	for i in range(0, 3):
		data.append(mesh_data.get_vertex(mesh_data.get_face_vertex(index, i)))
	for i in range(0, 3):
		data.append(mesh_data.get_vertex_normal(mesh_data.get_face_vertex(index, i)))
	for i in range(0, 3):
		data.append(mesh_data.get_vertex_uv(mesh_data.get_face_vertex(index, i)))
	return data


func generate_chunk(chunk_size : Vector3, chunk_corner : Vector3) -> MultiMeshInstance3D:
	var transforms : Array[Transform3D]	
	var space_state = get_world_3d().direct_space_state
	
	for x in range(ceil(chunk_size.x / detail_grid_size)): 
		for z in range(ceil(chunk_size.z / detail_grid_size)):
			var raycast_pos = Vector3(x + randfn(0, 0.33), 0, z + randfn(0, 0.33)) * detail_grid_size + chunk_corner
			const MASK = 8 # i.e. bit 4
			var query = PhysicsRayQueryParameters3D.create(raycast_pos + Vector3.UP * bounds_size.y, raycast_pos, MASK)
			var result = space_state.intersect_ray(query)
			if result:	
				var collision_point = result["position"]
				var face_index = result["face_index"]
				
				if collision_point.y < rules_vertical_range.x || collision_point.y > rules_vertical_range.y:
					continue
								
				var face_data = get_vertex_positions_normals_uvs_of_face(face_index)

				var b: Vector3 = Geometry3D.get_triangle_barycentric_coords(collision_point, face_data[0], face_data[1], face_data[2])				
				var normal : Vector3 = (face_data[3] * b.x + face_data[4] * b.y + face_data[5] * b.z).normalized()
				var uv : Vector2 = face_data[6] * b.x + face_data[7] * b.y + face_data[8] * b.z
				var terrain_mask = sample_image_billinear(terrain_image, uv)
				
				if terrain_mask.get_luminance() < 0.01 && normal.dot(Vector3.UP) > 0.85:
					var transform : Transform3D
					transform.origin = collision_point - chunk_corner
					
					var basis_x : Vector3 = normal.cross(Vector3(1,0,0)).normalized()
					if basis_x.length() < 0.0001:
						basis_x = normal.cross(Vector3(0,1,0)).normalized()
					var basis_z := basis_x.cross(normal).normalized()
					transform.basis.x = basis_x
					transform.basis.y = normal
					transform.basis.z = basis_z
					transform.basis = transform.basis.rotated(normal, randf() * 6.28318530718)
					transforms.append(transform)
					
	
	var details_count = transforms.size()	
	if details_count <= 0:
		return null
			
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = detail_mesh
	
	multi_mesh.instance_count = details_count
	for i in range(details_count):
		multi_mesh.set_instance_transform(i, transforms[i])
		
		
	var chunk := MultiMeshInstance3D.new()	
	chunk.position = chunk_corner
	chunk.multimesh = multi_mesh
	chunk.material_override = detail_material
	chunk.visibility_range_end = visibility_max_range
	
	return chunk
			
