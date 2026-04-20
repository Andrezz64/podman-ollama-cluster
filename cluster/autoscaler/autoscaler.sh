#!/bin/bash
# Podman Auto-Scaler Simples
# Monitora a CPU de containers específicos (via label) e ajusta as réplicas instanciadas pelo systemd
# Ex: para o systemd template 'frontend@.service', ele chamará 'systemctl --user start frontend@2.service' etc.

MAX_REPLICAS=5
MIN_REPLICAS=1
TARGET_CPU_PERCENT=70

# Listamos base de instâncias a monitorar
# Aqui podemos buscar apps habilitados ou simplesmente hardcodar para demonstração
APPS=("ollama")

for APP in "${APPS[@]}"; do
    echo "Analisando escalonamento para: $APP"

    # Encontrando conteineres ativos associados a este APP
    # Baseado no nome do serviço base, que podman assigna.
    # Exemplo: O container será nomeado algo como systemd-frontend.1 etc.
    CONTAINERS=$(podman ps --format "{{.Names}}" | grep "$APP" || true)
    
    if [ -z "$CONTAINERS" ]; then
        echo "Nenhum container rodando para $APP. Ignorando."
        continue
    fi

    TOTAL_CPU=0
    COUNT=0
    
    for CONTAINER in $CONTAINERS; do
        # Retorna por ex " 5.50%" (separa o numero)
        CPU_USAGE=$(podman stats --no-stream --format "{{.CPUPerc}}" "$CONTAINER" | sed 's/%//g' | awk '{print $1}')
        
        # Converte float para int p/ bash via AWK
        CPU_INT=$(awk "BEGIN {print int($CPU_USAGE)}")
        TOTAL_CPU=$((TOTAL_CPU + CPU_INT))
        COUNT=$((COUNT + 1))
    done

    AVG_CPU=$((TOTAL_CPU / COUNT))
    echo "CPU Média de $APP: $AVG_CPU% (Replicas: $COUNT)"

    if [ "$AVG_CPU" -ge "$TARGET_CPU_PERCENT" ]; then
        if [ "$COUNT" -lt "$MAX_REPLICAS" ]; then
            NEXT_ID=$((COUNT + 1))
            echo "Escalonando (Scale UP) $APP para réplica ID $NEXT_ID..."
            systemctl --user start "$APP@$NEXT_ID.service"
        else
            echo "Max replicas atingido para $APP."
        fi
    elif [ "$AVG_CPU" -le 20 ]; then # Se menor que 20%, tenta diminuir
        if [ "$COUNT" -gt "$MIN_REPLICAS" ]; then
            echo "Reduzindo (Scale DOWN) $APP - Matando réplica ID $COUNT..."
            systemctl --user stop "$APP@$COUNT.service"
        fi
    fi
done
