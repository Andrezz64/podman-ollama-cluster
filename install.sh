#!/bin/bash
# Podman App Cluster - Install Script
# Instala e inicializa o nosso ambiente minimalista de container local

echo "Inicializando Podman App Cluster..."

# Pre-req check
if ! command -v podman &> /dev/null; then
    echo "Erro: Podman não está instalado."
    exit 1
fi

SYSTEMD_DIR="$HOME/.config/containers/systemd"
APP_DIR="/opt/podman-app-cluster"

mkdir -p "$SYSTEMD_DIR"
mkdir -p "$APP_DIR"

# Simula copia deste repositório para o local oficial de operação (/opt/podman-app-cluster) 
echo "Copiando arquivos do repositório para a pasta de dados local..."
cp -R ./* "$APP_DIR/"

# Habilita logind persistence para rootless
if [ "$EUID" -ne 0 ]; then
    loginctl enable-linger "$USER"
fi

echo "Copiando timers de infraestrutura..."
# Usamos user systemd (rootless podman systemd)
mkdir -p "$HOME/.config/systemd/user"
cp $APP_DIR/cluster/gitops/gitops.service "$HOME/.config/systemd/user/"
cp $APP_DIR/cluster/gitops/gitops.timer "$HOME/.config/systemd/user/"
cp $APP_DIR/cluster/autoscaler/autoscaler.service "$HOME/.config/systemd/user/"
cp $APP_DIR/cluster/autoscaler/autoscaler.timer "$HOME/.config/systemd/user/"

systemctl --user daemon-reload
systemctl --user enable --now gitops.timer
systemctl --user enable --now autoscaler.timer

echo "Ativando proxy do Traefik..."
cp $APP_DIR/cluster/proxy/traefik.container "$SYSTEMD_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now traefik.service

echo "Fazendo bootstrap das rotas de IA (Ollama, LiteLLM, Open-WebUI)..."
cp $APP_DIR/apps/ollama/ollama@.kube "$SYSTEMD_DIR/"
cp $APP_DIR/apps/litellm/litellm.kube "$SYSTEMD_DIR/"
cp $APP_DIR/apps/open-webui/open-webui.kube "$SYSTEMD_DIR/"

systemctl --user daemon-reload

echo "Iniciando LiteLLM e WebUI..."
systemctl --user enable --now litellm.service
systemctl --user enable --now open-webui.service

echo "Fazendo bootstrap do primeiro nó do Ollama (Pode demorar devido ao pull da imagem de 3GB+)..."
systemctl --user enable --now ollama@1.service

echo "Instalação concluída com sucesso!"
echo "O GitOps e o Autoscaler continuarão escalando os nós do ollama@.kube conforme a carga de GPU/CPU demandar!"
