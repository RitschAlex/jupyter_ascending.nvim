local M = {}

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

M.config = {
	enabled = false,
	python_executable = "python",
	match_pattern = ".sync.py",
	auto_write = true,
	default_mappings = true,
	timeout = 10000,
	keymap_prefix = "<space><space>",
	command_prefix = "Jupyter",
}

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Execute system commands and handle their output
---@param cmd string[] Command and arguments as a table
---@param opts? table Additional options for vim.system
---@return vim.SystemObj
local function execute_command(cmd, opts, success_msg)
	opts = opts or {}

	local system_opts = {
		text = true,
		timeout = M.config.timeout,
		stdout = function(_, data)
			if data and data ~= "" then
				if not data:match("^Logging Jupyter Ascending") then
					vim.schedule(function()
						vim.api.nvim_echo({ { "[JupyterAscending] " .. data:gsub("\n$", ""), "Normal" } }, false, {})
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
						"[JupyterAscending] Command failed with (code %d): %s",
						obj.code,
						table.concat(cmd, " ")
					),
					vim.log.levels.ERROR
				)
			end)
		elseif success_msg then
			vim.schedule(function()
				vim.api.nvim_echo({ { "[JupyterAscending] " .. success_msg, "Normal" } }, false, {})
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

-- Check if plugin is enabled
--- @return boolean
local function check_enabled()
	if not M.config.enabled then
		vim.notify("[JupyterAscending] Plugin is currently disabled", vim.log.levels.WARN)
		return false
	end
	return true
end

-------------------------------------------------------------------------------
-- Core Functionality
-------------------------------------------------------------------------------

-- Sync the current file with its corresponding Jupyter notebook
function M.sync()
	if not check_enabled() then
		return
	end

	local file_name = vim.fn.expand("%:p")
	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.sync",
		"--filename",
		file_name,
	}, nil, "Synced with jupyter successfully")

	vim.api.nvim_echo({ { "[JupyterAscending] Syncing Jupyter Notebook ...", "Normal" } }, false, {})
end

-- Execute the current cell in Jupyter
function M.execute()
	if not check_enabled() then
		return
	end

	local file_name = vim.fn.expand("%:p")
	local line = get_current_line()

	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.execute",
		"--filename",
		file_name,
		"--linenumber",
		tostring(get_current_line()),
	}, nil, "Executed cell at line: " .. tostring(line) .. " successfully")

	vim.api.nvim_echo(
		{ { "[JupyterAscending] Executing current cell under in line: " .. tostring(get_current_line()), "Normal" } },
		false,
		{}
	)
end

-- Execute all cells in the current file
function M.execute_all()
	if not check_enabled() then
		return
	end

	local file_name = vim.fn.expand("%:p")
	execute_command({
		M.config.python_executable,
		"-m",
		"jupyter_ascending.requests.execute_all",
		"--filename",
		file_name,
	}, nil, "Executed all cells successfully")

	vim.api.nvim_echo({ { "[JupyterAscending] Executing all cells ", "Normal" } }, false, {})
end

-- Restart the Jupyter kernel
function M.restart()
	if not check_enabled() then
		return
	end

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
	}, nil, "Kernel restarted successfully")

	vim.api.nvim_echo({ { "[JupyterAscending] Restarting the kernel ...", "Normal" } }, false, {})
end

-------------------------------------------------------------------------------
-- Setup Function
-------------------------------------------------------------------------------

local function setup_autocmds()
	-- Create autocommand group for the plugin
	local group = vim.api.nvim_create_augroup("JupyterAscending", { clear = true })

	-- Set up autocommand if auto_write is true
	if M.config.auto_write then
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = "*" .. M.config.match_pattern,
			group = group,
			callback = function()
				vim.schedule(function()
					M.sync()
				end)
			end,
			desc = "Sync Jupyter notebook on save",
		})
	end

	-- Set up default keymaps if enabled
	if M.config.default_mappings then
		local keymap_prefix = M.config.keymap_prefix
		vim.api.nvim_create_autocmd("BufRead", {
			pattern = "*" .. M.config.match_pattern,
			group = group,
			callback = function()
				local keymap_opts = {
					noremap = true,
					silent = true,
				}

				-- Execute current cell
				vim.keymap.set("n", keymap_prefix .. "x", function()
					M.execute()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Execute current Jupyter cell" }))

				-- Execute all cells
				vim.keymap.set("n", keymap_prefix .. "X", function()
					M.execute_all()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Execute all Jupyter cells" }))

				-- Restart kernel
				vim.keymap.set("n", keymap_prefix .. "r", function()
					M.restart()
				end, vim.tbl_extend("force", keymap_opts, { desc = "Restart Jupyter kernel" }))
			end,
			desc = "Set Up Jupyter Ascending keymaps for *.sync.py files",
		})
	end
	vim.notify("[JupyterAscending] Plugin is active", vim.log.levels.INFO)
end

local function clear_autocmds()
	pcall(vim.api.nvim_del_augroup_by_name, "JupyterAscending")
end

---@param opts table? Optional configuration table to override defaults
function M.setup(opts)
	-- Merge user config with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if M.config.enabled then
		setup_autocmds()
	else
		clear_autocmds()
	end
end

-- Register commands
local cmd_prefix = M.config.command_prefix

vim.api.nvim_create_user_command(cmd_prefix .. "Sync", function()
	M.sync()
end, { desc = "Sync current file with Jupyter notebook" })

vim.api.nvim_create_user_command(cmd_prefix .. "Execute", function()
	M.execute()
end, { desc = "Execute current Jupyter cell" })

vim.api.nvim_create_user_command(cmd_prefix .. "ExecuteAll", function()
	M.execute_all()
end, { desc = "Execute all Jupyter cells" })

vim.api.nvim_create_user_command(cmd_prefix .. "Restart", function()
	M.restart()
end, { desc = "Restart Jupyter kernel" })

vim.api.nvim_create_user_command(cmd_prefix .. "Enable", function()
	if M.config.enabled then
		vim.notify("[JupyterAscending] Plugin is already enabled", vim.log.levels.INFO)
		return
	end
	M.config.enabled = true
	setup_autocmds()
	vim.notify("[JupyterAscending] Plugin enabled", vim.log.levels.INFO)
end, { desc = "Enable Jupyter Ascending plugin" })

vim.api.nvim_create_user_command(cmd_prefix .. "Disable", function()
	if not M.config.enable then
		vim.notify("[JupyterAscending] Plugin is already disabled", vim.log.levels.INFO)
		return
	end
	M.config.enabled = false
	clear_autocmds()
	vim.notify("[JupyterAscending] Plugin disabled", vim.log.levels.INFO)
end, { desc = "Disable Jupyter Ascending plugin" })

return M
