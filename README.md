# Jupyter_Ascending.nvim

A Neovim plugin for seamless integration with Jupyter notebooks through [Jupyter Ascending](https://github.com/imbue-ai/jupyter_ascending). This plugin allows you to edit and execute Jupyter notebooks using regular Python files while maintaining synchronization with the notebook format.

## Features

- Automatic synchronization between `.sync.py` files and `.ipynb` notebooks
- Execute individual cells or entire notebooks
- Restart Jupyter kernels
- Smart cursor-based cell execution
- Configurable auto-sync on save

## Prerequisites

- Neovim >= 0.9.0
- Python 3.x
- Jupyter Ascending package (`pip install jupyter_ascending`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "RitschAlex/jupyter-ascending.nvim",
    config = function()
        require("jupyter_ascending").setup()
    end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    "RitschAlex/jupyter-ascending.nvim",
    config = function()
        require("jupyter_ascending").setup()
    end
}
```

## Configuration

The plugin comes with sensible defaults but can be customized using the setup function:

```lua
require("jupyter_ascending").setup({
    -- Path to Python executable (default: "python")
    python_executable = "python",
    
    -- Pattern to match sync files (default: ".sync.py")
    match_pattern = ".sync.py",
    
    -- Auto-sync on save (default: true)
    auto_write = true,
    
    -- Enable default keymaps (default: true)
    default_mappings = true,
    
    -- Command timeout in milliseconds (default: 3000)
    timeout = 3000,
})
```

## Default Keymaps

When `default_mappings` is enabled, the following keymaps are available in `.sync.py` files:

| Keymap | Description |
|--------|-------------|
| `<space><space>x` | Execute current cell |
| `<space><space>X` | Execute all cells |
| `<space><space>r` | Restart Jupyter kernel |

## API

The plugin exposes the following Lua functions:

```lua
-- Sync the current file with its corresponding Jupyter notebook
require("jupyter_ascending").sync()

-- Execute the current cell
require("jupyter_ascending").execute()

-- Execute all cells in the current file
require("jupyter_ascending").execute_all()

-- Restart the Jupyter kernel
require("jupyter_ascending").restart()
```

## Custom Keymaps

If you prefer to set up your own keymaps, disable the default mappings in the setup and define your own:

```lua
require("jupyter_ascending").setup({
    default_mappings = false,
})

-- Set up custom keymaps
vim.keymap.set("n", "<leader>je", function()
    require("jupyter_ascending").execute()
end, { desc = "Execute current Jupyter cell" })

vim.keymap.set("n", "<leader>ja", function()
    require("jupyter_ascending").execute_all()
end, { desc = "Execute all Jupyter cells" })

vim.keymap.set("n", "<leader>jr", function()
    require("jupyter_ascending").restart()
end, { desc = "Restart Jupyter kernel" })
```

## Usage

1. Create a pair of synced Python and Jupyter notebook files:
```bash
python -m jupyter_ascending.scripts.make_pair --base example
```
This creates two files:
- `example.sync.py`: The Python file you'll edit in Neovim
- `example.sync.ipynb`: The Jupyter notebook file

2. Start Jupyter and open the notebook:
```bash
python -m jupyter notebook example.sync.ipynb
```

3. Edit the `example.sync.py` file in Neovim
4. Use the provided keymaps to:
   - Execute individual cells (`<space><space>x`)
   - Execute all cells (`<space><space>X`)
   - Restart the kernel (`<space><space>r`)

The plugin will automatically sync changes to the notebook file when you save the Python file (if `auto_write` is enabled).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Jupyter Ascending](https://github.com/imbue-ai/jupyter_ascending) for the core functionality
- The Neovim community for inspiration and support
