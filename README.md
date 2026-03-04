# Godot Vertex Animation Plugin

**Godot Engine addon that enables creating vertex animations from skeletal animations.**

This tool allows you to convert complex skeletal animations into high-performance Vertex Animation Textures (VAT). By baking animation data into textures and using custom shaders, you can render hundreds or even thousands of animated meshes simultaneously with minimal CPU overhead.

## 🚀 Features

* **Skeletal to VAT Conversion:** Bake animations directly from `AnimationPlayer`.
* **Vertex Animation Player:** Play vertex animations directly in editor and runtime.
* **Mesh and MultiMesh Support:** Create optimized `MultiMesh` resources for massive crowd rendering.
* **Mesh Merging:** Combine multiple `MeshInstance3D` nodes into a single static mesh.
* **Texture Merging:** Combine textures into a single atlas.
* **Flexible Export:** Save textures directly into material or as separate external files.

## 🛠 Installation

1.  Download or clone this repository.
2.  Copy `vertex_animation_plugin` folder into your project's `res://addons/` directory.
3.  Go to **Project Settings > Globals > Shader Globals** and add variable **global_shader_time** of type **float**.
4.  Go to **Project Settings > Plugins** and enable **Vertex Animation Plugin**.

## 📖 How to use

1.  Add plugin **VertexAnimationEditor** node to your scene containing a animated mesh.
2.  Assign an **AnimationPlayer** containing the source animations.
3.  Add the **MeshInstance3D** nodes you wish to bake into the `Animated Meshes` array.
4.  Set the `Animation FPS`. **Note:** Higher FPS results in smoother motion but significantly increases the animation texture size. For most games, 30 FPS is a good balance.
5.  (Optional) Select specific animations in the `Animation Selection` group.
6.  Configure your output settings (Mesh, MultiMesh, or External Textures).
7.  Click the **Create** button at the top of the inspector.

> [!IMPORTANT]
> **Technical Limitations:**
> * **No Dynamic Interaction:** Since animations are baked, features like IK (Inverse Kinematics), Ragdolls, or Animation Blending are not supported.
> * **Memory Usage:** Vertex animations uses textures to store positions. High-poly meshes with long animations will result in very large texture sizes.
> * **Texture Merging:** Supports textures: albedo, metallic, roughness, emission, normal, ambient occlusion. 
If texture overlaps occur, it may be helpful to disable mipmap generation in the source texture import settings. 
Due to the resizing process, the merged texture may differ from the original. This is especially noticeable if a low target resolution is selected. Some loss of detail or minor artifacts might occur. 
> 
> **Animation Texture Import Settings:** If you choose to save your textures in separate files, remember to update your animation texture import settings in Godot:
> * **Compress Mode:** `VRAM Uncompressed`
> * **Mipmaps Generate:** `Off`
> * **Detect 3D Compress to:** `Disabled`

## ⚙️ Requirements

* Godot Engine 4.5+
