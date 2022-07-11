using Godot;
using System;
using System.Collections.Generic;

public partial class VoxelDefinition : Resource
{
    public readonly string Id;
    public readonly Mesh CustomMesh;
    public readonly Dictionary<string, TextureID> TextureMap = new Dictionary<string, TextureID>();

    public VoxelDefinition() { }

    public VoxelDefinition(Module module, Godot.Collections.Dictionary dict)
    {
        if (!dict.Contains("name"))
        {
            Util.LogError("Invalid voxel definition");
            return;
        }

        Id = module.Name + ":" + ((string)dict["name"]).ToLower();

        if (dict.Contains("textures"))
        {
            Godot.Collections.Dictionary textures = (Godot.Collections.Dictionary)dict["textures"];

            foreach (string key in textures.Keys)
            {
                TextureID textureId = new TextureID(module, (string)textures[key]);
                TextureMap[key] = textureId;
            }
        }

        if (dict.Contains("mesh"))
        {
            throw new NotImplementedException("Custom block meshes not implemented yet");
        }
    }
}
