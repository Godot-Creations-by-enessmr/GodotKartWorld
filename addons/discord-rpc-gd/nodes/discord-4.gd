extends Node

func _ready() -> void:
	_discord()

func _discord():
	# Application ID
	DiscordRPC.app_id = 1510307027291738202
	# this is boolean if everything worked
	print("Discord working: " + str(DiscordRPC.get_is_discord_working()))
	# Set the first custom text row of the activity here
	DiscordRPC.details = "Using the engine and working or testing the game"
	# Set the second custom text row of the activity here
	DiscordRPC.state = "In the RPC debugger"
	# Image key for small image from "Art Assets" from the Discord Developer website
	DiscordRPC.large_image = "game-and-engine"
	# Tooltip text for the large image
	DiscordRPC.large_image_text = "Wait till the demo comes out of the game or use the engine!"
	# Image key for large image from "Art Assets" from the Discord Developer website
	DiscordRPC.small_image = "game-and-engine"
	# Tooltip text for the small image
	DiscordRPC.small_image_text = "Wait till the demo comes out of the game or use the engine!"
	# "02:41 elapsed" timestamp for the activity
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	# "59:59 remaining" timestamp for the activity
	# DiscordRPC.end_timestamp = int(Time.get_unix_time_from_system()) + 3600
	# Always refresh after changing the values!
	DiscordRPC.refresh() 
