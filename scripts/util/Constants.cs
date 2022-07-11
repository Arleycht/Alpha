using Godot;
using System;

public partial class Constants : Node3D
{
    public const int BlockSize = 16;
    public const string ModulesPath = "user://modules";
    public const string CoreModulePath = "res://modules/core";
    public const string DefaultTexturePath = "res://modules/core/textures/null.png";
    public const string DefaultTextureID = "core/null.png";

    // Gender constants

    enum Gender
    {
        Female = 0,
        Male,
    }
}
