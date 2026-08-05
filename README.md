## Fedora Bootc GNOME Minimal

Este repositório contém uma imagem personalizada baseada no fedora-boot imagem oficial, usando o conceito de sistemas imutáveis com bootc.

A proposta do projeto é ser simples e didática, ajudando iniciantes a aprender como criar suas próprias imagens de sistema personalizadas com bootc.

A imagem utiliza um ambiente GNOME extremamente minimalista, trazendo apenas o básico para iniciar o sistema e permitindo que o próprio usuário escolha os aplicativos que deseja instalar depois.

## O que acompanha a imagem

A instalação inclui apenas:

* GNOME Shell
* A loja de software é o Bazaar (flatpak)
* Firefox (flatpak)
* Extension Manager (Flatpak)
* Nautilus
* Terminal Ptxys
* Distrobox
* Toolbox

Aplicativos como navegador, suíte office, players de mídia e outros programas não vêm instalados por padrão.
A ideia é deixar o sistema limpo e permitir que cada usuário monte seu próprio desktop.

## Objetivo do projeto

Este projeto foi criado para:

* Aprender sobre bootc
* Entender como funcionam imagens OCI inicializáveis
* Criar sistemas personalizados baseados no Fedora
* Gerar ISOs de instalação próprias
* Explorar sistemas imutáveis de forma simples

## Base da imagem

* Base: `fedora-bootc`
* Interface: GNOME Minimal
* Sistema: Imutável via bootc
* Distribuição base: Fedora Project
* Formato de distribuição: Imagem OCI inicializável
* Instalação: ISO personalizada inclusa no projeto

## Estrutura dos arquivos

| Arquivo                | Função                                          |
| ---------------------- | ----------------------------------------------- |
| `Containerfile`        | Define como a imagem é construída               |
| `pacotes_desktop`      | Lista dos pacotes do ambiente gráfico           |
| `pacotes_necessarios`  | Pacotes essenciais do sistema                   |
| `post-install.sh`      | Script executado no primeiro boot               |
| `post-install.service` | Serviço systemd responsável pelo pós-instalação |
| `config.toml`          | Configuração usada para gerar a ISO             |
| `locale.conf`          | Configuração regional pt-BR                     |
| `vconsole.conf`        | Configuração do terminal TTY                    |
| `zram-generator.conf`  | Configuração de zram                            |
| `.github/workflows`    | Automação de builds via GitHub Actions          |

## Atualizando o sistema

```bash id="yq8yxv"
# Verificar atualizações
sudo bootc upgrade --check

# Aplicar atualização
sudo bootc upgrade

# Reiniciar o sistema
sudo reboot
```

## Comandos úteis

```bash id="yq0x9j"
# Ver informações da imagem atual
bootc status

# Voltar para a imagem anterior
sudo bootc rollback
```

## Aviso sobre bootc switch

Agora é possível realizar o bootc switch diretamente a partir do Fedora Silverblue para esta imagem.

```
sudo bootc switch ghcr.io/ferlinuxdebian/gnome-minimal:latest
```

## Clonando o projeto

```bash id="66d9r8"
git clone https://github.com/Ferlinuxdebian/gnome-minimal.git
cd gnome-minimal
```

## Build local da imagem

```bash id="i8ls7u"
sudo buildah build \
    --skip-unused-stages=false \
    --security-opt=label=disable \
    -t "gnome-minimal" \
    -f Containerfile \
    -v $(pwd):/run/src \
    .
```

## Gerando a ISO de instalação

```bash id="eolam0"
mkdir -p output

sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v ./config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type anaconda-iso \
    --rootfs btrfs \
    localhost/gnome-minimal
```

## Download da ISO pelo GitHub Actions

Este repositório também gera automaticamente a ISO através do GitHub Actions.

Para baixar a ISO gerada automaticamente:

1. Abra a aba `Actions` do repositório
2. Entre no workflow desejado
3. Aguarde o build finalizar
4. Role até a seção `Artifacts`
5. Baixe o artefato contendo a ISO

![Fedora Bootc GNOME Minimal](https://i.imgur.com/cYXwJIl.png)

## Sobre o projeto

O foco deste repositório não é entregar um sistema cheio de aplicativos prontos, mas sim servir como base de aprendizado para quem deseja entender melhor o ecossistema bootc e começar a criar suas próprias imagens de sistema personalizadas.
