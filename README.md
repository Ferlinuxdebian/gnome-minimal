# Fedora Bootc GNOME Minimal

Uma imagem de sistema atômico baseada no **Fedora 45** com **GNOME minimalista**, feita para quem quer aprender `bootc` na prática.

Este repositório é uma **referência para iniciantes**: mostra, do jeito mais simples possível, como montar uma imagem OCI inicializável, publicá-la no GHCR e instalar ou atualizar o sistema com `bootc`.

> **Sistema atômico:** a base do sistema é imutável. Você atualiza trocando a imagem inteira, e pode voltar para a versão anterior se algo der errado.

## O que vem na imagem

- Fedora 45 (`fedora-bootc`)
- GNOME Shell minimalista
- Nautilus, Ptyxis e utilitários básicos
- Som funcionando no GNOME (PipeWire + backends do libcanberra)
- `usbutils` (`lsusb`) e `pciutils` (`lspci`)
- Flatpak, Toolbox e Distrobox
- Bazaar, Firefox e Extension Manager instalados no primeiro boot via Flatpak

Navegador, suíte office, players de mídia e outros aplicativos **não** vêm instalados. A ideia é deixar o sistema limpo e permitir que cada usuário monte o desktop depois.

## Instalando a imagem pronta

Se você só quer usar a imagem já publicada:

```bash
sudo bootc switch ghcr.io/ferlinuxdebian/gnome-minimal:latest
sudo systemctl reboot
```

Funciona a partir do Fedora Silverblue/Kinoite ou de qualquer sistema que já use `bootc`.

## Estrutura do projeto

| Arquivo | Para que serve |
| --- | --- |
| `Containerfile` | Receita do build: imagem base, pacotes e configurações |
| `pacotes_necessarios` | Pacotes essenciais do sistema e ferramentas |
| `pacotes_desktop` | Pacotes do ambiente gráfico (GNOME) |
| `post-install.sh` | Script executado no primeiro boot (instala Flatpaks) |
| `post-install.service` | Serviço systemd que roda o script no primeiro boot |
| `locale.conf` | Idioma e formato regional (pt-BR) |
| `vconsole.conf` | Teclado e console (pt-BR) |
| `zram-generator.conf` | Swap comprimido na RAM (zram) |
| `.github/workflows/build-image.yml` | Build automático e publicação no GHCR |

## Como o Containerfile funciona

O build tem poucas etapas:

1. `FROM quay.io/fedora/fedora-bootc:45` — parte da imagem oficial do Fedora.
2. `COPY` — copia as listas de pacotes e arquivos de configuração para dentro do build.
3. `RUN dnf5 install` — instala o GNOME e os pacotes das listas.
4. `RUN bootc container lint` — valida se a imagem está apta a virar um sistema bootc.

Cada `RUN` vira uma camada da imagem. Por isso as listas de pacotes e os arquivos de configuração são copiados uma única vez.

## Criando a sua própria versão

### 1. Faça um fork e clone

Faça o fork no GitHub e clone o seu:

```bash
git clone https://github.com/SEU-USUARIO/gnome-minimal.git
cd gnome-minimal
```

### 2. Ajuste o nome da imagem no workflow

Abra `.github/workflows/build-image.yml` e troque:

```yaml
env:
  IMAGE_NAME: ferlinuxdebian/gnome-minimal
```

pelo caminho do seu repositório:

```yaml
env:
  IMAGE_NAME: SEU-USUARIO/gnome-minimal
```

### 3. Escolha os pacotes

Quase toda personalização começa em dois arquivos:

- **`pacotes_necessarios`** — base do sistema, ferramentas e serviços.
- **`pacotes_desktop`** — tudo que é do ambiente gráfico.

Cada linha é um pacote. Linhas que começam com `#` são comentários. Exemplo:

```text
htop
fastfetch
pciutils
```

Para descobrir o nome exato de um pacote no Fedora:

```bash
dnf5 search nome-do-pacote
```

### 4. Personalize o sistema

- **Idioma e teclado:** `locale.conf` e `vconsole.conf`.
- **Memória comprimida:** `zram-generator.conf`.
- **Primeiro boot:** `post-install.sh` e `post-install.service`.
- **Arquivos novos:** adicione o `COPY` e o comando de instalação no `Containerfile`.

### 5. Teste o build localmente

```bash
sudo podman build \
  --security-opt label=disable \
  -t localhost/gnome-minimal \
  -f Containerfile .
```

Se quiser abrir um shell dentro da imagem para conferir pacotes:

```bash
podman run --rm -it localhost/gnome-minimal bash
```

### 6. Publique no GHCR

```bash
git add -A
git commit -m "Minha personalização"
git push origin main
```

O GitHub Actions vai buildar, otimizar a imagem com `bootc-base-imagectl` e publicar em:

```text
ghcr.io/SEU-USUARIO/gnome-minimal:latest
```

Se o pacote ficar privado, torne-o público em **Packages** no GitHub, ou faça login na máquina:

```bash
podman login ghcr.io
```

### 7. Instale ou atualize

Na máquina onde você quer usar a sua imagem:

```bash
sudo bootc switch ghcr.io/SEU-USUARIO/gnome-minimal:latest
sudo systemctl reboot
```

Depois, para receber novas versões:

```bash
sudo bootc upgrade
sudo systemctl reboot
```

## Atualização e rollback

```bash
# Ver se há atualização disponível
sudo bootc upgrade --check

# Aplicar a atualização
sudo bootc upgrade

# Ver a imagem atual e o histórico
bootc status

# Voltar para a versão anterior
sudo bootc rollback
```

O rollback é uma das maiores vantagens do sistema atômico: se uma atualização quebrar algo, você volta para a imagem anterior sem reinstalar nada.

## Gerando uma ISO de instalação

A geração de ISO **não fica mais neste repositório**. Use:

**https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer**

```bash
git clone https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer.git
cd anaconda-webui-bootc-installer

sudo just build ghcr.io/SEU-USUARIO/gnome-minimal:latest
sudo just create-iso
```

O repositório da ISO usa o Anaconda WebUI e instala a imagem escolhida via `bootc`.

## Problemas comuns

**O build falha com "No match for argument"**
O nome do pacote está errado ou não existe no Fedora 45. Confira com `dnf5 search`.

**`bootc switch` pede login**
A imagem está privada. Torne o pacote público no GitHub ou rode `podman login ghcr.io`.

**Sem som no GNOME**
Confira se os backends continuam em `pacotes_desktop`:

```text
libcanberra-backend-pulse
libcanberra-backend-gstreamer
libcanberra-backend-alsa
```

O grupo `@multimedia` já instala o PipeWire e o WirePlumber.

**Flatpaks não instalaram no primeiro boot**
O `post-install.service` precisa de rede. Verifique:

```bash
systemctl status post-install.service
journalctl -u post-install.service
```

**Preciso de `lspci` ou `lsusb`**
Eles vêm de `pciutils` e `usbutils`, já incluídos em `pacotes_necessarios`.

## Próximos passos

- **Assinatura e verificação da imagem:**
  https://github.com/Ferlinuxdebian/bootc-gnome-minimal-f45
- **ISO com Anaconda WebUI:**
  https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer

## Licença

CC BY 4.0 — veja `LICENSE.md`.
