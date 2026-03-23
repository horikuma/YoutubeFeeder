#!/usr/bin/env node

import { mkdtemp, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultRoots = ['docs', 'README.md'];
const fencePattern = /```mermaid[^\n]*\r?\n([\s\S]*?)```/g;

async function main() {
  const targets = process.argv.slice(2);
  const files = await resolveMarkdownFiles(targets.length > 0 ? targets : defaultRoots);
  const mermaidBlocks = await collectMermaidBlocks(files);

  if (mermaidBlocks.length === 0) {
    console.log('No mermaid blocks found.');
    return;
  }

  const tempDir = await mkdtemp(path.join(tmpdir(), 'youtubefeeder-mermaid-'));
  let failed = false;

  try {
    for (const block of mermaidBlocks) {
      try {
        await renderBlock(block, tempDir);
        console.log(`OK ${path.relative(repoRoot, block.file)}:${block.startLine}`);
      } catch (error) {
        failed = true;
        const message = error instanceof Error ? error.message : String(error);
        console.error(`NG ${path.relative(repoRoot, block.file)}:${block.startLine}`);
        console.error(message.trim());
      }
    }
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }

  if (failed) {
    process.exitCode = 1;
    return;
  }

  console.log(`Validated ${mermaidBlocks.length} mermaid block(s).`);
}

async function resolveMarkdownFiles(inputs) {
  const resolved = new Set();

  for (const input of inputs) {
    const absolute = path.resolve(repoRoot, input);
    await collectMarkdownPaths(absolute, resolved);
  }

  return [...resolved].sort();
}

async function collectMarkdownPaths(targetPath, resolved) {
  const info = await stat(targetPath);

  if (info.isDirectory()) {
    const entries = await readdir(targetPath, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === '.git' || entry.name === 'node_modules') {
        continue;
      }
      await collectMarkdownPaths(path.join(targetPath, entry.name), resolved);
    }
    return;
  }

  if (targetPath.endsWith('.md')) {
    resolved.add(targetPath);
  }
}

async function collectMermaidBlocks(files) {
  const blocks = [];

  for (const file of files) {
    const content = await readFile(file, 'utf8');
    let match;
    let index = 0;

    while ((match = fencePattern.exec(content)) !== null) {
      index += 1;
      blocks.push({
        file,
        index,
        source: match[1].trimEnd(),
        startLine: countLines(content.slice(0, match.index)) + 1
      });
    }
  }

  return blocks;
}

async function renderBlock(block, tempDir) {
  const stem = `${path.basename(block.file, '.md')}-${block.index}`;
  const inputPath = path.join(tempDir, `${stem}.mmd`);
  const outputPath = path.join(tempDir, `${stem}.svg`);
  await writeFile(inputPath, block.source, 'utf8');
  await runMmdc(inputPath, outputPath);
}

async function runMmdc(inputPath, outputPath) {
  const cliPath = path.join(repoRoot, 'node_modules', '.bin', process.platform === 'win32' ? 'mmdc.cmd' : 'mmdc');

  await new Promise((resolve, reject) => {
    const child = spawn(cliPath, ['--input', inputPath, '--output', outputPath], {
      cwd: repoRoot,
      env: process.env
    });

    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });

    child.on('error', (error) => {
      reject(new Error(`Failed to launch mmdc: ${error.message}. Run "npm install" in the repository root first.`));
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(stderr || `mmdc exited with code ${code}`));
    });
  });
}

function countLines(text) {
  if (text.length === 0) {
    return 0;
  }
  return text.split(/\r?\n/).length;
}

await main();
