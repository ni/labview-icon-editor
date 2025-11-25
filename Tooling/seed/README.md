README.md
markdown
Copy
# LabVIEW CI/CD Seed GitHub Action

This repository provides a GitHub Action and companion CLI tools to automate conversion, patching, and seeding of LabVIEW project (`.lvproj`) and VI Package Build specification (`.vipb`) files. It streamlines CI/CD pipelines for LabVIEW applications by enabling human-readable JSON conversions and automated project setup.

## Features

1. **Conversion:** Convert between `.vipb` (VI Package Build spec) or `.lvproj` (LabVIEW Project) files and JSON format. This facilitates easy version control and diffing, since JSON can be text-diffed and edited directly. (Aliases `buildspec2json` and `json2buildspec` perform auto-detection for convenience.)  
2. **Patching:** Apply modifications to `.vipb`, `.lvproj`, or JSON files via patch files. Supported patch methods include standard diff/patch files and YAML merge patches (requires `yq` for YAML processing). This allows automating changes (e.g., updating version numbers or build settings) without manual GUI edits.  
3. **Seeding:** Automatically create initial template files when they don’t exist. For example, generate a starter `seed.lvproj` or `build/buildspec.vipb` from known-good “golden” templates. This ensures new projects or builds begin with standardized content.

## Getting Started

You can use LabVIEW CI/CD Seed either as a GitHub Action within workflows or as a standalone set of CLI tools (via Docker or local build):

### Using as a GitHub Action

Simply reference the action in your GitHub workflow. The action runs in a Docker container that already includes all needed dependencies (the conversion binary, wrapper scripts, `yq`, `gh`, etc.). 

#### Inputs

The GitHub Action accepts the following inputs (parameters): 

| Name           | Required | Default | Description                                                                                                            |
| -------------- | -------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| **`mode`**         | yes      | *(none)* | Operation mode: one of `vipb2json`, `json2vipb`, `lvproj2json`, or `json2lvproj`. *(Aliases `buildspec2json` and `json2buildspec` are also accepted.)* |
| **`input`**        | yes      | *(none)* | Path to the input file (a `.vipb`, `.lvproj`, or `.json` file, depending on mode).                                     |
| **`output`**       | yes      | *(none)* | Path to the output file to produce (a `.vipb`, `.lvproj`, or `.json`, depending on mode).                              |
| **`patch_file`**   | no       | *(none)* | Path to a plaintext diff/patch file to apply *after* conversion (uses the Unix `patch` utility).                       |
| **`patch_yaml`**   | no       | *(none)* | Path to a YAML merge patch file to apply *after* conversion (requires the `yq` tool).                                  |
| **`always_patch`** | no       | `false`  | If `true`, apply patches even if target fields are missing (force patching).                                          |
| **`branch_name`**  | no       | *(none)* | If provided, the action will commit the generated output file(s) to a new branch with this name.                      |
| **`auto_pr`**      | no       | `false`  | If `true`, open a pull request automatically after committing changes (uses GitHub CLI `gh` to create the PR).         |
| **`upload_files`** | no       | `true`   | If `true`, upload the generated output file(s) as workflow artifacts for easy download from the workflow run.         |
| **`seed_lvproj`**  | no       | `false`  | If `true`, and no `.lvproj` exists, create a new `seed.lvproj` from the provided template (see **Seeding** below).     |
| **`seed_vipb`**    | no       | `false`  | If `true`, and no build spec exists, create a new `buildspec.vipb` (in `build/`) from the provided template file.      |
| **`tag`**          | no       | *(none)* | **Required when seeding is enabled.** Specifies a version tag (e.g. `v1.2.3`) to name the seeding branch (`seed-<tag>`). |

#### Example Workflow

Below is an example illustrating how to seed new LabVIEW project files on a tag push using this action:

