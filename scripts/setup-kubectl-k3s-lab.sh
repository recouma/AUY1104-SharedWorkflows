#!/usr/bin/env bash
# Configura kubectl en tu PC para el K3s del laboratorio EA2 (IP pública + kubeconfig vía SSH).
# Uso: ./scripts/setup-kubectl-k3s-lab.sh
# Requisitos: bash, ssh, sed, mktemp, kubectl. Clave .pem y acceso SSH a la VM (puerto 22).
set -euo pipefail

DEFAULT_SSH_USER="ubuntu"
DEFAULT_KUBECONFIG_DIR="${HOME}/.kube/lab-k3s"
DEFAULT_KUBECONFIG_FILE="${DEFAULT_KUBECONFIG_DIR}/k3s.yaml"
REMOTE_K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[0;33m'
NC='\033[0m'

die() { echo -e "${RED}Error:${NC} $*" >&2; exit 1; }
info() { echo -e "${GRN}✓${NC} $*"; }
warn() { echo -e "${YEL}!${NC} $*"; }

ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

validate_ipv4() {
  local ip="$1"
  [[ "$ip" =~ $ipv4_regex ]] || return 1
  local IFS='.'
  local -a oct
  read -ra oct <<< "$ip"
  local o
  for o in "${oct[@]}"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o <= 255 )) || return 1
  done
  return 0
}

expand_path() {
  local p="$1"
  # shellcheck disable=SC2088
  case "$p" in
    "~"|"~/"*) p="${p/#~/${HOME}}" ;;
  esac
  printf '%s' "$p"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Instala \"$1\" y vuelve a ejecutar este script."
}

require_cmd ssh
require_cmd sed
require_cmd mktemp

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Configuración de kubectl → K3s (EA2 · Learner Lab)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

require_cmd kubectl
info "kubectl encontrado: $(kubectl version --client 2>/dev/null | head -1 || kubectl version --client --output=yaml 2>/dev/null | head -3)"

echo ""
read -r -p "IP pública de la EC2 (ej. 34.231.243.56): " LAB_IP
LAB_IP="${LAB_IP// /}"
[[ -n "$LAB_IP" ]] || die "La IP no puede estar vacía."
validate_ipv4 "$LAB_IP" || die "No parece una IPv4 válida: $LAB_IP"

echo ""
read -r -p "Ruta absoluta o ~/... al archivo .pem de SSH: " PEM_INPUT
[[ -n "$PEM_INPUT" ]] || die "La ruta al PEM no puede estar vacía."
PEM_PATH="$(expand_path "$PEM_INPUT")"
[[ -f "$PEM_PATH" ]] || die "No existe el archivo: $PEM_PATH"

chmod 600 "$PEM_PATH" 2>/dev/null || true
info "Permisos del PEM ajustados a 600 (recomendado)."
[[ -r "$PEM_PATH" ]] || die "No se puede leer la clave: $PEM_PATH"

echo ""
read -r -p "Usuario SSH en la AMI [${DEFAULT_SSH_USER}]: " SSH_USER_INPUT
SSH_USER="${SSH_USER_INPUT:-$DEFAULT_SSH_USER}"

echo ""
read -r -p "Guardar kubeconfig local en [${DEFAULT_KUBECONFIG_FILE}]: " OUT_INPUT
OUT_FILE="$(expand_path "${OUT_INPUT:-$DEFAULT_KUBECONFIG_FILE}")"
OUT_DIR="$(dirname "$OUT_FILE")"

mkdir -p "$OUT_DIR"

BACKUP=""
if [[ -f "$OUT_FILE" ]]; then
  BACKUP="${OUT_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  warn "Ya existe $OUT_FILE — se creará respaldo en $BACKUP"
  cp -a "$OUT_FILE" "$BACKUP"
fi

echo ""
echo "Probando SSH (${SSH_USER}@${LAB_IP})..."
if ! ssh -i "$PEM_PATH" \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    -o BatchMode=yes \
    "${SSH_USER}@${LAB_IP}" 'echo ssh-ok' >/dev/null 2>&1; then
  die "SSH falló. Revisa: IP, PEM, Security Group (puerto 22), usuario (${SSH_USER})."
fi
info "SSH respondió correctamente."

echo ""
echo "Descargando ${REMOTE_K3S_KUBECONFIG} desde la VM..."
TMP_DL="$(mktemp)"
trap 'rm -f "$TMP_DL"' EXIT

if ! ssh -i "$PEM_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=30 \
    "${SSH_USER}@${LAB_IP}" "sudo cat ${REMOTE_K3S_KUBECONFIG}" >"$TMP_DL" 2>/dev/null; then
  die "No se pudo leer el kubeconfig en el servidor. ¿Está instalado K3s? (ruta ${REMOTE_K3S_KUBECONFIG})"
fi

[[ -s "$TMP_DL" ]] || die "El archivo descargado está vacío."

mv "$TMP_DL" "$OUT_FILE"
trap - EXIT
info "Kubeconfig guardado en: $OUT_FILE"

echo ""
echo "Ajustando server https://127.0.0.1:6443 → https://${LAB_IP}:6443 ..."
TMP_EDIT="$(mktemp)"
trap 'rm -f "$TMP_EDIT"' EXIT
if ! sed "s|https://127.0.0.1:6443|https://${LAB_IP}:6443|g" "$OUT_FILE" >"$TMP_EDIT"; then
  die "sed falló al editar el kubeconfig."
fi
mv "$TMP_EDIT" "$OUT_FILE"
trap - EXIT

SERVER_LINE="$(kubectl config view --kubeconfig "$OUT_FILE" --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
[[ -n "$SERVER_LINE" ]] || warn "No se pudo leer clusters[0].cluster.server con kubectl config view."
[[ "$SERVER_LINE" == "https://${LAB_IP}:6443" ]] && info "Server en kubeconfig: ${SERVER_LINE}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GRN}Listo.${NC} En esta terminal ejecuta:"
echo ""
echo "  export KUBECONFIG=\"${OUT_FILE}\""
echo "  kubectl get nodes"
echo "  kubectl cluster-info"
echo ""
warn "Si aparece error TLS (x509 / certificate … not ${LAB_IP}): la VM debe incluir esa IP en el certificado (--tls-san) o usar túnel SSH con 127.0.0.1. Ver docs/conexion-kubectl-k8s-lab/README.md"
warn "Si aparece timeout en :6443: el Security Group debe permitir TCP 6443 desde tu IP (o usar túnel SSH)."
echo ""
