using Godot;
using GDict = Godot.Collections.Dictionary;
using System;
using System.Collections.Generic;

public struct TextureID
{
    public readonly Module Module;
    public readonly string TextureName;
    public readonly string TexturePath;
    public readonly string Id;

    public TextureID(Module module, string textureFileName)
    {
        Module = module;
        TextureName = textureFileName;
        TexturePath = module.Path + "/textures/" + textureFileName;
        Id = module.Name.ToLower() + ":" + textureFileName.ToLower();
    }

    public override bool Equals(object o)
    {
        return o is TextureID id && this == id;
    }

    public static bool operator ==(TextureID a, TextureID b)
    {
        return a.TexturePath == b.TexturePath;
    }

    public static bool operator !=(TextureID a, TextureID b)
    {
        return a.TexturePath != b.TexturePath;
    }

    public override int GetHashCode()
    {
        return TexturePath.GetHashCode();
    }
}

public struct ImageEntry
{
    public Rect2i Rect;
    public readonly Image Image;

    public ImageEntry(Image image, Vector2i position = new Vector2i())
    {
        Rect = new Rect2i(position, (Vector2i)image.GetSize());
        Image = image;
    }

    public void SetPosition(Vector2i position)
    {
        Rect.Position = position;
    }
}

public partial class WorldLoader : Node3D
{
    public VoxelBlockyLibrary Library { get; private set; }
    public Dictionary<string, Module> ModuleMap { get; private set; } = new Dictionary<string, Module>();
    public Dictionary<ulong, string> NameMap { get; private set; } = new Dictionary<ulong, string>();
    public Dictionary<string, ulong> IdMap { get; private set; } = new Dictionary<string, ulong>();
    public ImageTexture AtlasTexture { get; private set; }
    public Dictionary<TextureID, ImageEntry> AtlasMap { get; private set; } = new Dictionary<TextureID, ImageEntry>();

    private Image AtlasImage;

    public void Load()
    {
        GD.Print("Loading modules");
        LoadModules();
    }

    private void LoadModules()
    {
        ModuleMap.Add("core", new Module(Constants.CoreModulePath));

        Directory dir = new Directory();

        if (!dir.DirExists(Constants.ModulesPath))
        {
            dir.MakeDirRecursive(Constants.ModulesPath);
        }

        if (dir.Open(Constants.ModulesPath) == Error.Ok)
        {
            foreach (string moduleName in dir.GetDirectories())
            {
                Module module = new Module(dir.GetCurrentDir() + "/" + moduleName);

                if (module.IsLoaded)
                {
                    ModuleMap.Add(module.Name.ToLower(), module);
                }
            }
        }
        else
        {
            GD.PrintErr("Could not open modules directory");
        }

        Library = new VoxelBlockyLibrary()
        {
            BakeTangents = false,
            VoxelCount = 0,
        };

        // Hard coded empty voxel
        Library.VoxelCount += 1;
        Library.CreateVoxel(0, "air");
        NameMap[0] = "core:air";
        IdMap["core:air"] = 0;

        // Generate atlas mappings
        GenerateAtlas(ModuleMap.Values);

        // Generate default material
        StandardMaterial3D material = new StandardMaterial3D
        {
            AlbedoTexture = AtlasTexture,
            VertexColorUseAsAlbedo = true,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
        };

        List<KeyValuePair<string, Module>> modules = new List<KeyValuePair<string, Module>>(ModuleMap);
        modules.Sort((a, b) => a.Value.LoadOrder.CompareTo(b.Value.LoadOrder));

        foreach (var pair1 in modules)
        {
            foreach (var def in pair1.Value.VoxelDefinitions)
            {
                if (IdMap.ContainsKey(def.Id))
                {
                    GD.PrintErr("Duplicate voxel id: " + def.Id);
                }
                else
                {
                    Library.VoxelCount++;
                    NameMap[Library.VoxelCount - 1] = def.Id;
                    IdMap[def.Id] = Library.VoxelCount - 1;

                    ArrayMesh mesh = BuildCubeMesh(def.TextureMap);
                    var voxel = Library.CreateVoxel(Library.VoxelCount - 1, def.Id);

                    voxel.GeometryType = VoxelBlockyModel.GeometryTypeEnum.CustomMesh;
                    voxel.CustomMesh = mesh;
                    voxel.SetMaterialOverride(0, material);

                    Util.Log("Loaded voxel definition");
                }
            }
        }

        Library.Bake();
    }

