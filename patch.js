const fs = require('fs');
const file = '/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js';

if (!fs.existsSync(file)) {
  console.error(`File not found: ${file}`);
  process.exit(1);
}

let content = fs.readFileSync(file, 'utf8');

const MANUAL_URL = "https://platform.claude.com/oauth/code/callback";

// 1. Specific Redirect Force for V_1
content = content.replace(/j\.searchParams\.append\("redirect_uri",[a-zA-Z0-9$]+\?[a-zA-Z0-9$]+\(\)\.MANUAL_REDIRECT_URL:`http:\/\/localhost:\$\{[a-zA-Z0-9$]+\}\/callback`\)/g,
  `j.searchParams.set("redirect_uri", "${MANUAL_URL}")`);

// 2. Specific Redirect Force for r$8
content = content.replace(/redirect_uri:[a-zA-Z0-9$]+\?[a-zA-Z0-9$]+\(\)\.MANUAL_REDIRECT_URL:`http:\/\/localhost:\$\{[a-zA-Z0-9$]+\}\/callback`/g,
  `redirect_uri: "${MANUAL_URL}"`);

// 3. Force exchange function parameter z to true
content = content.replace(/async function r\$8\(([a-zA-Z0-9$]+),([a-zA-Z0-9$]+),([a-zA-Z0-9$]+),([a-zA-Z0-9$]+),([a-zA-Z0-9$]+)=!1/g,
  'async function r$8($1,$2,$3,$4,$5=!0');

// 4. Scope Purge
content = content.replace(/"user:sessions:claude_code"/g, '"user:profile"');
content = content.replace(/"user:mcp_servers"/g, '"user:profile"');

// 5. Deep URL Capture to file
content = content.replace(/j\.searchParams\.append\("state",q\)/g,
  'j.searchParams.append("state",q),import("node:fs").then(m=>m.writeFileSync("/workspace/login_url.txt",j.toString()))');

fs.writeFileSync(file, content);
console.log('Successfully applied TARGETED REDIRECT OVERRIDE to cli.js');
