<div align="center">

# Podman AI Cluster

**A lightweight, scalable AI inference cluster built entirely on pure Podman + Systemd.**

[![Podman](https://img.shields.io/badge/Podman-892CA0?style=for-the-badge&logo=podman&logoColor=white)](https://podman.io)
[![Systemd](https://img.shields.io/badge/Systemd-Quadlets-009688?style=for-the-badge)](https://www.freedesktop.org/software/systemd/man/latest/systemd.html)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

*No Kubernetes. No Docker. No heavyweight orchestrators.*
*Just Podman, Systemd, and bash.*

</div>

---

## Overview

Podman App Cluster is a case study that demonstrates how to build a fully functional AI inference platform — complete with load balancing, horizontal auto-scaling, and GitOps-driven continuous deployment — using **only native Linux tooling**.

The stack provisions multiple [Ollama](https://ollama.com) inference workers behind a [LiteLLM](https://litellm.ai) API gateway, fronted by [Open-WebUI](https://openwebui.com) for a ChatGPT-like experience, all managed declaratively through [Podman Quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) and Systemd timers.

### Key Features

- **Rootless by default** — entire cluster runs without root privileges via Podman's rootless mode
- **Declarative pod definitions** — Kubernetes-style YAML consumed natively by Podman Quadlets
- **Template-based scaling** — Systemd `@` templates enable `ollama@1`, `ollama@2`, ..., `ollama@N` instances
- **Automatic horizontal scaling** — CPU-based autoscaler creates/destroys replicas via Systemd
- **GitOps continuous deployment** — periodic `git pull` syncs cluster state from the repository
- **Shared model storage** — all Ollama nodes mount a single volume, eliminating redundant multi-GB model downloads
- **OpenAI-compatible API** — any tool or SDK targeting the OpenAI API works out of the box

---

## Architecture

```
                          ┌─────────────────────────────────────────────┐
                          │          Linux Host (Podman + Systemd)      │
                          │                                             │
User ──▶ Traefik (:80) ──┤──▶ chat.localhost ──▶ Open-WebUI (:3000)    │
                          │                         │                   │
                          │                         ▼                   │
                          ├──▶ api.localhost  ──▶ LiteLLM (:4000)      │
                          │                      ┌──┼──┐               │
                          │                      ▼  ▼  ▼               │
                          │               Ollama Nodes (:11434)        │
                          │               [1] [2] ... [N]              │
                          │                      │                     │
                          │                      ▼                     │
                          │              Shared Model Volume           │
                          └─────────────────────────────────────────────┘

         ┌──────────────────────────────────────┐
         │        Systemd Timers (1 min)        │
         │  ┌─────────────┐  ┌───────────────┐  │
         │  │ GitOps Sync │  │  Autoscaler   │  │
         │  └─────────────┘  └───────────────┘  │
         └──────────────────────────────────────┘
```

### Request Flow

```
Client Request
  └─▶ Traefik (:80)
        ├── Host: chat.localhost ──▶ Open-WebUI (:3000) ──▶ LiteLLM (:4000/v1)
        └── Host: api.localhost  ──▶ LiteLLM (:4000)
                                       └─▶ usage-based routing ──▶ Ollama Node 1..N
```

---

## Components

| Component | Image | Role | Port |
|---|---|---|---|
| **Traefik** | `traefik:v3.0` | Reverse proxy, service discovery | `:80`, `:8080` (dashboard) |
| **Ollama** | `ollama/ollama:latest` | LLM inference engine (scalable) | `:11434` |
| **LiteLLM** | `ghcr.io/berriai/litellm:main-latest` | OpenAI-compatible API gateway & load balancer | `:4000` |
| **Open-WebUI** | `ghcr.io/open-webui/open-webui:main` | Web-based chat interface | `:3000` |
| **GitOps Agent** | — (bash + systemd timer) | Continuous deployment from Git | — |
| **Autoscaler** | — (bash + systemd timer) | CPU-based horizontal pod scaling | — |

---

## Prerequisites

- **Linux** with Systemd (Ubuntu 22.04+, Fedora 38+, Debian 12+)
- **Podman** >= 4.5 (Quadlet support required)
- **Git** and **Bash** >= 4.0
- **16 GB RAM** minimum (LLM inference is memory-intensive)
- **20 GB disk** free (container images + model weights)

**Optional (GPU acceleration):**

- NVIDIA GPU with proprietary drivers
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) with CDI configured

```bash
# Verify Podman version
podman --version  # must be >= 4.5.0

# (Optional) Generate CDI spec for GPU passthrough
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/your-user/podman-app-cluster.git
cd podman-app-cluster

# 2. Run the installer
chmod +x install.sh
./install.sh

# 3. Verify the cluster is running
systemctl --user list-units 'ollama@*' 'litellm*' 'open-webui*' 'traefik*'
podman ps
```

### What `install.sh` Does

1. Checks that Podman is installed
2. Copies the repository to `/opt/podman-app-cluster`
3. Enables `loginctl enable-linger` for rootless persistence
4. Installs GitOps and Autoscaler timers into user-level Systemd
5. Deploys the Traefik reverse proxy Quadlet
6. Copies application Quadlets (Ollama, LiteLLM, Open-WebUI)
7. Starts LiteLLM and Open-WebUI services
8. Bootstraps the first Ollama node (`ollama@1.service`)

> **Note:** Initial startup may take several minutes while Podman pulls container images (~3 GB for Ollama) and downloads the default model (`llama3`, ~4.7 GB).

---

## Project Structure

```
podman-app-cluster/
├── install.sh                        # Bootstrap and installation script
├── ARCHITECTURE.md                   # Architecture documentation (pt-BR)
├── README.md
│
├── apps/
│   ├── ollama/
│   │   ├── deployment.yml            # Pod spec (Kube YAML)
│   │   └── ollama@.kube              # Quadlet template (@ = multi-instance)
│   │
│   ├── litellm/
│   │   ├── deployment.yml            # Pod spec with Traefik labels
│   │   ├── litellm.kube              # Quadlet
│   │   ├── litellm_config.yaml       # Production config (host network)
│   │   └── litellm_config_dev.yaml   # Development config (container DNS)
│   │
│   └── open-webui/
│       ├── deployment.yml            # Pod spec with Traefik labels
│       └── open-webui.kube           # Quadlet
│
└── cluster/
    ├── proxy/
    │   └── traefik.container         # Traefik Quadlet (Container type)
    │
    ├── gitops/
    │   ├── gitops-sync.sh            # Git pull + Quadlet sync script
    │   ├── gitops.service            # Systemd oneshot service
    │   └── gitops.timer              # Periodic timer (every 1 min)
    │
    └── autoscaler/
        ├── autoscaler.sh             # CPU-based scaling logic
        ├── autoscaler.service        # Systemd oneshot service
        └── autoscaler.timer          # Periodic timer (every 1 min)
```

---

## Configuration

### Models

Models are registered in `apps/litellm/litellm_config.yaml`:

```yaml
model_list:
  - model_name: llama3
    litellm_params:
      model: ollama/llama3
      api_base: "http://localhost:11434"

  - model_name: mistral
    litellm_params:
      model: ollama/mistral
      api_base: "http://localhost:11434"

router_settings:
  routing_strategy: usage-based-routing-v2

general_settings:
  master_key: sk-1234   # replace in production
```

To add a model:

```bash
# 1. Pull the model into Ollama
podman exec <ollama-container> ollama pull <model-name>

# 2. Add the entry to litellm_config.yaml

# 3. Restart the gateway
systemctl --user restart litellm.service
```

**Recommended models for testing:**

| Model | Size | RAM Usage | Best For |
|---|---|---|---|
| `llama3` (8B) | ~4.7 GB | ~8 GB | General chat, code |
| `mistral` (7B) | ~4.1 GB | ~6 GB | Instructions, reasoning |
| `codellama` (7B) | ~3.8 GB | ~6 GB | Code generation |
| `phi3` (3.8B) | ~2.3 GB | ~4 GB | Low-memory environments |

### Routing (Traefik)

Routes are declared via pod labels in each `deployment.yml`:

```yaml
metadata:
  labels:
    traefik.enable: "true"
    traefik.http.routers.litellm.rule: "Host(`api.localhost`)"
    traefik.http.services.litellm.loadbalancer.server.port: "4000"
```

| Hostname | Target |
|---|---|
| `chat.localhost` | Open-WebUI (`:3000`) |
| `api.localhost` | LiteLLM (`:4000`) |

### API Key

Authentication between services uses the LiteLLM `master_key`. The default value is `sk-1234` — **change this in production.**

| File | Key |
|---|---|
| `apps/litellm/litellm_config.yaml` | `master_key: sk-1234` |
| `apps/open-webui/deployment.yml` | `OPENAI_API_KEY: "sk-1234"` |

```bash
# Generate a secure key
openssl rand -hex 32
```

### GPU (NVIDIA)

Uncomment the resource block in `apps/ollama/deployment.yml`:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
env:
- name: NVIDIA_VISIBLE_DEVICES
  value: all
```

Requires: NVIDIA driver + Container Toolkit + CDI spec.

### Autoscaler Tuning

Edit the constants at the top of `cluster/autoscaler/autoscaler.sh`:

```bash
MAX_REPLICAS=5            # Maximum replicas per app
MIN_REPLICAS=1            # Minimum replicas (never scales to zero)
TARGET_CPU_PERCENT=70     # CPU threshold for scale-up
# Scale-down threshold is 20% (hardcoded at line 51)
```

Apps monitored by the autoscaler:

```bash
APPS=("ollama")           # Add app names as needed
```

> **Note:** Only apps with Systemd template Quadlets (`@.kube`) support multi-instance scaling. Fixed Quadlets like `litellm.kube` require refactoring to use templates.

### GitOps Sync Interval

Edit `cluster/gitops/gitops.timer`:

```ini
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min      # Change to 5min, 15min, etc.
```

---

## Usage

### Service Management

```bash
# Status
systemctl --user status traefik.service
systemctl --user status ollama@1.service
systemctl --user status litellm.service
systemctl --user status open-webui.service

# Logs (follow mode)
journalctl --user -u ollama@1.service -f
journalctl --user -u litellm.service -f

# Container stats
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
podman stats --no-stream

# Stop all services
systemctl --user stop traefik litellm open-webui ollama@1

# Restart a single service
systemctl --user restart litellm.service
```

### Manual Scaling

```bash
# Scale up
systemctl --user start ollama@2.service
systemctl --user start ollama@3.service

# List active replicas
systemctl --user list-units 'ollama@*'

# Scale down
systemctl --user stop ollama@3.service
```

### Web Access

| Service | URL | Description |
|---|---|---|
| Chat UI | `http://chat.localhost` | ChatGPT-like interface |
| API Gateway | `http://api.localhost` | OpenAI-compatible endpoint |
| Traefik Dashboard | `http://localhost:8080` | Route and service overview |
| Ollama (direct) | `http://localhost:11434` | Raw Ollama API |
| LiteLLM (direct) | `http://localhost:4000` | Raw gateway API |

> If `*.localhost` does not resolve, add to `/etc/hosts`:
> ```
> 127.0.0.1  chat.localhost api.localhost
> ```

### API Examples

**cURL:**

```bash
curl http://api.localhost/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234" \
  -d '{
    "model": "llama3",
    "messages": [
      {"role": "user", "content": "What is Podman?"}
    ]
  }'
```

**Python (openai SDK):**

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://api.localhost/v1",
    api_key="sk-1234",
)

response = client.chat.completions.create(
    model="llama3",
    messages=[{"role": "user", "content": "What is Podman?"}],
)
print(response.choices[0].message.content)
```

**JavaScript (fetch):**

```javascript
const response = await fetch("http://api.localhost/v1/chat/completions", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: "Bearer sk-1234",
  },
  body: JSON.stringify({
    model: "llama3",
    messages: [{ role: "user", content: "What is Podman?" }],
  }),
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

---

## GitOps Workflow

The GitOps agent (`cluster/gitops/gitops-sync.sh`) runs every minute via a Systemd timer:

```
1. git pull origin main
2. Compare HEAD hash with previous run
3. If changed:
   a. Copy all .kube and .container files to ~/.config/containers/systemd/
   b. systemctl --user daemon-reload
   c. Reload or restart affected services
4. If unchanged: no-op
```

**Deploy workflow:**

```bash
# Edit a config (e.g., add a model to LiteLLM)
vim apps/litellm/litellm_config.yaml

# Commit and push
git add -A && git commit -m "chore: add codellama model" && git push

# Within 1 minute, the cluster picks up the change automatically
```

---

## Auto-Scaling

The autoscaler (`cluster/autoscaler/autoscaler.sh`) runs every minute via a Systemd timer:

```
For each monitored app (default: ollama):
  1. Collect CPU usage from all running replicas (via podman stats)
  2. Compute the average CPU percentage
  3. If avg CPU >= 70% AND replicas < MAX → start ollama@(N+1).service
  4. If avg CPU <= 20% AND replicas > MIN → stop ollama@N.service
```

**Example output:**

```
CPU avg for ollama: 82% (replicas: 1)
  → Scaling UP ollama to replica ID 2...

CPU avg for ollama: 65% (replicas: 2)
  → Load stable. No action.

CPU avg for ollama: 12% (replicas: 2)
  → Scaling DOWN ollama — stopping replica ID 2...
```

---

## Volumes & Persistence

| Volume | Host Path | Contents |
|---|---|---|
| `ollama_data` | `/var/lib/containers/storage/volumes/ollama_data/_data` | Downloaded model weights |
| `openwebui_data` | `/var/lib/containers/storage/volumes/openwebui_data/_data` | WebUI config, chat history |
| `litellm-config` | `/opt/podman-app-cluster/apps/litellm/litellm_config.yaml` | Bind-mounted config file |

> **Important:** `ollama_data` is shared across all Ollama replicas. This prevents duplicate downloads of models that can range from 5 GB to 40 GB each.

**Backup:**

```bash
sudo tar czf ollama-models-backup.tar.gz \
  /var/lib/containers/storage/volumes/ollama_data/

sudo tar czf webui-data-backup.tar.gz \
  /var/lib/containers/storage/volumes/openwebui_data/
```

---

## Troubleshooting

<details>
<summary><strong>Container fails to start</strong></summary>

```bash
journalctl --user -u ollama@1.service --no-pager -n 50
systemctl --user cat ollama@1.service
systemctl --user daemon-reload
```
</details>

<details>
<summary><strong>Port already in use</strong></summary>

```bash
ss -tlnp | grep 11434
systemctl --user stop ollama@1.service
```
</details>

<details>
<summary><strong>Model download timeout</strong></summary>

Increase `TimeoutStartSec` in the Quadlet:

```ini
[Service]
TimeoutStartSec=300   # 5 minutes for large models
```
</details>

<details>
<summary><strong>Open-WebUI cannot reach LiteLLM</strong></summary>

```bash
# Check gateway health
curl http://localhost:4000/health

# Verify env vars in apps/open-webui/deployment.yml:
#   OPENAI_API_BASE_URL = http://host.containers.internal:4000/v1
#   OPENAI_API_KEY      = <must match litellm master_key>
```
</details>

<details>
<summary><strong>GitOps not syncing</strong></summary>

```bash
systemctl --user status gitops.timer
bash /opt/podman-app-cluster/cluster/gitops/gitops-sync.sh
cd /opt/podman-app-cluster && git remote -v
```
</details>

<details>
<summary><strong>Quadlet not recognized by Systemd</strong></summary>

```bash
# Quadlets must be in one of:
#   ~/.config/containers/systemd/   (rootless)
#   /etc/containers/systemd/        (rootful)

ls -la ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user list-unit-files | grep -E "ollama|litellm|webui|traefik"
```
</details>

---

## Roadmap

- [ ] Multi-host deployment via Podman Remote
- [ ] Prometheus + Grafana observability stack
- [ ] Automatic TLS via Let's Encrypt (Traefik ACME)
- [ ] Secrets management (Vault / SOPS integration)
- [ ] Container health checks with automatic restart
- [ ] Webhook notifications on scaling events
- [ ] Per-consumer rate limiting in LiteLLM
- [ ] Multi-GPU scheduling with selective CDI passthrough

---

## License

This project is a **case study** for educational purposes. Feel free to use it as a reference for your own infrastructure.

---

<div align="center">

Built with Podman. No Kubernetes was harmed in the making of this cluster.

</div>
