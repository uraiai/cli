# Urai CLI

A unified command-line tool for building, testing, and deploying TypeScript tools for Urai Voice.

## Installation

### Using Pre-built Binaries

#### Linux (x86_64)
```bash
curl -L https://github.com/uraiai/cli/releases/latest/download/urai-linux-x86_64 -o urai
chmod +x urai
sudo mv urai /usr/local/bin/
```

#### Linux (ARM64/aarch64)
```bash
curl -L https://github.com/uraiai/cli/releases/latest/download/urai-linux-aarch64 -o urai
chmod +x urai
sudo mv urai /usr/local/bin/
```

#### Using Docker (All Platforms including macOS)

For macOS users or anyone preferring containerized environments, use our Docker images hosted on GitHub Container Registry:

```bash
# Pull the image (automatically selects the right architecture)
docker pull ghcr.io/uraiai/cli:latest

# Run interactively
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/uraiai/cli:latest urai --help

# Create an alias for convenience
alias urai='docker run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/uraiai/cli:latest urai'

# Now use it like a native command
urai js list-tools ./my-tools/tidycal.ts
```

The Docker image is based on Debian 13 and includes all necessary dependencies. It's perfect for:
- **macOS users** (Apple Silicon and Intel)
- **Development environments**
- **CI/CD pipelines**
- **Consistent cross-platform execution**

### Building from Source

Build the CLI from the workspace root:

```bash
cargo build --release -p urai-cli
```

The binary will be available at `target/release/urai`.

Optionally, install it globally:

```bash
cargo install --path urai-cli
```

## Configuration

The CLI supports configuration through multiple sources (in order of priority):

1. **Command-line arguments** (highest priority)
2. **Environment variables**
3. **Local config file** (`.urai.toml` in current directory)
4. **Global config file** (`~/.config/urai/config.toml`)

Configuration can be organized into profiles. The active profile can be selected by setting the `URAI_PROFILE` environment variable. If not set, it defaults to `default`.

### Environment Variables

You can override any configuration setting using environment variables.

```bash
# Select a configuration profile (defaults to "default")
export URAI_PROFILE="staging"

# Override settings for the selected profile
export URAI_API_URL="https://your-urai-server.com"
export URAI_API_KEY="your-api-key-here"
export URAI_ORG_ID="your-organization-id"
```

### Config File Format

Create `.urai.toml` (local) or `~/.config/urai/config.toml` (global) with one or more profiles.

```toml
# Default profile, used if URAI_PROFILE is not set
[profile.default]
api_url = "https://api.urai.io"
api_key = "key_for_default_profile"
org_id = "org_default"

# Staging profile, activated with `export URAI_PROFILE=staging`
[profile.staging]
api_url = "https://staging.api.urai.io"
api_key = "key_for_staging_profile"
org_id = "org_staging"
```

The CLI will also read configuration from the old format (without profiles) and treat it as the `default` profile for backward compatibility.

## Usage

The CLI has four main command groups:

### 1. Local Testing (`urai js`)

Test your TypeScript tools locally before deploying them.

#### List Tool Declarations

```bash
urai js list-tools <script.ts>
```

**Example:**
```bash
urai js list-tools ./my-tools/tidycal.ts
```

