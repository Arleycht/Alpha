using Godot;
using System;
using System.Collections.Generic;

public partial class Navigator : Node
{
    public World World;
    public Character Character;

    public List<Vector3i> Path { get; private set; } = new List<Vector3i>();
    public int PathIndex { get; private set; } = 0;

    private ulong LastCheckTime = 0;
    private Vector3 LastPosition = new Vector3();
    
    public void Update()
    {
        if (World == null || Character == null || Path.Count == 0)
        {
            return;
        }

        Vector3 target = GetCurrentPosition();
        float closeEnough = Mathf.Max(Character.GetAabb().Size.x, Character.GetAabb().Size.z);
        bool isLast = (PathIndex == Path.Count - 1);

        if (isLast)
        {
            closeEnough *= 0.1f;
        }
        else if (closeEnough > 0.5f)
        {
            closeEnough *= 0.5f;
        }
        else
        {
            closeEnough = 0.5f;
        }

        // Move character

        Vector3 diff = target - Character.Position;
        Vector3 hDiff = Plane.PlaneXZ.Project(diff);

        Character.WishVector = hDiff.Normalized() * Mathf.Clamp(hDiff.Length(), 0.1f, 1.0f);
        
        if (diff.y > Character.JumpHeight * 0.75f)
        {
            if (hDiff.LengthSquared() < 2.0f && !Character.IsJumping)
            {
                
            }
        }
        else if (diff.y < -0.75f || isLast)
        {
            // Precision movement for descending and last waypoint
            if (Plane.PlaneXZ.Project(Character.Velocity).Length() > 2.5f)
            {
                Character.WishVector *= -1.0f;
            }
        }

        // Increment path position

        if (hDiff.LengthSquared() < closeEnough * closeEnough && Mathf.Abs(diff.y) < 0.5f)
        {
            PathIndex++;
        }

        if (Time.GetTicksMsec() - LastCheckTime > 5000)
        {
            if ((Character.Position - LastPosition).LengthSquared() < 2.25f)
            {
                Path.Clear();
            }

            LastCheckTime = Time.GetTicksMsec();
            LastPosition = Character.Position;
        }
    }

    public void MoveTo(Vector3 target)
    {
        if (World == null || Character == null)
        {
            return;
        }

        UpdatePath(Util.AlignVector(Character.Position), Util.AlignVector(target));
    }

    public Vector3 GetCurrentPosition()
    {
        if (Path.Count == 0)
        {
            return Vector3.Zero;
        }

        return Path[PathIndex] + new Vector3(0.5f, 0.0f, 0.5f);
    }

