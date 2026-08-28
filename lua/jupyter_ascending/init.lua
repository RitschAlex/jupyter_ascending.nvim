local M = {}

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

local defaults = {
	enabled = true,
	python_executable = "python",
	match_pattern = ".sync.py",
	auto_write = true,
	default_mappings = true,
	timeout = 10000,
	keymap_prefix = "<space><space>",
	command_prefix = "Jupyter",
	notebook_command = { "jupyter", "notebook" },
}

M.config = vim.deepcopy(defaults)

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

-- Return paired .ipynb notebook file
--- @return string|nil
local function get_paired_notebook_file()
	local py_file = is_sync_py_file()
	if not py_file then
		return nil
	end

	local ipynb_file = py_file:gsub("%.py$", ".ipynb")
	if not vim.uv.fs_stat(ipynb_file) then
		vim.schedule(function()
			vim.notify(
				"[JupyterAscending] Paired notebook file not found: "
					.. ipynb_file
					.. ". Create it with: python -m jupyter_ascending.scripts.make_pair --base"
					.. vim.fn.fnamemodify(py_file, ":t:r:r"),
				vim.log.levels.ERROR
			)
		end)
		return nil
	end

	return ipynb_file
end

-- Build the notebook server command from config
---@param ipynb_file string Path to the paired notebook
---@return string[]
local function build_server_command(ipynb_file)
	local cmd = vim.list_extend({ M.config.python_executable, "-m" }, vim.deepcopy(M.config.notebook_command))
	table.insert(cmd, ipynb_file)
	return cmd
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
		tostring(line),
	}, nil, "Executed cell at line: " .. tostring(line) .. " successfully")

	vim.api.nvim_echo(
		{ { "[JupyterAscending] Executing current cell at line: " .. tostring(line), "Normal" } },
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

	vim.api.nvim_echo({ { "[JupyterAscending] Executing all cells", "Normal" } }, false, {})
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

-- Start a jupyter notebook server for the paired notebook of the current file
function M.start_server()
	if not check_enabled() then
		return
	end

	local ipynb_file = get_paired_notebook_file()
	if not ipynb_file then
		return
	end

	if M._server then
		vim.notify(
			"[JupyterAscending] Notebook server is already running for " .. M._server.notebook,
			vim.log.levels.INFO
		)
		return
	end

	-- vim.cmd("botright new")
	-- local bufnr = vim.api.nvim_get_current_buf()
	-- vim.api.nvim_buf_set_name(bufnr, "jupyter-server://" .. vim.fn.fnamemodify(ipynb_file, ":t"))
	local bufname = "jupyter-server://" .. vim.fs.basename(ipynb_file)
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(bufnr, bufname)

	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].buftype = "nofile"

	vim.api.nvim_open_win(bufnr, true, {
		split = "below",
		win = -1,
	})

	local notified = false
	local job_id = vim.fn.jobstart(build_server_command(ipynb_file), {
		term = true,
		cwd = vim.fs.dirname(ipynb_file),
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				local port = line:match("http://localhost:(%d+)") or line:match("http://127%.0%.0%.1:(%d+)")
				if port and not notified then
					notified = true
					vim.schedule(function()
						vim.notify(
							string.format("[JupyterAscending] Notebook server started at http://localhost:%s", port),
							vim.log.levels.INFO
						)
						if tonumber(port) ~= 8888 then
							vim.notify(
								string.format(
									"[JupyterAscending] Note: The server is running on a non-default port (%s). You may need to adjust your Jupyter configuration accordingly.",
									port
								),
								vim.log.levels.WARN
							)
						end
					end)
					break
				end
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				if M._server and M._server.job_id == job_id then
					M._server = nil
				end
				if exit_code == 0 or exit_code == 15 or exit_code == 130 or exit_code == 143 then
					vim.notify("[JupyterAscending] Notebook server stopped", vim.log.levels.INFO)
				else
					vim.notify(
						string.format("[JupyterAscending] Notebook server exited with code %d", exit_code),
						vim.log.levels.ERROR
					)
				end
			end)
		end,
	})

	if job_id <= 0 then
		vim.api.nvim_buf_delete(bufnr, { force = true })
		if job_id == -1 then
			vim.notify(
				"[JupyterAscending] Failed to start notebook server: '"
					.. M.config.python_executable
					.. "' is not executable.",
				vim.log.levels.ERROR
			)
		else
			vim.notify("[JupyterAscending] Failed to start notebook server process", vim.log.levels.ERROR)
		end
		return
	end

	M._server = { job_id = job_id, bufnr = bufnr, notebook = ipynb_file }
	vim.api.nvim_echo({ { "[JupyterAscending] Starting notebook server ...", "Normal" } }, false, {})