**Options:**
- `-d, --work-dir <DIR>` - Working directory (defaults to script's directory)
- `-s, --secrets <JSON>` - Secrets as JSON string
- `--secrets-file <FILE>` - Load secrets from file
- `-v, --vars <JSON>` - Variables as JSON string
- `--vars-file <FILE>` - Load variables from file

#### Call a Tool

```bash
urai js call <script.ts> <function-name> [arg1=value1] [arg2:=value2]...
```

Arguments can be passed as `key=value` for strings or `key:=value` for other JSON types (numbers, booleans, objects, arrays).

**Examples:**
```bash
# Simple greeting with a string argument
urai js call ./my-tools/tidycal.ts greet name=Alice

# Book appointment with multiple arguments and secrets
urai js call ./my-tools/tidycal.ts book_slot date=2024-01-15 time=14:00 --secrets-file ./secrets.json

# Using non-string arguments (numbers)
urai js call ./my-tools/calculator.ts add a:=25 b:=17.5

# Passing a JSON object
urai js call ./my-tools/user.ts create_user user:='{"name": "Bob", "is_admin": false}'
```


#### Generate Schema

Automatically generate a schema JSON file from your TypeScript tool declarations:

```bash
urai js generate-schema <script.ts> -o <output.json>
```

**Example:**
```bash
urai js generate-schema ./my-tools/tidycal.ts -o tidycal-schema.json
```

This extracts the tool declarations from your TypeScript file and saves them to a JSON file that can be used with `urai tool create`. The default output filename is `schema.json`.

**Options:**
- `-o, --output <FILE>` - Output file path (default: schema.json)
- `-d, --work-dir <DIR>` - Working directory
- All secret/variable options supported

#### Generate Declarations

Automatically generate TypeScript declarations from your tool source file using tree-sitter. This eliminates the need to manually write and maintain declaration files separately from your JSDoc comments.

```bash
urai js generate-declarations <tool-file.ts> -o <declarations.ts>
```

**Example:**
```bash
urai js generate-declarations ./my-tools/tidycal_tool.ts -o ./my-tools/declarations.ts
```

This command parses your TypeScript source file and:
- Extracts interfaces with their JSDoc comments
- Finds methods decorated with `@tool`
- Generates properly formatted `FunctionDeclaration` objects
- Maps TypeScript types to JSON Schema types
- Handles optional vs required parameters correctly


**Options:**
- `-o, --output <FILE>` - Output file path (default: declarations.ts)

#### Run a Local Server

Run a local HTTP server that exposes your tools, mimicking the cloud runtime environment. This is useful for more complex integrations or testing from other services.

```bash
urai js serve <script1.ts> [script2.ts ...] [OPTIONS]
```

**Example:**
```bash
# Serve tools from a single script
urai js serve ./my-tools/tidycal.ts --port 3000

# Serve tools from multiple scripts
urai js serve ./tools/calendar.ts ./tools/email.ts --port 3000
```

The server exposes a single endpoint: `POST /call`.

**Request Body:**
```json
{
  "function_name": "your_tool_name",
  "args": { "arg1": "value1" }
}
```

**Example with `curl`:**
```bash
# Standard JSON response
curl -X POST http://127.0.0.1:3000/call \
  -H "Content-Type: application/json" \
  -d '{
    "function_name": "book_slot",
    "args": {
      "date": "2024-01-15",
      "time": "14:00"
    }
  }'

# Streaming response using Server-Sent Events (SSE)
curl -N -X POST "http://127.0.0.1:3000/call?stream=true" \
  -H "Content-Type: application/json" \
  -d '{
    "function_name": "long_running_task",
    "args": {}
  }'
```

**Options:**
- `-p, --port <PORT>` - Port to listen on (default: 3000)
- `-d, --work-dir <DIR>` - Working directory
- All secret/variable options supported

### 2. Cloud Management (`urai tool`)

Manage tools in the Urai Voice backend.

#### Create a Tool

```bash
urai tool create <name> --schema <schema.json>
```

**Example:**
```bash
urai tool create tidycal --schema ./tidycal-schema.json
```

**Options:**
- `-s, --schema <FILE>` - Path to schema JSON file (required)
- `--storage-path <PATH>` - Custom storage path (default: `<org-id>/<tool-name>`)
- `--main-script <FILE>` - Main script filename (default: `tool.ts`)
- `--org <ID>` - Organization ID (overrides config)
- `--api-key <KEY>` - API key (overrides config)

**Schema File Format:**
```json
[
  {
    "name": "book_slot",
    "description": "Books a calendar slot",
    "parameters": {
      "schema_type": "Object",
      "properties": {
        "date": {
          "schema_type": "string",
          "description": "Date in YYYY-MM-DD format"
        },
        "time": {
          "schema_type": "string",
          "description": "Time in HH:MM format"
        }
      },
      "required": ["date", "time"]
    }
  }
]
```

#### Upload Tool Files

After creating a tool, upload its implementation:

```bash
urai tool upload <tool-id> <directory>
```

**Example:**
```bash
urai tool upload 550e8400-e29b-41d4-a716-446655440000 ./my-tools/tidycal/
```

This command:
- Recursively scans the directory for TypeScript, JavaScript, and JSON files
- Uploads each file individually to cloud storage
- Skips `node_modules` and hidden files/directories
- Preserves the directory structure

**File types included:** `.ts`, `.js`, `.json`

#### Get Tool Details

```bash
urai tool get <tool-id>
```

#### List Tools

```bash
urai tool list
```

**Options:**
- `--status <STATUS>` - Filter by status (`draft`, `active`, `inactive`)

**Example:**
```bash
# List all active tools
urai tool list --status active
```

#### Update a Tool

```bash
urai tool update <tool-id> [OPTIONS]
```

**Options:**
- `--name <NAME>` - New name
- `--schema <FILE>` - Path to new schema JSON
- `--status <STATUS>` - New status (`draft`, `active`, `inactive`)

**Example:**
```bash
# Activate a tool
urai tool update 550e8400-e29b-41d4-a716-446655440000 --status active

# Update schema
urai tool update 550e8400-e29b-41d4-a716-446655440000 \
  --schema ./tidycal-schema-v2.json
```

#### Delete a Tool

Soft deletes a tool (marks as inactive):

```bash
urai tool delete <tool-id>
```

#### Link Tool to Agent

```bash
urai tool link <tool-id> <agent-id>
```

**Example:**
```bash
urai tool link 550e8400-e29b-41d4-a716-446655440000 \
  660e8400-e29b-41d4-a716-446655440001
```

#### Unlink Tool from Agent

```bash
urai tool unlink <tool-id> <agent-id>
```

#### Reload Tool Runtime

When you update tool files or secrets, reload the runtime to pick up changes:

```bash
urai tool reload <tool-id>
```

**Example:**
```bash
urai tool reload 550e8400-e29b-41d4-a716-446655440000
```

This command:
- Shuts down the existing runtime for the tool
- Forces the tool to reinitialize on the next execution
- Picks up updated code files and secrets

**When to use:**
- After uploading new/updated tool files
- After changing environment secrets
- When you want to force a clean restart of the tool

### 3. Agent Management (`urai agent`)

Commands for managing and viewing agents.

#### List Agents

View all agents in your organization:

```bash
urai agent list
```

**Example output:**
```
Agents (2)
================================================================================
3a7f8c21-1234-5678-9abc-def012345678 Customer Support Agent
  Description: Handles customer inquiries and support tickets
  Slug: customer-support
  Model: gemini-2.0-flash-exp
  Pipeline: gemini
  Language: en-US

5b9d2e43-5678-9012-cdef-345678901234 Sales Assistant
  Slug: sales-assistant
  Model: gemini-2.0-flash-exp
  Pipeline: cascaded
  Language: en-US

================================================================================
Tip: Use agent IDs with 'urai tool link'
```

This command is particularly useful when you need to find agent IDs for linking tools.

### 4. Secret Management (`urai secret`)

Securely manage encrypted secrets for your organization. Secrets are encrypted at rest using AES-256-GCM encryption.

#### Set a Secret

Create or update a secret:

```bash
urai secret set <name> <value>
```

**Examples:**
```bash
# Set an API key
urai secret set STRIPE_API_KEY sk_live_abc123

# Set a database URL
urai secret set DATABASE_URL "postgresql://user:pass@host/db"

# Set any environment variable
urai secret set OPENAI_API_KEY sk-proj-xyz789
```

**Note:** After setting a secret, any tools using it will need to be reloaded:
```bash
urai tool reload <tool-id>
```

#### Get a Secret

Retrieve and decrypt a secret's value:

```bash
urai secret get <name>
```

**Example:**
```bash
urai secret get STRIPE_API_KEY
```

**Output:**
```
Secret Details
============================================================
Name: STRIPE_API_KEY
Value: sk_live_abc123
============================================================
```

#### List Secrets

View all secret names (without revealing values):

```bash
urai secret list
```

**Example output:**
```
Secrets (3)
============================================================
  • STRIPE_API_KEY
  • DATABASE_URL
  • OPENAI_API_KEY
============================================================
Tip: Use 'urai secret get <name>' to view a secret's value
```

**Security Features:**
- All secrets are encrypted using AES-256-GCM with organization-specific keys
- Master encryption key is derived using HKDF-SHA256
- Each secret has a unique random nonce
- Secrets are never transmitted or stored in plaintext

## Complete Workflow Example

Here's a typical workflow for creating and deploying a new tool:

```bash
# 1. Create your TypeScript tool files
mkdir my-calendar-tool
cd my-calendar-tool

# 2. Write your tool implementation (tool.ts) with JSDoc
cat > tool.ts << 'EOF'
import "./declarations.ts";

/**
 * Booking request parameters
 */
interface BookingRequest {
  /** Date in YYYY-MM-DD format */
  date: string;
  /** Time in HH:MM format */
  time: string;
}

class CalendarTool {
  /**
   * Books a calendar slot
   */
  @tool
  static async book_slot({ date, time }: BookingRequest) {
    const apiKey = meta.secrets.CALENDAR_API_KEY;
    // Implementation...
    return { success: true, booking_id: "123" };
  }
}
EOF

# 2a. Auto-generate declarations from JSDoc
urai js generate-declarations tool.ts -o declarations.ts

# 3. Test locally
urai js list-tools tool.ts
urai js call tool.ts book_slot date=2024-01-15 time=14:00 -s '{"CALENDAR_API_KEY": "test-key"}'

# 4. Auto-generate schema file from TypeScript
urai js generate-schema tool.ts -o calendar-schema.json

# 5. Create tool in backend
urai tool create calendar --schema calendar-schema.json
# Output: Tool ID: 550e8400-e29b-41d4-a716-446655440000

# 6. Upload files
urai tool upload 550e8400-e29b-41d4-a716-446655440000 .

# 7. Activate the tool
urai tool update 550e8400-e29b-41d4-a716-446655440000 --status active

# 8. Find available agents
urai agent list
# Output: Lists all agents with their IDs

# 9. Set any required secrets for the tool
urai secret set CALENDAR_API_KEY your-api-key-here
urai secret set CALENDAR_URL https://api.calendar.com

# 10. Link to an agent
urai tool link 550e8400-e29b-41d4-a716-446655440000 <agent-id-from-list>
```

**Note:** The `generate-schema` command automatically extracts the declarations from your TypeScript file, eliminating the need to manually maintain a separate schema file!

### Workflow with Secrets Example

If your tool needs API keys or other secrets:

```bash
# 1. Set secrets first
urai secret set TIDYCAL_API_KEY your-api-key
urai secret set TIDYCAL_BASE_URL https://tidycal.com/api

# 2. Create and upload your tool (steps 1-6 from above)
urai tool create tidycal --schema tidycal-schema.json
urai tool upload <tool-id> ./tidycal

# 3. Activate the tool
urai tool update <tool-id> --status active

# 4. Link to agent and test
urai tool link <tool-id> <agent-id>

# If you update secrets later, reload the tool
urai secret set TIDYCAL_API_KEY new-api-key
urai tool reload <tool-id>
```

## Passing Secrets and Variables

### Secrets

Secrets are automatically collected from:
1. Environment variables matching: `*_TOKEN`, `*_KEY`, `*_SECRET`, `*_URL`, `*_ID`, `URAI_*`
2. Secrets file (JSON)
3. CLI argument (JSON)

```bash
# Via environment
export CALENDAR_API_KEY="secret-key"
urai js call tool.ts book_slot

# Via file
echo '{"CALENDAR_API_KEY": "secret-key"}' > secrets.json
urai js call tool.ts book_slot --secrets-file secrets.json

# Via CLI
urai js call tool.ts book_slot -s '{"CALENDAR_API_KEY": "secret-key"}'
```

### Variables

Variables provide runtime context:

```bash
# Via file
cat > vars.json << EOF
{
  "user": {
    "name": "Alice",
    "timezone": "America/New_York"
  }
}
EOF

urai js call tool.ts book_slot --vars-file vars.json

# Via CLI
urai js call tool.ts book_slot -v '{"user": {"name": "Alice"}}'
```

## Help

Get help for any command:

```bash
urai --help
urai js --help
urai js call --help
urai js generate-schema --help
urai js generate-declarations --help
urai tool --help
urai tool create --help
urai agent --help
urai secret --help
```

## Examples

### Example 1: Simple Math Tool

```typescript
// math.ts
import { ToolRegistry, tool } from "@urai/runtime";

ToolRegistry.addDeclarations([
  {
    name: "add",
    description: "Adds two numbers",
    parameters: {
      schema_type: "Object",
      properties: {
        a: { schema_type: "number", description: "First number" },
        b: { schema_type: "number", description: "Second number" }
      },
      required: ["a", "b"]
    }
  }
]);

class MathTool {
  @tool
  static add({ a, b }: { a: number; b: number }): number {
    return a + b;
  }
}
```

Test it:
```bash
urai js call math.ts add a:=10 b:=32
```

### Example 2: API Integration Tool

```typescript
// weather.ts
import { ToolRegistry, tool, meta } from "@urai/runtime";

ToolRegistry.addDeclarations([/* ... */]);

class WeatherTool {
  @tool
  static async get_weather({ city }: { city: string }) {
    const apiKey = meta.secrets.WEATHER_API_KEY;
    const response = await fetch(
      `https://api.weather.com/data?city=${city}&key=${apiKey}`
    );
    return await response.json();
  }
}
```

Test it:
```bash
export WEATHER_API_KEY="your-key"
urai js call weather.ts get_weather city="New York"
```

## Troubleshooting

### "API URL not configured"

Set the API URL via an environment variable or add it to a profile in your config file (`.urai.toml` or `~/.config/urai/config.toml`).

```bash
export URAI_API_URL="https://your-server.com"
```

### "API key not configured"

Set your API key via an environment variable or add it to a profile in your config file.

```bash
export URAI_API_KEY="your-api-key"
```

### Upload fails

Ensure:
- Directory exists and contains your tool files
- Tool was created successfully (check with `urai tool get <id>`)
- You have sufficient permissions

### Tool not working after upload

Check:
1. Tool status is `active`: `urai tool update <id> --status active`
2. Tool is linked to agent: `urai tool link <tool-id> <agent-id>`
3. Schema matches implementation

## License

See main repository license.