    protected void UpdatePath(Vector3i from, Vector3i to,
        Func<Vector3i, bool> clearance_f = null, Func<Vector3i, Vector3i, float> cost_f = null,
        Func<Vector3i, Vector3i, float> heuristic_f = null, int maxPathLength = 1024)
    {
        clearance_f = clearance_f != null ? clearance_f : DefaultClearanceFunction;
        cost_f = cost_f != null ? cost_f : DefaultCostFunction;
        heuristic_f = heuristic_f != null ? heuristic_f : DefaultHeuristicFunction;

        Path.Clear();

        // If the character is standing on the edge of a valid voxel
        // they may technically be over an invalid voxel.
        // Therefore, we try to find the actual voxel they are standing on.
        if (!clearance_f(from))
        {
            bool found = false;
            int width = (int)Mathf.Ceil(Character.GetAabb().GetLongestAxisSize());

            for (int i = -width; i < width + 1; ++i)
            {
                for (int j = -width; j < width + 1; ++j)
                {
                    Vector3i pos = new Vector3i(from.x + i, from.y, from.z + j);

                    if (clearance_f(pos))
                    {
                        from = pos;
                        found = true;
                        break;
                    }

                    if (found)
                    {
                        break;
                    }
                }

                if (found)
                {
                    break;
                }
            }

            if (!clearance_f(to) || !World.IsPositionLoaded(from) || !World.IsPositionLoaded(to))
            {
                return;
            }
        }

        HashSet<Vector3i> open = new HashSet<Vector3i> { from };
        Dictionary<Vector3i, Vector3i> map = new Dictionary<Vector3i, Vector3i>();
        Dictionary<Vector3i, int> pathLengths = new Dictionary<Vector3i, int>();
        Dictionary<Vector3i, float> gMap = new Dictionary<Vector3i, float>();
        Dictionary<Vector3i, float> fMap = new Dictionary<Vector3i, float>();

        pathLengths[from] = 0;
        gMap[from] = 0.0f;
        fMap[from] = 0.0f;

        while (open.Count > 0)
        {
            List<Vector3i> sortedFScores = new List<Vector3i>(open);
            sortedFScores.Sort((a, b) => fMap[a].CompareTo(fMap[b]));

            Vector3i current = sortedFScores[0];
            
            if (current == to)
            {
                Path.Clear();
                
                while (map.ContainsKey(current))
                {
                    Path.Add(current);
                    current = map[current];
                }

                Path.Reverse();

                PathIndex = 0;
                LastCheckTime = Time.GetTicksMsec();

                return;
            }

            open.Remove(current);

            if (pathLengths[current] > maxPathLength)
            {
                continue;
            }

            foreach (Vector3i neighbor in GetNeighbors(current))
            {
                if (!World.IsPositionLoaded(neighbor))
                {
                    continue;
                }

                if (!clearance_f(neighbor) || !IsTraversalClear(current, neighbor, clearance_f))
                {
                    continue;
                }

                float g = gMap[current] + cost_f(current, neighbor);

                if (!gMap.ContainsKey(neighbor) || g < gMap[neighbor])
                {
                    map[neighbor] = current;
                    pathLengths[neighbor] = pathLengths[current] + 1;
                    gMap[neighbor] = g;
                    fMap[neighbor] = g + heuristic_f(neighbor, to);

                    if (!open.Contains(neighbor))
                    {
                        open.Add(neighbor);
                    }
                }
            }
        }
    }

    private bool DefaultClearanceFunction(Vector3i pos)
    {
        string floor = World.GetVoxel(pos);
        string occupied = World.GetVoxel(pos + new Vector3i(0, 1, 0));

        return World.IsPositionLoaded(pos) && floor != "core:air" && occupied == "core:air";
    }

    private float DefaultCostFunction(Vector3i a, Vector3i b)
    {
        float h = (new Vector3i(b.x - a.x, 0, b.z - a.z)).LengthSquared();
        float v = Mathf.Abs(b.y - a.y);

        if (b.y > a.y)
        {
            v *= 2.8f;
        }
        else
        {
            v = 0.0f;
        }

        return h + v;
    }

    private float DefaultHeuristicFunction(Vector3i a, Vector3i b)
    {
        a.y = 0;
        b.y = 0;
        return (b - a).LengthSquared() * 0.5f;
    }

    private List<Vector3i> GetNeighbors(Vector3i pos)
    {
        List<Vector3i> neighbors = new List<Vector3i>();

        for (int i = -1; i < 2; ++i)
        {
            for (int j = -1; j < 2; ++j)
            {
                for (int k = 0; k < 2; k++)
                {
                    if (i == 0 && j == 0 && k == 0)
                    {
                        continue;
                    }

                    neighbors.Add(pos + new Vector3i(i, j, k));
                }
            }
        }

        return neighbors;
    }

    private bool IsTraversalClear(Vector3i a, Vector3i b, Func<Vector3i, bool> clearance_f = null)
    {
        clearance_f = clearance_f != null ? clearance_f : DefaultClearanceFunction;

        Vector3i delta = (b - a).Sign();
        Vector3i dx = new Vector3i(delta.x, 0, 0);
        Vector3i dy = new Vector3i(0, delta.y, 0);
        Vector3i dz = new Vector3i(0, 0, delta.z);

        while (a != b)
        {
            if (a.x != b.x && clearance_f(a + dx))
            {
                a += dx;
            }
            else if (a.z != b.z && clearance_f(a + dz))
            {
                a += dz;
            }
            else if (a.y != b.y)
            {
                if (delta.y > 0 && World.GetVoxel(a + dy) != "core:air")
                {
                    return false;
                }
                else
                {
                    a += dy;
                }
            }
            else
            {
                return false;
            }
        }

        return true;
    }
}
