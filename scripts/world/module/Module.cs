using Godot;
using GDict = Godot.Collections.Dictionary;
using System;
using System.Collections.Generic;

public partial class Module : Resource
{
    public readonly string Name;
    public readonly string Path;
    public readonly string ConfigPath;
    public readonly int LoadOrder;

    public readonly bool IsLoaded = false;

    public readonly List<VoxelDefinition> VoxelDefinitions = new List<VoxelDefinition>();
    public readonly Dictionary<TextureID, ImageEntry> ImageEntries = new Dictionary<TextureID, ImageEntry>();

    public Module(string modulePath)
    {
        Util.Log("Reading module at \"{0}\"", modulePath);

        Directory dir = new Directory();
        ConfigFile config = new ConfigFile();

        string configPath = modulePath + "/module.cfg";

        if (dir.Open(modulePath) == Error.Ok && config.Load(configPath) == Error.Ok)
        {
            Path = modulePath;
            
            if (config.HasSection("config"))
            {
                if (config.HasSectionKey("config", "name"))
                {
                    Name = (string)config.GetValue("config", "name");
                    Name = Name.ToLower();
                }
                else
                {
                    Util.LogError("No name found in config");
                }

                if (config.HasSectionKey("config", "load_order"))
                {
                    LoadOrder = Convert.ToInt32(config.GetValue("config", "load_order", 1));
                }
                else
                {
                    Util.LogError("Load order not specified for module at \"{0}\"", modulePath);
                }
            }
            else
            {
                Util.LogError("No config section at \"{0}\"", configPath);
            }

            if (dir.ChangeDir("definitions") == Error.Ok)
            {
                // TODO: Get files recursively for better organization
                foreach (string fileName in dir.GetFiles())
                {
                    if (!fileName.EndsWith(".json"))
                    {
                        continue;
                    }

                    string defPath = dir.GetCurrentDir() + "/" + fileName;
                    VoxelDefinition definition = LoadDefinition(defPath);

                    if (definition.Id != null)
                    {
                        VoxelDefinitions.Add(definition);
                    }
                    else
                    {
                        Util.LogError("Invalid definition at \"{0}\"", defPath);
                    }
                }
            }
            else
            {
                Util.LogError("Failed to open directory at \"{0}\"", modulePath);
            }

            if (Name != null)
            {
                if (VoxelDefinitions.Count <= 0)
                {
                    Util.LogWarning("No definitions in \"{0}\"", modulePath);
                }

                IsLoaded = true;
            }
        }
        else
        {
            Util.LogError("Failed to open config file at \"{0}\"", configPath);
        }
    }

    private VoxelDefinition LoadDefinition(string path)
    {
        File file = new File();
        string fileData;
        JSON json = new JSON();

        file.Open(path, File.ModeFlags.Read);
        fileData = file.GetAsText();
        file.Close();

        json.Parse(fileData);

        if (json.GetData() is GDict)
        {
            return new VoxelDefinition(this, (GDict)json.GetData());
        }

        return new VoxelDefinition();
    }
}
