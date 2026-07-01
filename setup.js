#!/usr/bin/env node
// Idempotent Neovim config setup. Safe to run repeatedly.
// Copies nvim/ to the config directory Neovim reads on this platform.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const SRC = path.join(__dirname, 'nvim');

function log(msg) {
  console.log(`[nvim-conf] ${msg}`);
}

function configDir() {
  if (process.platform === 'win32') {
    return path.join(process.env.LOCALAPPDATA, 'nvim');
  }
  const xdg = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  return path.join(xdg, 'nvim');
}

const DEST = configDir();
fs.cpSync(SRC, DEST, { recursive: true, force: true });
log(`Copied nvim/ -> ${DEST}`);

try {
  execSync(process.platform === 'win32' ? 'where nvim' : 'command -v nvim', { stdio: 'ignore' });
} catch {
  log('Warning: nvim not found on PATH. Install Neovim 0.12+ (e.g. winget install Neovim.Neovim).');
}

log('Done. Launch nvim; lazy.nvim installs the plugins on first start.');