```yaml
name: Seed LabVIEW Project and Build Spec
on:
  push:
    tags:
      - 'v*'  # trigger on version tag like v1.2.3

jobs:
  seed-files:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Seed LabVIEW project & VIPB
        uses: LabVIEW-Community-CI-CD/seed@v2.0.0
        with:
          mode: vipb2json           # Mode is required but ignored during seeding
          input: dummy.vipb         # Dummy input (unused in seeding mode)
          output: dummy.json        # Dummy output (unused in seeding mode)
          seed_lvproj: true         # Create seed.lvproj if missing
          seed_vipb: true          # Create buildspec.vipb if missing
          tag: ${{ github.ref_name }}
```
What happens in the above workflow?
If a seed.lvproj file is not present at the repository root, the action copies the template tests/Samples/seed.lvproj into place as a starting project file.
If build/buildspec.vipb is not present, the action creates the build directory (if needed) and copies the template tests/Samples/seed.vipb to build/buildspec.vipb.
The action commits the new file(s) to a branch named seed-<tag> (for example, seed-v1.2.3 if the workflow was triggered by pushing tag v1.2.3).
If auto_pr: true was set, the action would also open a pull request from that branch. In this example, auto_pr is false, so it simply pushes the branch.
Using the CLI Tools (via Docker or Local)
In addition to the GitHub Action, this project provides several command-line tools for direct use. These are wrapper scripts (and a backing .NET binary) that you can run to perform conversions outside of GitHub Actions. Each tool corresponds to one mode of conversion:
vipb2json – Convert a .vipb file (VI Package Build spec) to JSON.
Usage: vipb2json --input path/to/file.vipb --output path/to/file.json
json2vipb – Convert a JSON file back into .vipb format.
Usage: json2vipb --input path/to/file.json --output path/to/file.vipb
lvproj2json – Convert a .lvproj file (LabVIEW Project) to JSON.
Usage: lvproj2json --input path/to/file.lvproj --output path/to/file.json
json2lvproj – Convert a JSON file back into .lvproj format.
Usage: json2lvproj --input path/to/file.json --output path/to/file.lvproj
buildspec2json – Convert either a .vipb or .lvproj file to JSON. This alias auto-detects the input type (Project vs Package) and outputs JSON accordingly.
Usage: buildspec2json --input path/to/file.(vipb|lvproj) --output path/to/file.json
json2buildspec – Convert a JSON file into a .vipb or .lvproj. The output type is determined by the file extension you provide for the output.
Usage: json2buildspec --input path/to/file.json --output path/to/file.(vipb|lvproj)
Each of these commands will print a brief help message if invoked with -h or --help. They also validate their inputs: if required flags are missing or an unknown flag is provided, the tool will exit with an error message.
Obtaining the Tools
There are two main ways to get the LabVIEW CI/CD Seed tools:
Via Docker Image: A pre-built Docker image (based on Ubuntu) is available with the conversion binary and all wrapper scripts installed in /usr/local/bin. This image also includes git, patch, yq, and gh. You can pull it from GitHub Packages (GHCR) or build it yourself. For example, to use Docker (assuming the image is published as ghcr.io/labview-community-ci-cd/seed:latest):
bash
Copy
docker pull ghcr.io/labview-community-ci-cd/seed:latest
# Convert a VIPB to JSON using the container:
docker run --rm -v "$PWD:/data" ghcr.io/labview-community-ci-cd/seed:latest \
  vipb2json --input /data/MyBuildSpec.vipb --output /data/MyBuildSpec.json
In the above example, we run the vipb2json tool inside the container, mounting the current directory to /data in the container to access input and output files. The container’s entrypoint is configured to recognize the CLI commands. Running the container with no command will display a help message about available tools.
From Source (Local Build): If you prefer to run the tools natively, you can compile the .NET tool and use the scripts directly on your machine. This requires the .NET 8.0 SDK and PowerShell (for running tests). Clone this repository and see the Development & Contributing section below for build instructions. Once built, you can find the VipbJsonTool binary (or use dotnet run) and the wrapper scripts in the bin/ directory.
Note: The CLI wrapper scripts are simple front-ends that call the underlying VipbJsonTool with the appropriate mode. They ensure arguments are provided and offer --help documentation.
Development & Contributing
Contributions are welcome! If you want to modify or extend this project, here’s how to set up your environment:
Requirements: Install .NET SDK 8.0 (or newer) and PowerShell 7+ (PowerShell Core) on your development machine. The .NET SDK is needed to build the VipbJsonTool converter, and PowerShell is used to run the test suite (via Pester tests).
Building the converter: The conversion utility is a C# project targeting .NET 8. It is configured to produce a single-file, self-contained binary for Linux. You can build it by running:
bash
Copy
dotnet build src/VipbJsonTool/VipbJsonTool.csproj -c Release
The output binary (for your OS/runtime) will be in src/VipbJsonTool/bin/Release/<framework>/. Alternatively, use dotnet publish -c Release -r linux-x64 --self-contained -p:PublishSingleFile=true to produce the self-contained Linux binary as done in the Docker build.
CLI scripts: The shell scripts for vipb2json, json2vipb, etc., are located in the bin/ folder. They expect the VipbJsonTool binary to be in your PATH or in the same directory. Ensure the binary is built and accessible before running them locally. You may add bin/ to your PATH for convenience during development.
Running tests: This repository uses Pester for its test suite. Tests verify that JSON round-trip conversions work and that the CLI tools behave as expected. To run all tests, execute Pester from the repository root. For example, from a PowerShell prompt:
powershell
Copy
# Install Pester if not already installed
Install-Module Pester -Force -Scope CurrentUser