end

-- Stop the running jupyter server
function M.stop_server()
	if not M._server then
		vim.notify("[JupyterAscending] No running Jupyter server to stop", vim.log.levels.INFO)
		return
	end

	if vim.fn.jobstop(M._server.job_id) == 0 then
		-- Job was already dead and on_exit may not fire; clean up defensively
		M._server = nil
	end
end

-------------------------------------------------------------------------------
-- Setup Function
-------------------------------------------------------------------------------

M._server = nil
M._initialized_buffers = M._initialized_buffers or {}

---@param bufnr integer Buffer number to set up keymaps for
local function setup_keymaps_for_buffer(bufnr)
	if not M.config.default_mappings then
		return
	end

	-- Track initialized buffers
	if M._initialized_buffers[bufnr] then
		return
	end
	M._initialized_buffers[bufnr] = true

	local keymap_prefix = M.config.keymap_prefix
	local keymap_opts = {
		noremap = true,
		silent = true,
		buffer = bufnr,
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
end

--
local setup_autocmds
local clear_autocmds

local function register_commands()
	-- Register commands with prefix
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

	vim.api.nvim_create_user_command(cmd_prefix .. "StartServer", function()
		M.start_server()
	end, { desc = "Start Jupyter notebook server for the current notebook" })

	vim.api.nvim_create_user_command(cmd_prefix .. "StopServer", function()
		M.stop_server()
	end, { desc = "Stop the running Jupyter notebook server" })

	vim.api.nvim_create_user_command(cmd_prefix .. "Enable", function()
		if M.config.enabled then
			vim.notify("[JupyterAscending] Plugin is already enabled", vim.log.levels.INFO)
			return
		end

		M.config.enabled = true
		setup_autocmds()

		vim.api.nvim_exec_autocmds("BufEnter", {
			buffer = vim.api.nvim_get_current_buf(),
		})

		vim.notify("[JupyterAscending] Plugin enabled", vim.log.levels.INFO)
	end, { desc = "Enable Jupyter Ascending plugin" })

	vim.api.nvim_create_user_command(cmd_prefix .. "Disable", function()
		if not M.config.enabled then
			vim.notify("[JupyterAscending] Plugin is already disabled", vim.log.levels.INFO)
			return
		end
		M.config.enabled = false

		if M.config.default_mappings then
			local keymap_prefix = M.config.keymap_prefix
			for buf_nr, initialized in pairs(M._initialized_buffers) do
				if initialized and vim.api.nvim_buf_is_valid(buf_nr) then
					pcall(vim.api.nvim_buf_del_keymap, buf_nr, "n", keymap_prefix .. "x")
					pcall(vim.api.nvim_buf_del_keymap, buf_nr, "n", keymap_prefix .. "X")
					pcall(vim.api.nvim_buf_del_keymap, buf_nr, "n", keymap_prefix .. "r")
				end
			end
		end

		clear_autocmds()

		vim.notify("[JupyterAscending] Plugin disabled", vim.log.levels.INFO)
	end, { desc = "Disable Jupyter Ascending plugin" })
end

local function unregister_commands()
	-- Unregister commands with prefix
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "Sync")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "Execute")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "ExecuteAll")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "Restart")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "Disable")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "StartServer")
	pcall(vim.api.nvim_del_user_command, M.config.command_prefix .. "StopServer")
end

setup_autocmds = function()
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

	if M.config.default_mappings then
		vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter", "BufNewFile" }, {
			pattern = "*" .. M.config.match_pattern,
			group = group,
			callback = function(args)
				setup_keymaps_for_buffer(args.buf)
			end,
			desc = "Set Up Jupyter Ascending keymaps for *.sync.py files",
		})
	end

	-- Register commands with prefix
	register_commands()
end

clear_autocmds = function()
	-- Clear existing JupyterAscending augroup
	pcall(vim.api.nvim_del_augroup_by_name, "JupyterAscending")

	-- Reset initialized buffers tracking
	M._initialized_buffers = {}

	-- Unregister commands with prefix
	unregister_commands()
end

---@param opts table? Optional configuration table to override defaults
function M.setup(opts)
	-- Merge user config with defaults
	M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

	-- Clear autocmds if exist
	clear_autocmds()

	-- Run setup only if current buffer matches the match_pattern and enabled == true
	if not M.config.enabled then
		return
	end

	setup_autocmds()

	-- If in a matching buffer, trigger BufEnter once
	vim.api.nvim_exec_autocmds({ "BufReadPost", "BufEnter", "BufNewFile" }, {
		buffer = vim.api.nvim_get_current_buf(),
	})
end

return M
