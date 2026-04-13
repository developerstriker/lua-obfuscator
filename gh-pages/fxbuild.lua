local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return (str:match("(.*[/%\\])") or ""):gsub("/$", "")
end
local base_dir = script_path():gsub("/src$", "")
package.path = base_dir .. "/prometheus/src/?.lua;" .. package.path

local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info
Prometheus.colors.enabled = true

local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

local function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do lines[#lines + 1] = line end
    return lines
end

local function read_file(file)
    local f = io.open(file, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(file, content)
    local f = io.open(file, "w")
    f:write(content)
    f:close()
end

local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function getFiles(dir, pattern)
    local files = {}
    local handle = io.popen('ls "' .. dir .. '" 2>/dev/null')
    if handle then
        for line in handle:lines() do
            local path = dir .. "/" .. line
            if pattern == "*" or line:match(pattern) then
                files[#files + 1] = path
            end
        end
        handle:close()
    end
    return files
end

local function getAllLuaFiles(dir)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -type f -name "*.lua" 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end

local fxmanifestPath, presetName

local i = 1
while i <= #arg do
    local curr = arg[i]
    if curr:sub(1, 2) == "--" then
        if curr == "--preset" or curr == "--p" then
            i = i + 1
            presetName = arg[i]
        end
    else
        fxmanifestPath = curr
    end
    i = i + 1
end

if not fxmanifestPath then
    print("Usage: fxbuild.sh <fxmanifest.lua> [--preset <nome>]")
    print("Example: fxbuild.sh resource/fxmanifest.lua --preset minify")
    os.exit(1)
end

fxmanifestPath = fxmanifestPath:gsub("\\", "/")

local manifestDir = fxmanifestPath:match("(.+)/")
if not manifestDir then manifestDir = "." end

local resourceName = manifestDir:match("([^/]+)$")

local function parseManifest(content)
    local commands = {
        server_scripts = {},
        client_scripts = {},
        shared_scripts = {}
    }
    
    for line in content:gmatch("[^\r\n]+") do
        line = trim(line)
        if line:match("^server_scripts?") then
            local files = line:match("^server_scripts?%s*(.+)$")
            if files then
                for _, f in ipairs(split(files, "%s+")) do
                    commands.server_scripts[#commands.server_scripts + 1] = trim(f:gsub('"', ''):gsub("'", ""))
                end
            end
        elseif line:match("^client_scripts?") then
            local files = line:match("^client_scripts?%s*(.+)$")
            if files then
                for _, f in ipairs(split(files, "%s+")) do
                    commands.client_scripts[#commands.client_scripts + 1] = trim(f:gsub('"', ''):gsub("'", ""))
                end
            end
        elseif line:match("^shared_scripts?") then
            local files = line:match("^shared_scripts?%s*(.+)$")
            if files then
                for _, f in ipairs(split(files, "%s+")) do
                    commands.shared_scripts[#commands.shared_scripts + 1] = trim(f:gsub('"', ''):gsub("'", ""))
                end
            end
        end
    end
    
    return commands
end

print("Loading fxmanifest: " .. fxmanifestPath)
local manifestContent = read_file(fxmanifestPath)
if not manifestContent then
    print("Error: fxmanifest.lua not found")
    os.exit(1)
end

local commands = parseManifest(manifestContent)

local function expandPattern(path)
    if not path or path == "" then
        return {}
    end
    if path:find("%*") then
        local baseDir = manifestDir
        local dirMatch = path:match("([^%/]+)/")
        if dirMatch then
            baseDir = manifestDir .. "/" .. dirMatch
        end
        if not baseDir or baseDir == "" then baseDir = manifestDir end
        local results = {}
        local allFiles = getAllLuaFiles(baseDir)
        for _, fullPath in ipairs(allFiles) do
            local filename = fullPath:match("([^/]+)$")
            if filename and filename:match("%.lua$") then
                local relativePath
                if baseDir ~= manifestDir then
                    relativePath = dirMatch .. "/" .. filename
                else
                    relativePath = filename
                end
                results[#results + 1] = relativePath
            end
        end
        return results
    end
    return {path}
end

local function collectScripts(type)
    local scripts = {}
    for _, pattern in ipairs(commands[type]) do
        local expanded = expandPattern(pattern)
        for _, file in ipairs(expanded) do
            local fullPath = manifestDir .. "/" .. file
            local content = read_file(fullPath)
            if content then
                scripts[#scripts + 1] = {file = file, content = content}
            end
        end
    end
    return scripts
end

local serverScripts = collectScripts("server_scripts")
local clientScripts = collectScripts("client_scripts")
local sharedScripts = collectScripts("shared_scripts")

print("Found scripts:")
print("  Server: " .. #serverScripts)
print("  Client: " .. #clientScripts)
print("  Shared: " .. #sharedScripts)

local function buildScript(scripts)
    local code = ""
    for _, s in ipairs(scripts) do
        code = code .. "-- File: " .. s.file .. "\n"
        code = code .. s.content .. "\n\n"
    end
    return code
end

local serverCode = buildScript(serverScripts)
local clientCode = buildScript(clientScripts)
local sharedCode = buildScript(sharedScripts)

local combinedServer = sharedCode .. "\n" .. serverCode
local combinedClient = sharedCode .. "\n" .. clientCode

local config = presetName and Prometheus.Presets[presetName] or Prometheus.Presets.Minify
local pipeline = Prometheus.Pipeline:fromConfig(config)

Prometheus.Logger:info("Obfuscating server code...")
local obfuscatedServer = pipeline:apply(combinedServer, "server.lua")

Prometheus.Logger:info("Obfuscating client code...")
local obfuscatedClient = pipeline:apply(combinedClient, "client.lua")

local outputDir = manifestDir .. "/dist"
os.execute("mkdir -p '" .. outputDir .. "'")

write_file(outputDir .. "/_server.obfuscated.lua", obfuscatedServer)
write_file(outputDir .. "/_client.obfuscated.lua", obfuscatedClient)

local fxmanifestOutput = [[fx_version 'cerulean'
game 'gta5'

server_script '_server.obfuscated.lua'
client_script '_client.obfuscated.lua'
]]

write_file(outputDir .. "/fxmanifest.lua", fxmanifestOutput)

print("")
print("Build complete!")
print("Output files:")
print("  " .. outputDir .. "/_server.obfuscated.lua")
print("  " .. outputDir .. "/_client.obfuscated.lua")
print("  " .. outputDir .. "/fxmanifest.lua")