    private void GenerateAtlas(ICollection<Module> modules)
    {
        GenerateAtlasMap(modules);
        Vector2i atlasSize = PackImages();

        AtlasImage = new Image();
        AtlasImage.Create(atlasSize.x, atlasSize.y, false, Image.Format.Rgba8);

        Util.Log(atlasSize.ToString());

        foreach (ImageEntry entry in AtlasMap.Values)
        {
            AtlasImage.BlitRect(entry.Image, new Rect2(Vector2.Zero, entry.Rect.Size), entry.Rect.Position);
        }

        AtlasTexture = ImageTexture.CreateFromImage(AtlasImage);
    }

    private Dictionary<TextureID, ImageEntry> GenerateAtlasMap(ICollection<Module> modules)
    {
        Dictionary<TextureID, ImageEntry> map = new Dictionary<TextureID, ImageEntry>();

        foreach (Module module in modules)
        {
            foreach (VoxelDefinition definition in module.VoxelDefinitions)
            {
                foreach (TextureID textureId in definition.TextureMap.Values)
                {
                    if (!AtlasMap.ContainsKey(textureId))
                    {
                        ImageEntry entry = LoadImage(textureId.TexturePath);
                        AtlasMap.Add(textureId, entry);
                    }
                }
            }
        }

        return map;
    }

    private Vector2i PackImages(int padding = 1)
    {
        List<KeyValuePair<TextureID, ImageEntry>> pairs = new List<KeyValuePair<TextureID, ImageEntry>>(AtlasMap);
        Vector2i pos = Vector2i.One * padding;
        Vector2i size = new Vector2i();
        int maxWidth = 0;

        // Sort by height
        pairs.Sort((a, b) => a.Value.Rect.Size.y - b.Value.Rect.Size.y);

        foreach (var pair in pairs)
        {
            size.x += pair.Value.Rect.Size.x;
            maxWidth = Mathf.Max(pair.Value.Rect.Size.x, maxWidth);
        }

        // Choose an arbitrary maximum width to pack into
        // Optimally, should be as close as possible to a square,
        // hence half the total width
        size.x += ((pairs.Count * 2) + 1) * padding;
        maxWidth = Mathf.Max(size.x >> 1, maxWidth);

        size = new Vector2i();

        foreach (var pair in pairs)
        {
            Rect2i rect = pair.Value.Rect;

            size.y = Mathf.Max(size.y, rect.Size.y);

            if (pos.x + rect.Size.x + padding > maxWidth)
            {
                pos.x = padding;
                pos.y = size.y + padding;
            }

            ImageEntry entry = AtlasMap[pair.Key];
            entry.Rect = new Rect2i(pos, entry.Rect.Size);
            AtlasMap[pair.Key] = entry;

            size.x = Mathf.Max(size.x, pos.x + rect.Size.x);
            size.y = Mathf.Max(size.y, pos.y + rect.Size.y);
            pos.x += rect.Size.x + padding;
        }

        return size + Vector2i.One * padding;
    }

    private ImageEntry LoadImage(string path)
    {
        Image image = new Image();

        if (!File.FileExists(path))
        {
            path = Constants.DefaultTexturePath;

            Util.LogError("Failed to find image at \"{0}\"", path);
        }

        if (path.BeginsWith("res://"))
        {
            Texture2D texture = (Texture2D)GD.Load(path);

            if (texture == null)
            {
                texture = (Texture2D)GD.Load(Constants.DefaultTexturePath);
            }

            image = texture.GetImage();
        }
        else
        {
            image.Load(path);
        }

        image.Convert(Image.Format.Rgba8);

        return new ImageEntry(image);
    }

