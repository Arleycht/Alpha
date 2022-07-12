using Godot;
using Godot.Collections;
using System;

public readonly struct RaycastResult
{
    public readonly bool HasHit;
    public readonly Node3D Collider;
    public readonly Vector3 Position;
    public readonly Vector3 Normal;
    public readonly RID RID;
    public readonly int Shape;

    public RaycastResult(Dictionary resultDict)
    {
        if (resultDict.Count <= 0)
        {
            HasHit = false;
            Collider = null;
            Position = new Vector3();
            Normal = new Vector3();
            RID = null;
            Shape = 0;
        }
        else
        {
            HasHit = true;
            Collider = (Node3D)resultDict["collider"];
            Position = (Vector3)resultDict["position"];
            Normal = (Vector3)resultDict["normal"];
            RID = (RID)resultDict["rid"];
            Shape = (int)resultDict["shape"];
        }
    }
}

public partial class Util : Node3D
{
    // Returns the vector aligned to coordinates
    public static Vector3i AlignVector(Vector3 vector)
    {
        return new Vector3i(vector.Floor());
    }

    // Returns an AABB from two corners
    public static AABB GetAABB(Vector3i from, Vector3i to)
    {
        Vector3i size = (from - to).Abs();
        return new AABB(GetMinPos(from, to), size);
    }

    public static Vector3i GetMinPos(Vector3i a, Vector3i b)
    {
        return new Vector3i(Mathf.Min(a.x, b.x), Mathf.Min(a.y, b.y), Mathf.Min(a.z, b.z));
    }

    public static Vector3i GetMaxPos(Vector3i a, Vector3i b)
    {
        return new Vector3i(Mathf.Max(a.x, b.x), Mathf.Max(a.y, b.y), Mathf.Max(a.z, b.z));
    }

    public static void ForEachCell(Vector3i blockPos, Func<Vector3i, bool> function)
    {
        Vector3i origin = blockPos * Constants.BlockSize;

        for (int j = 0; j < Constants.BlockSize; ++j)
        {
            for (int i = 0; i < Constants.BlockSize; ++i)
            {
                for (int k = 0; k < Constants.BlockSize; ++k)
                {
                    object result = function(origin + new Vector3i(i, j, k));

                    if ((bool)result)
                    {
                        GD.Print("Broken early");
                        break;
                    }
                }
            }
        }
    }

    public static RaycastResult Raycast(World3D world3d, Vector3 from, Vector3 to)
    {
        PhysicsRayQueryParameters3D parameters = new PhysicsRayQueryParameters3D();

        parameters.From = from;
        parameters.To = to;

        Dictionary resultDict = world3d.DirectSpaceState.IntersectRay(parameters);

        return new RaycastResult(resultDict);
    }

    public static RaycastResult Raycast(Camera3D camera, World world, float distance = 100.0f)
    {
        World3D world3d = camera.GetWorld3d();
        Vector2 mousePosition = camera.GetViewport().GetMousePosition();
        Vector3 origin = camera.ProjectRayOrigin(mousePosition);
        Vector3 normal = camera.ProjectRayNormal(mousePosition);

        PhysicsRayQueryParameters3D parameters = new PhysicsRayQueryParameters3D
        {
            From = origin,
            To = normal * distance
        };

        return new RaycastResult(world3d.DirectSpaceState.IntersectRay(parameters));
    }

    public static VoxelRaycastResult Raycast(VoxelTool tool, Vector3 from, Vector3 to)
    {
        return tool.Raycast(from, to.Normalized(), to.Length());
    }

    public static VoxelRaycastResult Raycast(Camera3D camera, VoxelTool tool, float distance = 100.0f)
    {
        Vector2 mousePosition = camera.GetViewport().GetMousePosition();
        Vector3 origin = camera.ProjectRayOrigin(mousePosition);
        Vector3 normal = camera.ProjectRayNormal(mousePosition);
        return tool.Raycast(origin, normal, distance);
    }

    public static void Log(string message, params object[] args)
    {
        GD.Print(string.Format(message, args));
    }

    public static void LogWarning(string message, params object[] args)
    {
        GD.PrintErr(string.Format(message, args));
    }

    public static void LogError(string message, params object[] args)
    {
        GD.PrintErr(string.Format(message, args));
    }
}
