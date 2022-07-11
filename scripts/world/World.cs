using Godot;
using System;
using System.Collections.Generic;

public partial class World : Node3D
{
    public delegate void BlockLoadedHandler(Vector3 bpos);
    public delegate void BlockUnloadedHandler(Vector3 bpos);
    public delegate void MeshBlockChangedHandler();

    [Signal]
    public event BlockLoadedHandler BlockLoaded
    {
        add => Connect(nameof(BlockLoaded), new Callable(value));
        remove => Disconnect(nameof(BlockLoaded), new Callable(value));
    }
    [Signal]
    public event BlockUnloadedHandler BlockUnloaded
    {
        add => Connect(nameof(BlockUnloaded), new Callable(value));
        remove => Disconnect(nameof(BlockUnloaded), new Callable(value));
    }
    [Signal]
    public event MeshBlockChangedHandler MeshBlockChanged
    {
        add => Connect(nameof(MeshBlockChanged), new Callable(value));
        remove => Disconnect(nameof(MeshBlockChanged), new Callable(value));
    }

    private WorldLoader loader;
    private VoxelStreamSQLite stream;

    public VoxelTerrain Terrain;
    public VoxelTool Tool;

    private Dictionary<Vector3, bool> loadedBlocks = new Dictionary<Vector3, bool>();

    public override void _Ready()
    {
        loader = new WorldLoader();
        loader.Load();

        // Begin test resources

        VoxelGeneratorNoise2D generator = new VoxelGeneratorNoise2D();
        generator.Noise = new FastNoiseLite();
        generator.Channel = VoxelBuffer.ChannelId.ChannelType;
        generator.HeightStart = -25;
        generator.HeightRange = 50;

        stream = new VoxelStreamSQLite();
        stream.DatabasePath = "user://test.world";

        VoxelMesherBlocky mesher = new VoxelMesherBlocky();
        mesher.Library = loader.Library;

        // End test resources

        int maxHeight = 100;
        int minHeight = -100;
        int worldSize = 5;
        Vector3 pos = new Vector3(0, minHeight, 0);
        Vector3 size = new Vector3(1, 0, 1) * worldSize * Constants.BlockSize;
        size.y = Mathf.Abs(maxHeight - minHeight);

        Terrain = new VoxelTerrain();
        Terrain.Mesher = mesher;
        Terrain.Generator = generator;
        Terrain.MaxViewDistance = 256;
        Terrain.Bounds = new AABB(pos, size);
        Tool = Terrain.GetVoxelTool();

        Terrain.Name = "VoxelTerrain";
        AddChild(Terrain);

        Terrain.BlockLoaded += OnBlockLoaded;
        Terrain.BlockUnloaded += OnBlockUnloaded;
        Terrain.MeshBlockLoaded += OnMeshBlockLoaded;
        Terrain.MeshBlockUnloaded += OnMeshBlockUnloaded;
    }

    public bool SetVoxel(Vector3i pos, string name)
    {
        if (!loader.IdMap.ContainsKey(name))
        {
            return false;
        }

        if (!Tool.IsAreaEditable(new AABB(pos, Vector3.One)))
        {
            return false;
        }

        Tool.SetVoxel(pos, loader.IdMap[name]);

        return true;
    }

    public string GetVoxel(Vector3i pos)
    {
        return loader.NameMap[Tool.GetVoxel(pos)];
    }

    public bool IsOutOfBounds(Vector3 pos)
    {
        return !Terrain.Bounds.HasPoint(pos);
    }

    public bool IsPositionLoaded(Vector3 pos)
    {
        Vector3i blockPosition = Util.AlignVector(pos) / Constants.BlockSize;

        if (loadedBlocks.ContainsKey(blockPosition))
        {
            if (loadedBlocks[blockPosition])
            {
                return true;
            }
            else
            {
                bool isEmpty = true;

                Util.ForEachCell(blockPosition, (pos) =>
                {
                    if (Tool.GetVoxel(pos) != 0)
                    {
                        isEmpty = false;
                        return true;
                    }
                    return false;
                });

                return isEmpty;
            }
        }

        return false;
    }

    private void DeferredMeshUpdate(Vector3 bpos, bool loaded)
    {
        if (loadedBlocks.ContainsKey(bpos))
        {
            loadedBlocks[bpos] = loaded;
        }
    }

    private void OnBlockLoaded(Vector3 bpos)
    {
        Util.ForEachCell((Vector3i)bpos, pos =>
        {
            if (GetVoxel(pos) == "core:dirt" && GetVoxel(pos + new Vector3i(0, 1, 0)) == "core:air")
            {
                SetVoxel(pos, "core:grass");
            }

            return false;
        });

        if (!loadedBlocks.ContainsKey(bpos))
        {
            loadedBlocks[bpos] = false;
        }
    }

    private void OnBlockUnloaded(Vector3 bpos)
    {
        loadedBlocks.Remove(bpos);
    }

    private void OnMeshBlockLoaded(Vector3 bpos)
    {
        CallDeferred(nameof(DeferredMeshUpdate), bpos, true);
    }

    private void OnMeshBlockUnloaded(Vector3 bpos)
    {
        CallDeferred(nameof(DeferredMeshUpdate), bpos, false);
    }
}