    private List<Vector2> MapUV(Rect2i rect, Vector2 atlasSize)
    {
        Vector2 s = (Vector2)rect.Size / atlasSize;
        Vector2 a = (Vector2)rect.Position / atlasSize;
        Vector2 b = a + new Vector2(s.x, 0.0f);
        Vector2 c = a + new Vector2(0.0f, s.y);
        Vector2 d = a + s;
        return new List<Vector2> { d, a, b, d, c, a };
    }

    private ArrayMesh BuildCubeMesh(Dictionary<string, TextureID> textureMap)
    {
        Vector3[] vertices = {
            new Vector3(1, 0, 0),
            new Vector3(1, 0, 1),
            new Vector3(0, 0, 1),
            new Vector3(0, 0, 0),
            new Vector3(1, 1, 0),
            new Vector3(1, 1, 1),
            new Vector3(0, 1, 1),
            new Vector3(0, 1, 0),
        };


        Vector3[] normals = {
            new Vector3(1, 0, 0),
            new Vector3(0, 0, 1),
            new Vector3(-1, 0, 0),
            new Vector3(0, 0, -1),
            new Vector3(0, 1, 0),
            new Vector3(0, -1, 0),
        };


        int[] indices = {
            0, 5, 4, 0, 1, 5,
            1, 6, 5, 1, 2, 6,
            2, 7, 6, 2, 3, 7,
            3, 4, 7, 3, 0, 4,
            4, 6, 7, 4, 5, 6,
            3, 1, 0, 3, 2, 1,
        };

        ArrayMesh mesh = new ArrayMesh();

        List<Vector3> vertexArray = new List<Vector3>();
        List<Vector2> uvArray = new List<Vector2>();
        List<Vector3> normalArray = new List<Vector3>();
        List<int> indexArray = new List<int>();

        for (int side = 0; side < 6; ++side)
        {
            for (int tri = 0; tri < 2; ++tri)
            {
                int j = (side * 6) + (tri * 3);
                for (int i = 0; i < 3; ++i)
                {
                    vertexArray.Add(vertices[indices[j + i]]);
                    normalArray.Add(normals[side]);
                    indexArray.Add(j + i);
                }
            }
        }

        if (textureMap.ContainsKey("all"))
        {
            TextureID textureId = textureMap["all"];
            Rect2i rect = AtlasMap[textureId].Rect;
            List<Vector2> face_uvs = MapUV(rect, AtlasTexture.GetSize());

            for (int i = 0; i < 6; ++i)
            {
                uvArray.AddRange(face_uvs);
            }
        }
        else
        {
            Vector2[] uvs = new Vector2[36];

            foreach (string side in textureMap.Keys)
            {
                TextureID textureId = textureMap[side];
                Rect2i rect = AtlasMap[textureId].Rect;
                List<Vector2> face_uvs = MapUV(rect, AtlasTexture.GetSize());
                int face = 0;

                switch (side)
                {
                    case "south":
                        face = 0;
                        break;
                    case "west":
                        face = 1;
                        break;
                    case "north":
                        face = 2;
                        break;
                    case "east":
                        face = 3;
                        break;
                    case "top":
                        face = 4;
                        break;
                    case "bottom":
                        face = 5;
                        break;
                }
                
                for (int i = 0; i < 6; ++i)
                {
                    uvs[(face * 6) + i] = face_uvs[i];
                }
            }

            uvArray.AddRange(uvs);
        }

        Godot.Collections.Array array = new Godot.Collections.Array();
        array.Resize((int)Mesh.ArrayType.Max);
        array[(int)Mesh.ArrayType.Vertex] = vertexArray;
        array[(int)Mesh.ArrayType.TexUv] = uvArray;
        array[(int)Mesh.ArrayType.Normal] = normalArray;
        array[(int)Mesh.ArrayType.Index] = indexArray;
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, array);
        mesh.RegenNormalMaps();
        return mesh;
    }
}