# Run all tests with coverage enabled
$Config = New-PesterConfiguration
$Config.Run.Path = 'tests'
$Config.CodeCoverage.Enabled = $true
$Config.CodeCoverage.Path = 'tools/*.ps1'
$Config.TestResult.OutputFormat = 'NUnitXml'
$Config.TestResult.OutputPath = 'TestResults.xml'
Invoke-Pester -Configuration $Config
The above will execute all *.Tests.ps1 files in the tests/ directory. It will also generate a test results file (TestResults.xml) and a code coverage report.
Test coverage: Enabling Pester’s code coverage will produce a coverage.xml file in the JaCoCo format by default
pester.dev
. This file details which lines of your PowerShell scripts were executed by the tests. You can examine the coverage summary in the console output, or use a tool like ReportGenerator to convert coverage.xml into a human-friendly HTML report
donovanbrown.com
. For instance, using ReportGenerator to produce an HTML report will allow you to open index.html and visually see which lines were covered by tests.
Conventional Workflow: This project includes a GitHub Actions workflow for CI. When you open a pull request or push to the main branch, the workflow will build the .NET tool, run the Pester tests (failing if any test fails), and publish artifacts like the compiled binary and test results. Ensure all tests pass and consider writing new tests for any new features or bug fixes.
Feel free to submit issues or pull requests for improvements. When contributing, please follow common best practices: keep commits focused, update documentation for any changes in behavior, and add tests for new code where possible.
AI Guidance Tips
If using AI-powered tools (like GitHub Copilot or ChatGPT) to assist in writing workflows or code, keep in mind:
Clarify parameters: Ensure you specify concrete file paths and modes when prompting AI to generate YAML or code, to avoid ambiguity in the suggestions. For example, explicitly mention “use vipb2json on buildspec.vipb” rather than asking it to “convert my file,” so the generated snippet is accurate.
Highlight dependencies: The Docker image includes yq for YAML patching and gh for GitHub operations. If AI-generated steps involve these, make sure your runner or container has them (the provided Docker does).
Branching strategy: Clearly explain to AI (and in your documentation) how you want branches and PRs to be handled. This action uses branch_name, tag, and auto_pr to manage branches and PRs. Keeping those consistent in examples will avoid confusion and align with your repository’s policies.
Troubleshooting Docker Builds
Building the Docker image or using this action’s container occasionally runs into common issues. Here are some tips:
Entrypoint execution: Ensure the entrypoint.sh script is copied and has execute permission. If you get “permission denied” or “file not found” errors on container startup, verify that the Dockerfile used chmod +x /entrypoint.sh and that the file path is correct.
CLI scripts present: All wrapper scripts in bin/ should be present and marked executable. The Docker build copies these to /usr/local/bin. If a script is missing, the action will report an “Unsupported mode” error for that command.
Conversion tool binary: Make sure the VipbJsonTool binary is built and either included in the image or mounted in. The Dockerfile above uses a multi-stage build to include it. If you modify the .NET tool, rebuild the image to update the binary.
Sample files: Verify that the sample template files exist in tests/Samples/. The image expects seed.lvproj and seed.vipb to be available for seeding new files. Missing templates will cause seeding to fail.
Rebuild and inspect: If a Docker build fails, run it with docker build . --no-cache to ensure you’re not using stale layers. Look at the build output for any “file not found” messages to identify what’s missing.
By following these guidelines, you can resolve most issues encountered during container build or runtime. Happy converting and seeding!
