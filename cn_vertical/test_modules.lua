-- Test script to verify Lua module loading
package.path = package.path .. ';./?.lua'

print("=== Testing cn_vertical module loading ===")
print("package.path = " .. package.path)
print()

print("Loading cn_vertical_constants...")
local ok, constants = pcall(require, 'cn_vertical_constants')
if ok then
    print("SUCCESS: constants loaded")
    print("  GLYPH =", constants.GLYPH)
    print("  to_dimen =", constants.to_dimen)
else
    print("ERROR:", constants)
    os.exit(1)
end
print()

print("Loading cn_vertical_flatten...")
local ok, flatten = pcall(require, 'cn_vertical_flatten')
if ok then
    print("SUCCESS: flatten loaded")
    print("  flatten_vbox =", flatten.flatten_vbox)
else
    print("ERROR:", flatten)
    os.exit(1)
end
print()

print("Loading cn_vertical_layout...")
local ok, layout = pcall(require, 'cn_vertical_layout')
if ok then
    print("SUCCESS: layout loaded")
    print("  calculate_grid_positions =", layout.calculate_grid_positions)
else
    print("ERROR:", layout)
    os.exit(1)
end
print()

print("Loading cn_vertical_render...")
local ok, render = pcall(require, 'cn_vertical_render')
if ok then
    print("SUCCESS: render loaded")
    print("  apply_positions =", render.apply_positions)
else
    print("ERROR:", render)
    os.exit(1)
end
print()

print("Loading cn_vertical...")
local ok, cn_vert = pcall(require, 'cn_vertical')
if ok then
    print("SUCCESS: cn_vertical loaded")
    print("  make_grid_box =", cn_vert.make_grid_box)
    print("  Global cn_vertical =", _G.cn_vertical)
else
    print("ERROR:", cn_vert)
    os.exit(1)
end
print()

print("=== All modules loaded successfully! ===")
