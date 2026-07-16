extends Node

func _ready() -> void:
	# Application ID
	DiscordRPC.app_id = 1527334957167542472
	# this is boolean if everything worked
	print("Discord working: " + str(DiscordRPC.get_is_discord_working()))
	# Set the first custom text row of the activity here
	DiscordRPC.details = ""
	# Image key for small image from "Art Assets" from the Discord Developer website
	DiscordRPC.large_image = "game"
	# "02:41 elapsed" timestamp for the activity
	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
	# "59:59 remaining" timestamp for the activity
	# DiscordRPC.end_timestamp = int(Time.get_unix_time_from_system()) + 3600
	DiscordRPC.party_id = "ae488379-351d-4a4f-ad32-2b9b01c91657"
	# TODO: add online
	# DiscordRPC.current_party_size = online_room_curr
	# DiscordRPC.max_party_size = online_room_max
	DiscordRPC.current_party_size = 1
	DiscordRPC.max_party_size = 24
	# Always refresh after changing the values!
	DiscordRPC.refresh() 
