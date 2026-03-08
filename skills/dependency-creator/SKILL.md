---
name: dependency-creator
description: Create dependencies.json for Claude Prison skills. Make sure to use this skill whenever the user is creating a new skill, asks about fixing environment/dependency errors, mentions missing CLI tools, or wants to install Python/Alpine/NPM packages. Help them generate the dependencies.json file to persist those tools across sessions.
---

# Dependency Creator Tool

A skill for generating `dependencies.json` files for Claude Prison environments.

At a high level, the process of documenting skill dependencies goes like this:
- **Phase 1: Interview & Assess**. Determine what System packages, Python packages, and Environment variables the skill needs to function. Ask the user questions!
- **Phase 2: Draft**. Formulate these requirements into a `dependencies.json` schema inside their skill directory.
- **Phase 3: Validate**. The user must rebuild the container using `make build-with-skills` to persist the tools. Help them test it post-build.

Your job when using this skill is to act as a collaborative partner, not just a mindless JSON generator. Ask what the user is trying to accomplish so you can proactively suggest necessary dependencies (like suggesting `playwright` always needs system browsers, or `ffmpeg` requires specific codecs).

## Anatomy of the Dependencies

Claude Prison uses a specialized dynamic dependency installer during the build phase (`make build-with-skills`). It ingests a `dependencies.json` file placed in the root of any skill's directory (e.g., `~/.claude/skills/webapp-testing/dependencies.json`). 

### File Format

The `dependencies.json` file supports four optional fields. Here is an example of the maximum structure:

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

### Definitions & Guidelines:

Please explain these rules to the user if they ask for things that violate them:

1. **`apk` (Array of Strings):** 
   - A list of system packages.
   - **CRITICAL NOTE:** Even though the key is named `apk` for historical backwards-compatibility with Alpine, the modern Claude Prison Docker image natively uses **Debian** (`apt-get`). You MUST provide standard Debian/Ubuntu package names, not Alpine versions. Explain this to the user if they provide an Alpine-exclusive package name.
2. **`pip` (Array of Strings):** 
   - A list of Python packages.
   - *Why this matters*: These run under a system-wide `pip install --break-system-packages` context during the container build, immediately available to Claude at runtime globally.
3. **`post_install` (Array of Strings):** 
   - A list of shell commands to execute *after* the `apk` and `pip` packages are installed. 
   - Use this for initializing datasets, downloading heavy binary models outside of pip, or compiling Native bindings.
4. **`env` (Object of String:String mappings):** 
   - Environment variables that will be written to `/etc/profile.d/skills-env.sh` and sourced when the container starts.

## Writing Style & Approach

Try to explain to the model (or user) **why** things are important in lieu of heavy-handed musty directives. Use theory of mind and try to make the skill general and not super-narrow.

For instance, today's LLMs are smart — they have good theory of mind on how to resolve missing packages. If the user complains that "Claude can't find ffmpeg", you should immediately realize it's a missing dependency and jump into this skill's workflow to capture intent and output the fix!

## The Iteration Loop

1. Write the `dependencies.json` file into the appropriate skill folder: `~/.claude/skills/<skill-name>/dependencies.json`. If you don't know the exact path, ask the user or search their workspace for existing skill folders.
2. Instruct the user to run `make build-with-skills` on their host machine so the Docker container ingests the dependencies.
3. If they encounter build errors during the apt or pip phase, read the logs, adjust the package names (assure they are Debian-compatible), and update the JSON. Repeat.
