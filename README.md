# Full Visual Line
A simple plugin that highlights whole lines in linewise visual mode (`V`)

<details open>
<summary>Example Images</summary>

#### Before
![Preview Before](https://i.imgur.com/1Qw1jSk.png)

#### After
![Preview After](https://i.imgur.com/skIx5Jo.png)

</details>

## Installation Example
<details>
<summary>packer.nvim</summary>

> [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
	'0xAdk/full_visual_line.nvim',
	config = function ()
		require 'full_visual_line'.setup {}
	end
}
```
</details>
