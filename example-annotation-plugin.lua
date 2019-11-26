-- we will use this simple template library to help us write out the data
local liluat = require("liluat")

-- path to the template
local templateFolder = 
  debug.getinfo(1, "S").source:sub(2):match("^.*[/\\]") .. 'template/'

-- define the plugin functions as local functions
local function name()
  return "Annotation Exporter"
end

local function version()
  return "1.0.1"
end

local function init()
end

local function cleanup()
end

-- helper function for reading the entire contents of a file into a string
local function slurp(file)
  local f = assert(io.open(file))
  local s = f:read("*a")
  f:close()
  return s
end

-- helper function for writing a string to a file
local function write(file, text)
  local f = io.open(file, "w")
  f:write(text)
  f:close()
end

-- specify that this plugin exports XML and HTML files
local function exportFormats()
  return [[
    <filetypes>
      <type ext="html" desc="HTML File" />
      <type ext="xml" desc="XML File" />
    </filetypes>
  ]]
end

-- declare some variables that will hold some state info during the export process,
-- shared between a number of functions (which is why they aren't local to a particular function)
local exportFile
local exportFolder
local id

-- Walk through the tree and gather up annotation data into a lua table structure for the template engine:
--[[
  {
    title = "annotation export",
    date = "right now",
    annotations = {
      {
        name = "part",
        author = "jamie",
        viewpoints = {
          {
            image = "path/to/file",
            position = "1, 2, 3",
            rotation = "4, 5, 6"
          },
          { ... etc }
        },
        comments = {
          {
            author = "jamie",
            text = "hello"
          },
          { ... etc }
        }
      },
      { ... etc }
    }
  }
]]
local function buildData(node, data)
  local t = node:type(false)

  local childData = nil
  if t == "AnnotationList" then
    childData = {
      title = "Annotation Export",
      date = os.date(),
      annotations = {}
    }
  elseif t == "Annotation" then
    childData = {
      name = node:getName(),
      author = node.CreatedBy,
      viewpoints = {},
      comments = {}
    }
    table.insert(data.annotations, childData)
  elseif t == "AnnotationComment" then
    table.insert(data.comments, {
      author = node.CreatedBy,
      text = node.Comment
    })
  elseif t == "Viewpoint" then
    local pos, rot, scale = vrNodeDecomposeTransform(node)
    local tex = node:sibling("Texture")
    local filename = ""
    if tex then
      filename = exportFolder .. "\\viewpoint-" .. id .. ".png"
      id = id + 1
      vrExtractBinaryAssets(tex, filename, true, vrNodeGetMetaNode(tex, true))   
    end

    table.insert(data.viewpoints, {
      image = filename,
      position = tostring(pos),
      rotation = tostring(rot)
    })
  elseif t == "Assembly" then
    childData = data
  end

  local child = node:child()
  while child and childData do
    buildData(child, childData)
    child = child:next()
  end

  return childData
end

-- finds the Annotations node in the Scenes tree and exports them
local function export(file, root, scenes, libs, recipePath)
  local s = scenes:child("AnnotationList", "Annotations")
  if not s then
    vrMessageBox("No annotations found", name(), "ok,error")
    return 1
  else
    -- populate the file and folder variables
    exportFile = file
    exportFolder = file:match("(.+)%..+$")
    -- extract the export file extension so we know whether to use the xml or html template
    -- (or any other file template you might want to define)
    local exportType = file:match("^.+(%..+)$"):lower():sub(2)
    id = 1

    -- compile the template, gather the annotation data, and insert it
    local template = slurp(templateFolder .. 'template.' .. exportType)
    local compiled_template = liluat.compile(template)
    local data = buildData(s)
    local render = liluat.render(compiled_template, data)

    -- write the rendered template to file (e.g. the final html output)
    write(exportFile, render)

    -- for html output we added some basic styles to the template,
    -- so we need to copy some extra files to the output location
    local extraFiles = {
      xml = {},
      html = {
        "bootstrap.min.css",
        "logo.png"
      }
    }

    local extra = extraFiles[exportType]
    if extra and #extra > 0 then
      for _, file in ipairs(extra) do
        write(exportFolder .. "/" .. file, slurp(templateFolder .. file))
      end
    end

    return 0
  end
end

-- export the functions to the Lua state
return {
  name = name,
  version = version,
  init = init,
  cleanup = cleanup,
  exportFormats = exportFormats,
  export = export
}