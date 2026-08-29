# Jupyter_Ascending.nvim

A Neovim plugin for seamless integration with Jupyter notebooks through [Jupyter Ascending](https://github.com/RitschAlex/jupyter_ascending). This plugin allows you to edit and execute Jupyter notebooks using regular Python files while maintaining synchronization with the notebook format.
![](https://github.com/RitschAlex/jupyter_ascending.nvim/blob/main/demo.gif)

## Features

- Cell executions
- Automatic synchronization between `.sync.py` files and `.sync.ipynb` notebooks
- Start and stop the Jupyter notebook server from within Neovim
- Live server logs in a dedicated tab with automatic cleanup
- Execute individual cells or entire notebooks
- Restart Jupyter kernels
- Configurable auto-sync on save

## Prerequisites

- Neovim >= 0.10.0
- Python >= 3.10
- Jupyter Ascending package (`pip install git+https://github.com/RitschAlex/jupyter_ascending.git` or `pip install jupyter_ascending`)

> Note: The PyPI package [imbue-ai/jupyter_ascending](https://github.com/imbue-ai/jupyter_ascending) is unmaintained and only supports Jupyter Notebook v6. The GitHub installation recommended above, `RitschAlex/jupyter_ascending`, is a fork of `imbue-ai/jupyter_ascending` and supports Jupyter Notebook v7+, nbclassic and JupyterLab.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "RitschAlex/jupyter_ascending.nvim",
    config = function()
        require("jupyter_ascending").setup()
    end,
}
```

Using [vim.pack](https://neovim.io/doc/user/pack/#vim.pack)

```lua
vim.pack.add({
    "RitschAlex/jupyter_ascending.nvim"
})

require("jupyter_ascending").setup()

```

## Configuration

The plugin comes with sensible defaults but can be customized using the setup function:

```lua
require("jupyter_ascending").setup({
    -- Boolean to enable or disable the plugin (default: true)
    enabled = true,

    -- Path to Python executable (default: "python")
    python_executable = "python",
    
    -- Pattern to match sync files (default: ".sync.py")
    match_pattern = ".sync.py",
    
    -- Auto-sync on save (default: true)
    auto_write = true,
    
    -- Enable default keymaps (default: true)
    default_mappings = true,
    
    -- Command timeout in milliseconds (default: 10000)
    timeout = 10000,

    -- Keymap Prefix (default: "<space><space>")
    keymap_prefix = "<space><space>",

    -- Command Line Prefix (default: "Jupyter")
    command_prefix = "Jupyter",

    -- Command used to launch the notebook server, appended after "python -m"
    -- (default: { "jupyter", "notebook" })
    notebook_command = { "jupyter", "notebook" },
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

-- Start a Jupyter notebook server for the paired notebook of the current file
require("jupyter_ascending").start_server()

-- Stop the running Jupyter notebook server
require("jupyter_ascending").stop_server()
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

### 1. Create a Synced File Pair

Generate a `.sync.py` / `.sync.ipynb` file pair from the command line:

```bash
python -m jupyter_ascending.scripts.make_pair --base example
```

This creates two linked files:

| File | Purpose |
|------|---------|
| `example.sync.py` | Python source you edit in Neovim |
| `example.sync.ipynb` | Jupyter notebook kept in sync automatically |

### 2. Launch Jupyter

Start the notebook server and open the `.sync.ipynb` file.

**From Neovim** (with the `.sync.py` file open):

```vim
:JupyterStartServer
```

> - Launches the server for the paired `.sync.ipynb` and opens a dedicated tab with live server logs.
> - Stopping the server: `:JupyterStopServer`, closing the server tab, or quitting Neovim.
> - The paired notebook must exist (see step 1); otherwise an error with the `make_pair` command is shown.
> - Jupyter Ascending expects the server at `localhost:8888` — the plugin warns if the server ends up on a different port.

**Standard Jupyter (from a shell):**
```bash
python -m jupyter notebook example.sync.ipynb
```

**nbclassic** (legacy interface):
```bash
python -m jupyter nbclassic
```
> **Note:** When using `nbclassic`, the notebook must be accessible at  
> `localhost:8888/nbclassic/notebooks`. To launch it via `:JupyterStartServer`,  
> set `notebook_command = { "jupyter", "nbclassic" }` in your setup.

### 3. Edit in Neovim

Open `example.sync.py` in Neovim. The plugin ships **enabled by default** —
it can be toggled with:

```vim
:JupyterEnable
:JupyterDisable
```

### 4. Interact with the Notebook

Use keymaps or commands to control execution directly from Neovim.

**Keymaps** (active in `.sync.py` buffers):

| Key | Action |
|-----|--------|
| `<space><space>x` | Execute current cell |
| `<space><space>X` | Execute all cells |
| `<space><space>r` | Restart kernel |

**Commands:**

| Command | Effect |
|---------|--------|
| `:JupyterSync` | Sync `.py` -> `.ipynb` |
| `:JupyterExecute` | Execute current cell |
| `:JupyterExecuteAll` | Execute all cells |
| `:JupyterRestart` | Restart kernel |
| `:JupyterStartServer` | Start notebook server for the paired `.sync.ipynb` |
| `:JupyterStopServer` | Stop the running notebook server |
| `:JupyterEnable` | Enable the plugin |
| `:JupyterDisable` | Disable the plugin |

> **Auto‑sync:** When `auto_write = true` (the default), saving the Python file  
> automatically syncs changes to the notebook.

## Planned future enhancements

The following features are planned for `jupyter_ascending.nvim`:

- Add cell below
- Add cell above

In addition, while improving [Jupyter Ascending](https://github.com/RitschAlex/jupyter_ascending),
the following core features will be added:

- Run all cells above
- Run all cells below
- Hide output
- Clear outputs
- Clear all outputs

## Contributing

Contributions are welcome! Please feel free to open a Issue or submit a Pull Request.

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Jupyter Ascending](https://github.com/RitschAlex/jupyter_ascending) for the core functionality
- The Neovim community for inspiration and support
