# Godot Water Kart Demo

![Banner Image](https://github.com/JorisAR/GDWaterKart/blob/main/banner.png?raw=true)

Inspired by Mario Kart World, This project combines several compute based effects to achieve an interactive world.

The project features:
- An arcade style kart controller
- A water system featuring:
    - FFT based water waves
    - Water ripples following the player
    - Large interactive water waves caused by explosions
    - Simple rigidbody buoyancy
    - Simple underwater post processing
    - A water shader that incorporates the above elements, and
        - Caustics
        - Foam 
        - Screen Space Reflections
        - Refraction
- Some bonus effects including:
    - Item boxes
    - Boost panels
    - Tire tracks left by the player's kart
    - Grass swaying in the wind


## Getting Started

### Installation

- Clone the repository
- Open the project in Godot 4.4 or later


## Acknowledgements 

This project is inspired by, and borrows from the following other open source work:
- The official godot compute texture demo: https://github.com/godotengine/godot-demo-projects/tree/master/compute/texture
- The godot ocean FFT addon: https://github.com/tessarakkt/godot4-oceanfft 
    - The FFT related shaders are based on this project: https://github.com/achalpandeyy/OceanFFT
- GDQuest's 3D characters: https://github.com/gdquest-demos/godot-4-3D-Characters
- "Stylized Spatial Clouds" by "sebashtioon" on Godot shaders: https://godotshaders.com/shader/realistic-spatial-clouds/
- The screen space reflections handled in the fragment shader of the water are inspired by "smallcableboi" on Godot shaders: https://godotshaders.com/shader/realistic-water-with-reflection-and-refraction/


## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
