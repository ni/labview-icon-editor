# Devcontainer notes

- This container is for Linux-side tooling and the Ollama executor; LabVIEW/VIPM builds stay on Windows hosts.
- For git auth inside the container or Codespaces, follow `docs/auth.md` (SSH-first, Git Credential Manager for HTTPS, PAT last). No secrets are baked into the image; use agent forwarding or interactive GCM.
