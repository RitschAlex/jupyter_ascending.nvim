local M = {}

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

M.config = {
	python_executable = "python",
	match_pattern = ".sync.py",
	auto_write = true,
	default_mappings = true,
	timeout = 3000,
}

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Execute system commands and handle their output
---@param cmd string[] Command and arguments as a table
---@param opts? table Additional options for vim.system
---@return vim.SystemObj
local function execute_command(cmd, opts)
	opts = opts or {}

	local system_opts = {
		text = true,
		timeout = M.config.timeout,
		stdout = function(_, data)
			if data and data ~= "" then
				if not data:match("^Logging Jupyter Ascending") then
					vim.schedule(function()
						vim.notify("[JupyterAscending] " .. data:gsub("\n$", ""), vim.log.levels.INFO)
					end)
				end
			end
		end,
		stderr = function(_, data)
			if data and data ~= "" then
				vim.schedule(function()
					vim.notify("[JupyterAscending] " .. data, vim.log.levels.ERROR)
				end)
			end
		end,
	}

	--Merge with provided options
	system_opts = vim.tbl_deep_extend("force", system_opts, opts)

	-- Start the command async
	local system_obj = vim.system(cmd, system_opts, function(obj)
		if obj.code ~= 0 then
			vim.schedule(function()
				vim.notify(
					string.format(
						"[JupyterAscending] Command failed with code %d: %s",
						obj.code,
						table.concat(cmd, " "),
						vim.log.levels.ERROR
					)
				)
			end)
		end
	end)
	return system_obj
end

-- Return current line for execute command
---@return integer
local function get_current_line()
	return vim.api.nvim_win_get_cursor(0)[1]
end

-- Check if current file matches the jupyter notebook pattern
---@return string|false filename if matches, false otherwise
local function is_sync_py_file()
	local file_name = vim.fn.expand("%:p")
	if string.find(file_name, M.config.match_pattern) then
		return file_name
	end
	vim.schedule(function()
		vim.notify("[JupyterAscending] File does not match pattern", vim.log.levels.WARN)
	end)
	return false
end

-------------------------------------------------------------------------------
-- Core Functionality
-------------------------------------------------------------------------------

-- Sync the current file with its corresponding Jupyter notebook
function M.sync()
	local file_name = vim.fn.expand("%:p")
	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.sync",
		"--filename",
		file_name,
	})
	vim.notify("Syncing Jupyter Notebook ...", vim.log.levels.INFO)
end

-- Execute the current cell in Jupyter
function M.execute()
	local file_name = vim.fn.expand("%:p")
	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.execute",
		"--filename",
		file_name,
		"--linenumber",
		tostring(get_current_line()),
	})

	vim.notify("Executing current cell ...", vim.log.levels.INFO)
end

-- Execute all cells in the current file
function M.execute_all()
	local file_name = vim.fn.expand("%:p")
	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.execute_all",
		"--filename",
		file_name,
	})
	vim.notify("Executing all cells ...", vim.log.levels.INFO)
end

-- Restart the Jupyter kernel
function M.restart()
	local file_name = vim.fn.expand("%:p")
	if not file_name then
		return
	end

	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.restart",
		"--filename",
		file_name,
	})
	vim.notify("Restarting the kernel ...", vim.log.levels.INFO)
end

-------------------------------------------------------------------------------
-- Setup Function
-------------------------------------------------------------------------------

---@param opts table? Optional configuration table to override defaults
function M.setup(opts)
	-- Merge user config with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create autocommand group for the plugin
	local group = vim.api.nvim_create_augroup("JupyterAscending", { clear = true })

	-- Set up autocommand if auto_write is true
	if M.config.auto_write then
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = "*.sync.py",
			group = group,
			callback = function()
				require("jupyter_ascending").sync()
			end,
			desc = "Sync Jupyter notebook on save",
		})
	end

	-- Set up default keymaps if enabled
	if M.config.default_mappings then
		vim.api.nvim_create_autocmd("BufRead", {
			pattern = "*.sync.py",
			group = group,
			callback = function()
				local keymap_opts = {
					noremap = true,
					silent = true,
				}

				-- Execute current cell
				vim.keymap.set("n", "<space><space>x", function()
					M.execute()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Execute current Jupyter cell" }))

				-- Execute all cells
				vim.keymap.set("n", "<space><space>X", function()
					M.execute_all()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Execute all Jupyter cells" }))

				-- Restart kernel
				vim.keymap.set("n", "<space><space>r", function()
					M.restart()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Restart Jupyter kernel" }))
			end,
			desc = "Set Up Jupyter Ascending keymaps for *.sync.py files",
		})
	end
end

return M
