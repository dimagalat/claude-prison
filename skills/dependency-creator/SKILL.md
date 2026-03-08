---
name: Generate Skill Dependencies
description: Generates a dependencies.json file for Claude Code skills based on a skill description.
---

# Generate Skill Dependencies

You can help users create a `dependencies.json` file for their Claude Code skills. 

Claude Prison uses a specialized dynamic dependency installer that reads from a `dependencies.json` file placed in the root of a skill's directory (e.g., `~/.claude/skills/my-awesome-skill/dependencies.json`). 

When a user asks you to create dependencies for a skill or asks how to install dependencies for a skill they are writing, you should generate a `dependencies.json` file for them.

## File Format

The `dependencies.json` file supports four optional fields. Here is an example of the structure:

```json
{
  "apk": [
    "chromium",
    "libnss3",
    "libfreetype6"
  ],
  "pip": [
    "playwright",
    "beautifulsoup4"
  ],
  "post_install": [
    "playwright install chromium"
  ],
  "env": {
    "PLAYWRIGHT_BROWSERS_PATH": "/usr/lib/chromium",
    "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD": "1"
  }
}
```

### Definitions:
1. **`apk` (Array of Strings):** A list of Alpine/Debian apt packages required by the skill. The Docker image uses Debian natively (via `apt-get`), so provide standard Debian/Ubuntu package names. (The key is named `apk` for historical reasons, but the installer uses `apt-get`).
2. **`pip` (Array of Strings):** A list of Python packages to install globally in the container using `pip`.
3. **`post_install` (Array of Strings):** A list of shell commands to execute after the `apk` and `pip` packages are installed. (e.g., initializing a database, downloading a model, or running a post-install script).
4. **`env` (Object of String:String mappings):** Environment variables that will be written to an `env.sh` file and loaded when the container starts.

## INSTRUCTIONS
If a user asks you to define dependencies for a new skill:
1. Determine what System packages, Python packages, and Environment variables the skill needs to function.
2. Formulate these requirements into the `dependencies.json` JSON schema.
3. Write or output the `dependencies.json` into the appropriate skill folder in `~/.claude/skills/<skill-name>/dependencies.json`.
