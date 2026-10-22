#!/bin/sh
# Mede o consumo de RAM em repouso DENTRO do sistema Live ja inicializado. Somente leitura.
# Procedimento (docs/build-plan.md): VM com 4 GB, sessao XFCE aberta, nenhum aplicativo,
# aguardar 3 minutos antes de executar. Meta de TESTE: 1200 MB. Nao e garantia de resultado.
# Uso: sh measure-idle.sh [meta_em_MB]

target=${1:-1200}

total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
used_mb=$(( (total_kb - avail_kb) / 1024 ))

echo "== Memoria (MB): usado = MemTotal - MemAvailable"
echo "MemTotal=$((total_kb / 1024)) MemAvailable=$((avail_kb / 1024)) usado=${used_mb}"
free -m
echo
echo "== Maiores consumidores (RSS)"
ps -eo rss,comm --sort=-rss | head -n 15 | awk 'NR==1 {print; next} {printf "%7.1f MB  %s\n", $1/1024, $2}'
echo
echo "== Sistema de arquivos em RAM (overlay do Live)"
df -h / /tmp 2>/dev/null
echo
echo "== Servicos"
echo "Unidades com falha:"; systemctl --failed --no-legend || true
echo "Servicos habilitados: $(systemctl list-unit-files --type=service --state=enabled --no-legend | wc -l)"
echo
echo "== Portas escutando (esperado: nada em interfaces externas)"
ss -tulnH 2>/dev/null || ss -tuln
echo
echo "== Tempo de boot"
systemd-analyze 2>/dev/null || true
echo
if [ "$used_mb" -le "$target" ]; then
	echo "RESULTADO: ${used_mb} MB <= meta de teste ${target} MB (registrar em docs/test-reports/)"
	exit 0
fi
echo "RESULTADO: ${used_mb} MB > meta de teste ${target} MB (investigar consumidores acima)"
exit 1
