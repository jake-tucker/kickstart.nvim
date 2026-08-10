vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/antoinemadec/FixCursorHold.nvim',
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/nsidorenco/neotest-vstest',
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
}

local dap = require 'dap'
local dapui = require 'dapui'

local uname = vim.uv.os_uname()
local is_macos_arm64 = uname.sysname == 'Darwin' and uname.machine == 'arm64'
local data_dir = vim.fn.stdpath 'data'
-- TODO: Remove this platform-specific installer once Mason provides netcoredbg 3.2.0+ for macOS arm64.
local netcoredbg = is_macos_arm64 and vim.fs.joinpath(data_dir, 'netcoredbg', 'netcoredbg') or nil

if is_macos_arm64 and vim.fn.executable(netcoredbg) == 0 then
  local version = '3.2.0-1092'
  local checksum = 'f4fa33b3ff874910cc184b4bb3b9c56d0abdf5c6521cee0b144d7c6e4a6e59ea'
  local archive = vim.fn.tempname() .. '.zip'
  local url = ('https://github.com/Samsung/netcoredbg/releases/download/%s/netcoredbg-osx-arm64.zip'):format(version)

  local function notify(message, level)
    vim.schedule(function() vim.notify(message, level, { title = 'netcoredbg' }) end)
  end

  local function fail(stage, result)
    vim.uv.fs_unlink(archive)
    notify(('Installation failed during %s: %s'):format(stage, result.stderr or 'unknown error'), vim.log.levels.ERROR)
  end

  notify('Installing the macOS arm64 debugger...', vim.log.levels.INFO)
  vim.system({ 'curl', '-fL', '--retry', '3', url, '-o', archive }, { text = true }, function(download)
    if download.code ~= 0 then return fail('download', download) end

    vim.system({ 'shasum', '-a', '256', archive }, { text = true }, function(hash)
      if hash.code ~= 0 then return fail('checksum', hash) end
      if not hash.stdout or hash.stdout:match '^%x+' ~= checksum then
        return fail('checksum', { stderr = 'downloaded archive did not match the expected SHA-256' })
      end

      vim.system({ 'unzip', '-oq', archive, 'netcoredbg/*', '-d', data_dir }, { text = true }, function(unzip)
        if unzip.code ~= 0 then return fail('extraction', unzip) end

        vim.system({ 'chmod', '+x', netcoredbg }, { text = true }, function(chmod)
          vim.uv.fs_unlink(archive)
          if chmod.code ~= 0 then return fail('permissions', chmod) end
          notify('Installation complete.', vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

dap.adapters.netcoredbg = function(callback)
  callback {
    type = 'executable',
    command = netcoredbg or vim.fn.exepath 'netcoredbg',
    args = { '--interpreter=vscode' },
  }
end

dapui.setup {}
dap.listeners.before.attach.dotnet_dapui = function() dapui.open() end
dap.listeners.before.launch.dotnet_dapui = function() dapui.open() end
dap.listeners.before.event_terminated.dotnet_dapui = function() dapui.close() end
dap.listeners.before.event_exited.dotnet_dapui = function() dapui.close() end

local neotest = require 'neotest'
neotest.setup {
  adapters = {
    require 'neotest-vstest',
  },
}

vim.keymap.set('n', '<leader>tn', function() neotest.run.run() end, { desc = '[T]est [N]earest' })
vim.keymap.set('n', '<leader>tf', function() neotest.run.run(vim.api.nvim_buf_get_name(0)) end, { desc = '[T]est [F]ile' })
vim.keymap.set('n', '<leader>ta', function() neotest.run.run { suite = true } end, { desc = '[T]est [A]ll' })
vim.keymap.set('n', '<leader>tl', function() neotest.run.run_last() end, { desc = '[T]est [L]ast' })
vim.keymap.set('n', '<leader>td', function() neotest.run.run { strategy = 'dap' } end, { desc = '[T]est [D]ebug nearest' })
vim.keymap.set('n', '<leader>to', function() neotest.output.open { enter = true } end, { desc = '[T]est [O]utput' })
vim.keymap.set('n', '<leader>tp', function() neotest.output_panel.toggle() end, { desc = '[T]est output [P]anel' })
vim.keymap.set('n', '<leader>ts', function() neotest.summary.toggle() end, { desc = '[T]est [S]ummary' })
vim.keymap.set('n', '<leader>tx', function() neotest.run.stop { interactive = true } end, { desc = '[T]est stop' })
vim.keymap.set('n', '<leader>tW', function() neotest.watch.toggle(vim.api.nvim_buf_get_name(0)) end, { desc = '[T]est [W]atch file' })

vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = 'Debug: Continue' })
vim.keymap.set('n', '<F10>', function() dap.step_over() end, { desc = 'Debug: Step over' })
vim.keymap.set('n', '<F11>', function() dap.step_into() end, { desc = 'Debug: Step into' })
vim.keymap.set('n', '<F12>', function() dap.step_out() end, { desc = 'Debug: Step out' })
vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = '[D]ebug [B]reakpoint' })
vim.keymap.set('n', '<leader>dB', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = '[D]ebug conditional [B]reakpoint' })
vim.keymap.set('n', '<leader>du', function() dapui.toggle() end, { desc = '[D]ebug [U]I' })
vim.keymap.set('n', '<leader>dx', function() dap.terminate() end, { desc = '[D]ebug terminate' })
vim.keymap.set({ 'n', 'v' }, '<leader>de', function() dapui.eval() end, { desc = '[D]ebug [E]valuate' })
