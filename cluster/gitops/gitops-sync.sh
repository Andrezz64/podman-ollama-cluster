#!/bin/bash
# Podman GitOps Sync Agent
# Este script deve rodar periodicamente (ex. via systemd timer).
# Ele atualiza o repositório e copia os arquivos .kube e .container
# para o diretório de systemd do podman e recarrega os serviços alterados.

set -e

REPO_DIR="/opt/podman-app-cluster"
SYSTEMD_USER_DIR="$HOME/.config/containers/systemd"

cd "$REPO_DIR"

# Guarda hash antigo
OLD_HASH=$(git rev-parse HEAD)

# Puxa atualizações do git
git pull origin main

# Guarda novo hash
NEW_HASH=$(git rev-parse HEAD)

if [ "$OLD_HASH" != "$NEW_HASH" ]; then
    echo "$(date) - Mudanças detectadas via GitOps. Atualizando Quadlets e recarregando..."
    
    mkdir -p "$SYSTEMD_USER_DIR"
    
    # Sincronizando quadlets do proxy
    cp cluster/proxy/*.container cluster/proxy/*.kube "$SYSTEMD_USER_DIR/" 2>/dev/null || true
    
    # Sincronizando quadlets dos apps
    # Como são templates (ex: frontend@.kube) ou normais, apenas copiamos todos .kube e .container
    find apps/ -type f \( -name "*.kube" -o -name "*.container" \) -exec cp {} "$SYSTEMD_USER_DIR/" \;
    
    # Avisa ao systemd e recarrega o systemd daemon daemon 
    systemctl --user daemon-reload
    
    # Para atualizar as imagens com base nas novas especificações
    # O podman auto-update restart-se as units caso suas imagens ou configs tenham mudado.
    # Mas como estamos num cenário leve, talvez reiniciar serviços afetados manualmente seja melhor, ou
    # rodar podman auto-update.
    systemctl --user reload-or-restart $(find apps/ -type f -name "*.kube" -exec basename {} .kube \;) 2>/dev/null || true
    
    echo "$(date) - Sincronização e deploy GitOps concluído."
else
    echo "$(date) - Nenhuma mudança (GitOps sincronizado)."
fi
