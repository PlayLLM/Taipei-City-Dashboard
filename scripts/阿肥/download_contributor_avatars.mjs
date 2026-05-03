#!/usr/bin/env node

import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(fileURLToPath(new URL("..", import.meta.url)));
const outputDir = resolve(rootDir, "data", "contributors");

const contributors = [
  {
    userId: "tinghedy",
    profileUrl: "https://github.com/Tinghedy",
    avatarUrl: "https://github.com/Tinghedy.png?size=512",
  },
  {
    userId: "ncchen99",
    profileUrl: "https://github.com/ncchen99",
    avatarUrl: "https://github.com/ncchen99.png?size=512",
  },
  {
    userId: "ichenjt",
    profileUrl: "https://github.com/ichenjt",
    avatarUrl: "https://github.com/ichenjt.png?size=512",
  },
  {
    userId: "yenslife",
    profileUrl: "https://github.com/yenslife",
    avatarUrl: "https://github.com/yenslife.png?size=512",
  },
];

async function downloadAvatar({ userId, avatarUrl }) {
  const response = await fetch(avatarUrl);
  if (!response.ok) {
    throw new Error(`Failed to download ${userId}: ${response.status} ${response.statusText}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const filePath = resolve(outputDir, `${userId}.png`);
  await writeFile(filePath, buffer);
  return filePath;
}

async function main() {
  await mkdir(outputDir, { recursive: true });

  for (const contributor of contributors) {
    const filePath = await downloadAvatar(contributor);
    console.log(`Downloaded: ${contributor.userId} -> ${filePath}`);
  }

  const manifest = contributors.map((item) => ({
    user_id: item.userId,
    profile_url: item.profileUrl,
    avatar_url: item.avatarUrl,
    avatar_file: `data/contributors/${item.userId}.png`,
  }));

  await writeFile(
    resolve(outputDir, "manifest.json"),
    `${JSON.stringify(manifest, null, 2)}\n`,
    "utf8",
  );

  console.log(`Manifest written: ${resolve(outputDir, "manifest.json")}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
