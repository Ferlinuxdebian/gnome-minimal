#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Lê config/imagem.conf e gera os arquivos consumidos pelo Containerfile.
#
# Uso no build (padrão):
#   bash /run/build-inputs/config/build/prepare-config.sh
#
# Uso local (para testar sem Podman):
#   CONFIG_DIR=config OUT_DIR=/tmp/gnome-minimal-build \
#     bash config/build/prepare-config.sh
#
# Saída em $OUT_DIR:
#   settings.env          -- IMAGE_NAME e as opções true/false
#   flatpaks              -- IDs dos Flatpaks, um por linha
#   flatpaks.preinstall   -- arquivo no formato do `flatpak preinstall`
#   pacotes               -- pacotes base, um por linha
#   pacotes-desktop       -- pacotes do ambiente gráfico, um por linha
# ----------------------------------------------------------------------------
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/run/build-inputs/config}"
OUT_DIR="${OUT_DIR:-/run/build-inputs/generated}"
CONF_FILE="${CONFIG_DIR}/imagem.conf"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "ERRO: arquivo de configuração não encontrado: $CONF_FILE" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

IMAGE_NAME=""
RPMFUSION="false"
TERRA="false"
NEGATIVO17="false"
SECTION=""
LINE_NO=0

: > "$OUT_DIR/flatpaks"
: > "$OUT_DIR/pacotes"
: > "$OUT_DIR/pacotes-desktop"

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

fail() {
    if (( LINE_NO > 0 )); then
        echo "ERRO (config/imagem.conf, linha ${LINE_NO}): $*" >&2
    else
        echo "ERRO (config/imagem.conf): $*" >&2
    fi
    exit 1
}

normalize_bool() {
    local key="$1"
    local value="${2,,}"

    case "$value" in
        true|1|yes|sim|on)   printf 'true' ;;
        false|0|no|nao|não|off|'') printf 'false' ;;
        *)
            fail "${key} deve ser true ou false (valor encontrado: '$2')."
            ;;
    esac
}

add_item() {
    local kind="$1"
    local item="$2"

    if [[ "$item" == *[[:space:]]* ]]; then
        fail "use um item por linha em [$kind] (encontrado: '$item')."
    fi

    case "$kind" in
        flatpaks)
            if [[ ! "$item" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
                fail "ID de Flatpak inválido: '$item'."
            fi
            printf '%s\n' "$item" >> "$OUT_DIR/flatpaks"
            ;;
        pacotes|pacotes-desktop)
            if [[ "$item" == *=* ]]; then
                fail "as opções (CHAVE=valor) devem ficar antes da primeira seção; '$item' está em [$kind]."
            fi
            printf '%s\n' "$item" >> "$OUT_DIR/$kind"
            ;;
    esac
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    LINE_NO=$((LINE_NO + 1))

    # Remove CR (arquivos editados no Windows), comentários e espaços nas pontas.
    line="${raw_line%$'\r'}"
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    # Cabeçalho de seção: [flatpaks], [pacotes], [pacotes-desktop].
    if [[ "$line" == \[*\] ]]; then
        SECTION="$(trim "${line:1:${#line}-2}")"
        SECTION="${SECTION,,}"
        case "$SECTION" in
            flatpak|flatpaks)                   SECTION="flatpaks" ;;
            pacote|pacotes|pacotes_necessarios) SECTION="pacotes" ;;
            pacotes-desktop|pacotes_desktop|desktop)
                                                SECTION="pacotes-desktop" ;;
            *)
                fail "seção desconhecida '[$SECTION]'. Use [flatpaks], [pacotes] ou [pacotes-desktop]."
                ;;
        esac
        continue
    fi

    # Antes da primeira seção ficam as opções gerais (CHAVE=valor).
    if [[ -z "$SECTION" ]]; then
        if [[ "$line" != *=* ]]; then
            fail "opção inválida '$line'. Use CHAVE=valor (ex.: RPMFUSION=true)."
        fi

        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"
        key="${key^^}"

        # Aceita valores entre aspas, por conveniência.
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
            value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
            value="${value:1:${#value}-2}"
        fi

        case "$key" in
            IMAGE_NAME|NOME_DA_IMAGEM)
                IMAGE_NAME="$value"
                ;;
            RPMFUSION|RPM_FUSION)
                RPMFUSION="$(normalize_bool "$key" "$value")"
                ;;
            TERRA)
                TERRA="$(normalize_bool "$key" "$value")"
                ;;
            NEGATIVO17|NEGATIVO_17)
                NEGATIVO17="$(normalize_bool "$key" "$value")"
                ;;
            *)
                fail "opção desconhecida '$key'. Opções válidas: IMAGE_NAME, RPMFUSION, TERRA, NEGATIVO17."
                ;;
        esac
        continue
    fi

    add_item "$SECTION" "$line"
done < "$CONF_FILE"

# ---------------------------------------------------------------------------
# Validações finais
# ---------------------------------------------------------------------------
if [[ -z "$IMAGE_NAME" ]]; then
    LINE_NO=0
    fail "IMAGE_NAME não foi definido."
fi

if [[ "$IMAGE_NAME" =~ [[:space:]] ]]; then
    LINE_NO=0
    fail "IMAGE_NAME não pode conter espaços."
fi

if [[ "$IMAGE_NAME" =~ [A-Z] ]]; then
    LINE_NO=0
    fail "IMAGE_NAME deve usar apenas letras minúsculas (valor: '$IMAGE_NAME')."
fi

if [[ ! "$IMAGE_NAME" =~ ^[a-z0-9][a-z0-9._-]*(\/[a-z0-9][a-z0-9._-]*)+$ ]]; then
    LINE_NO=0
    fail "IMAGE_NAME inválido: '$IMAGE_NAME'. Use o formato usuario/nome-da-imagem."
fi

# ---------------------------------------------------------------------------
# Gera o arquivo do flatpak preinstall
# ---------------------------------------------------------------------------
{
    echo "# Gerado automaticamente a partir de config/imagem.conf."
    echo "# Edite a seção [flatpaks] daquele arquivo, não este."
    echo
    while IFS= read -r app_id; do
        echo "[Flatpak Preinstall ${app_id}]"
        echo "Branch=stable"
        echo
    done < "$OUT_DIR/flatpaks"
} > "$OUT_DIR/flatpaks.preinstall"

# ---------------------------------------------------------------------------
# Gera as opções para o Containerfile
# ---------------------------------------------------------------------------
{
    printf 'IMAGE_NAME=%s\n' "$IMAGE_NAME"
    printf 'RPMFUSION=%s\n' "$RPMFUSION"
    printf 'TERRA=%s\n' "$TERRA"
    printf 'NEGATIVO17=%s\n' "$NEGATIVO17"
} > "$OUT_DIR/settings.env"

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
count_lines() {
    wc -l < "$1" | tr -d '[:space:]'
}

echo "Configuração lida de config/imagem.conf:"
echo "  imagem:            $IMAGE_NAME"
echo "  RPM Fusion:        $RPMFUSION"
echo "  Terra:             $TERRA"
echo "  Negativo17:        $NEGATIVO17"
echo "  Flatpaks:          $(count_lines "$OUT_DIR/flatpaks")"
echo "  Pacotes base:      $(count_lines "$OUT_DIR/pacotes")"
echo "  Pacotes do desk.:  $(count_lines "$OUT_DIR/pacotes-desktop")"
