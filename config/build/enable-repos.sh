#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Habilita APENAS a configuração dos repositórios extras escolhidos em
# config/imagem.conf.
#
# Este script NÃO instala pacotes. Ele apenas:
#   - baixa os arquivos .repo oficiais;
#   - instala as chaves GPG para o dnf poder verificar as assinaturas.
#
# Quem instala pacotes é o usuário, listando-os em [pacotes] ou
# [pacotes-desktop]. Assim, marcar RPMFUSION=true, por exemplo, não instala
# codecs, GStreamer nem qualquer outro pacote do repositório.
#
# Uso no build:
#   bash /run/build-inputs/config/build/enable-repos.sh
#
# Uso local (para inspecionar os arquivos sem alterar o sistema):
#   DESTDIR=/tmp/repo-test SKIP_RPM_IMPORT=1 \
#     SETTINGS_FILE=... bash config/build/enable-repos.sh
# ----------------------------------------------------------------------------
set -euo pipefail

SETTINGS_FILE="${SETTINGS_FILE:-/run/build-inputs/generated/settings.env}"
DESTDIR="${DESTDIR:-}"
SKIP_RPM_IMPORT="${SKIP_RPM_IMPORT:-0}"

DNF5_REPO_DIR="${DESTDIR}/usr/share/dnf5/repos.d"
YUM_REPO_DIR="${DESTDIR}/etc/yum.repos.d"
GPG_DIR="${DESTDIR}/usr/share/pki/rpm-gpg"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "ERRO: arquivo de configuração não encontrado: $SETTINGS_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$SETTINGS_FILE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

download() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 20 -o "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$url" "$dest" <<'PY'
import sys
from urllib.request import urlopen

url, dest = sys.argv[1], sys.argv[2]
with urlopen(url, timeout=60) as response, open(dest, "wb") as output:
    output.write(response.read())
PY
    else
        echo "ERRO: nenhum downloader disponível (curl, wget ou python3)." >&2
        exit 1
    fi
}

import_key() {
    local key_file="$1"

    if [[ "$SKIP_RPM_IMPORT" == "1" ]]; then
        return 0
    fi

    rpm --import "$key_file"
}

enable_rpmfusion() {
    local version repo rpm_file extract_dir
    version="$(rpm -E %fedora)"
    extract_dir="$TMP_DIR/rpmfusion"
    mkdir -p "$extract_dir"

    echo "→ Habilitando RPM Fusion (somente configuração do repositório)"

    for repo in free nonfree; do
        rpm_file="$TMP_DIR/rpmfusion-${repo}-release.rpm"
        download \
            "https://mirrors.rpmfusion.org/${repo}/fedora/rpmfusion-${repo}-release-${version}.noarch.rpm" \
            "$rpm_file"

        # Extrai os arquivos .repo e as chaves do RPM de configuração, sem
        # registrá-lo no banco de pacotes e sem instalar nenhum pacote.
        rpm2archive "$rpm_file" > "${rpm_file}.tgz"
        tar -xzf "${rpm_file}.tgz" -C "$extract_dir"
    done

    install -d -m755 "$DNF5_REPO_DIR"
    install -m644 "$extract_dir"/usr/share/dnf5/repos.d/*.repo "$DNF5_REPO_DIR/"

    install -d -m755 "$GPG_DIR"
    cp -a "$extract_dir"/usr/share/pki/rpm-gpg/. "$GPG_DIR/"

    # As chaves ficam disponíveis em /usr/share/pki/rpm-gpg e também são
    # importadas para o banco do RPM, para o dnf verificar as assinaturas.
    import_key "$GPG_DIR/RPM-GPG-KEY-rpmfusion-free-fedora-2020"
    import_key "$GPG_DIR/RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020"
}

enable_terra() {
    local version
    version="$(rpm -E %fedora)"

    echo "→ Habilitando Terra (somente configuração do repositório)"

    install -d -m755 "$YUM_REPO_DIR"
    download \
        "https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo" \
        "$YUM_REPO_DIR/terra.repo"

    download \
        "https://repos.fyralabs.com/terra${version}/key.asc" \
        "$TMP_DIR/terra-key.asc"
    import_key "$TMP_DIR/terra-key.asc"
}

enable_negativo17() {
    echo "→ Habilitando Negativo17 multimedia (somente configuração do repositório)"

    install -d -m755 "$YUM_REPO_DIR"
    download \
        "https://negativo17.org/repos/fedora-multimedia.repo" \
        "$YUM_REPO_DIR/fedora-multimedia.repo"

    download \
        "https://negativo17.org/repos/RPM-GPG-KEY-slaanesh" \
        "$TMP_DIR/negativo17-key.asc"
    import_key "$TMP_DIR/negativo17-key.asc"
}

if [[ "$RPMFUSION" == "true" && "$NEGATIVO17" == "true" ]]; then
    echo "ERRO: RPMFUSION e NEGATIVO17 não podem ser true ao mesmo tempo." >&2
    echo "Os dois fornecem pacotes GStreamer/codecs conflitantes. Escolha um." >&2
    exit 1
fi

[[ "$RPMFUSION" == "true" ]]  && enable_rpmfusion
[[ "$TERRA" == "true" ]]      && enable_terra
[[ "$NEGATIVO17" == "true" ]] && enable_negativo17

echo "Repositórios configurados. Nenhum pacote foi instalado por este passo."
