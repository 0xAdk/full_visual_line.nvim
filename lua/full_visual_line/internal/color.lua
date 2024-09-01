---@class Rgb
---@field r number
---@field g number
---@field b number
local Rgb = {}

---@param rgb { r: number, g: number, b: number }
---@return Rgb
function Rgb.from_rgb(rgb)
	return setmetatable(rgb, { __index = Rgb })
end

---@param self Rgb
---@return { r: number, g: number, b: number }
function Rgb.to_rgb(self)
	return setmetatable(self, nil)
end

---@param bytes [integer, integer, integer]
---@return Rgb
function Rgb.from_bytes(bytes)
	return Rgb.from_rgb {
		r = bytes[1] / 255,
		g = bytes[2] / 255,
		b = bytes[3] / 255,
	}
end

---@param self Rgb
---@return [integer, integer, integer]
function Rgb.to_bytes(self)
	return {
		math.floor(self.r * 255),
		math.floor(self.g * 255),
		math.floor(self.b * 255),
	}
end

---@param n integer?
---@return Rgb
function Rgb.from_number(n)
	if n == nil then
		return Rgb.BLACK
	end

	return Rgb.from_bytes {
		[1] = bit.band(bit.rshift(n, 0), 0xFF),
		[2] = bit.band(bit.rshift(n, 8), 0xFF),
		[3] = bit.band(bit.rshift(n, 16), 0xFF),
	}
end

---@param self Rgb
---@return integer
function Rgb.to_number(self)
	local bytes = self:to_bytes()

	return bit.bor(
		bit.lshift(bytes[1], 0),
		bit.lshift(bytes[2], 8),
		bit.lshift(bytes[3], 16)
	)
end

---@param ns_id integer
---@param opts vim.api.keyset.get_highlight
---@return { fg: Rgb?, bg:  Rgb? }
function Rgb.get_hl(ns_id, opts)
	if opts.link == nil then
		opts.link = false
	end

	local hl = vim.api.nvim_get_hl(ns_id, opts)
	return {
		fg = hl.fg and Rgb.from_number(hl.fg),
		bg = hl.bg and Rgb.from_number(hl.bg)
	}
end

---@param self Rgb
---@return string
function Rgb.to_hex_string(self)
	return string.format('#%02x%02x%02x', unpack(self:to_bytes()))
end

---@param self Rgb
---@param other Rgb
---@return Rgb
function Rgb.average(self, other)
	return self:blend(other, 0.5)
end

---@param lhs number
---@param rhs number
---@param blend number
---@return number
Rgb.default_blend_fn = function(lhs, rhs, blend)
	return math.sqrt(lhs * lhs * (1 - blend) + rhs * rhs * blend)
end

---@param self Rgb
---@param other Rgb
---@param blend number
---@param blend_fn? fun(lhs: number, rhs: number, blend: number)
---@return Rgb
function Rgb.blend(self, other, blend, blend_fn)
	blend_fn = blend_fn or Rgb.default_blend_fn

	return Rgb.from_rgb {
		r = blend_fn(self.r, other.r, blend),
		g = blend_fn(self.g, other.g, blend),
		b = blend_fn(self.b, other.b, blend),
	}
end

Rgb.BLACK = Rgb.from_rgb { r = 0, g = 0, b = 0 };

return {
	Rgb = Rgb
}
