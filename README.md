# Fedora Bootc GNOME Minimal

Uma imagem de sistema **atômico** baseada no **Fedora 45**, com um **GNOME
minimalista**, criada para servir de referência para quem está começando com
`bootc`.

A ideia deste repositório é ser simples e didático: mostrar, do começo ao fim,
como transformar um `Containerfile` em um sistema operacional instalável,
publicá-lo em um registro de imagens e atualizar a máquina trocando a imagem
inteira — com direito a rollback se algo der errado.

> Se você nunca ouviu falar em sistema atômico, imagem OCI ou `bootc`, leia a
> próxima seção. Ela explica os conceitos usados no resto do guia.

---

## 1. O que é um sistema atômico?

No Fedora tradicional, o sistema é uma pasta gigante onde cada instalação,
atualização ou remoção de pacote altera arquivos espalhados por `/usr`, `/etc`,
`/var` e por aí vai. Com o tempo, duas máquinas que "deveriam" ser iguais
acabam diferentes.

Em um **sistema atômico**, a base do sistema (`/usr`) vem de uma **imagem
pronta e versionada**. Atualizar não significa aplicar centenas de mudanças
soltas: significa **trocar a imagem inteira** por outra mais nova.

Duas comparações ajudam:

| Sistema tradicional | Sistema atômico |
| --- | --- |
| Você atualiza pacote por pacote | Você troca a imagem inteira |
| O sistema muda aos poucos | O sistema é substituído em bloco |
| Se a atualização quebrar, dá trabalho voltar | `bootc rollback` volta para a imagem anterior |
| Cada máquina fica um pouco diferente | Todas as máquinas com a mesma imagem são iguais |

### Imagem x sistema em execução

Essa distinção é a mais importante do guia:

- **Imagem**: um arquivo compactado (formato OCI, o mesmo dos contêineres) que
  contém o sistema de arquivos base. Ela é **somente leitura** e fica guardada
  no registro (por exemplo, o GHCR do GitHub).
- **Sistema em execução**: o que você vê ligado na máquina. Ele é montado a
  partir de uma imagem, mas tem camadas graváveis por cima.

Quando você roda `bootc switch` ou `bootc upgrade`, o `bootc` baixa uma nova
imagem e prepara a próxima inicialização. No reboot, o sistema sobe a partir
dela. A imagem antiga continua guardada para rollback.

### O que é preservado?

- `/usr` — vem da imagem e é **substituído** a cada atualização.
- `/etc` — suas configurações. O `bootc` faz merge das mudanças a cada update.
- `/var` — dados, logs, bancos, contêineres, flatpaks. **Persiste**.
- `/home` — seus arquivos. **Persiste**.

O `/usr` é montado como **somente leitura**. Não existe "editar `/usr`" na
máquina em execução: qualquer mudança permanente precisa entrar na imagem.
Já `/etc` e `/var` são graváveis e persistem entre atualizações.

### Por que isso importa para você?

Você deixa de configurar a máquina "na mão" e passa a **descrever** a máquina
em um arquivo. O resultado é reproduzível: a mesma receita gera o mesmo
sistema, hoje ou daqui a seis meses.

---

## 2. O que é o `bootc`?

`bootc` é a ferramenta que instala, atualiza e faz rollback de sistemas a
partir de imagens OCI. Ela roda dentro da própria imagem e conversa com o
gerenciador de boot do sistema.

Os comandos que você mais vai usar:

| Comando | O que faz |
| --- | --- |
| `bootc status` | Mostra a imagem atual, o digest e o histórico |
| `bootc switch <imagem>` | Troca a imagem de referência (ex.: passar a usar a sua) |
| `bootc upgrade` | Baixa a versão mais nova da imagem já configurada |
| `bootc upgrade --check` | Só verifica se existe atualização |
| `bootc rollback` | Volta para a imagem anterior |

`switch` e `upgrade` **preparam** a próxima inicialização. Para valer, é
preciso reiniciar.

### O `bootc container lint`

Toda imagem feita para `bootc` precisa seguir algumas regras: não deixar lixo
em `/run`, não usar links simbólicos que "escapem" da raiz da imagem, ter os
binários de runtime necessários, etc.

O comando abaixo valida tudo isso:

```bash
bootc container lint
```

Neste projeto ele roda no final do `Containerfile`. Se o lint falhar, o build
falha — e é melhor falhar no build do que descobrir o problema depois de
instalar.

---

## 3. O que vem na imagem

- Base: `quay.io/fedora/fedora-bootc:45`
- Kernel atualizado no build (`kernel*` + `kernel-modules-extra` na mesma versão); o restante do sistema vem da imagem base, reconstruída diariamente
- GNOME Shell minimalista
- Nautilus, Ptyxis e utilitários básicos do desktop
- Flatpak, Toolbox e Distrobox
- Compressão btrfs (`zstd:1`) e splash do Plymouth (`rhgb quiet`) habilitados pelos mesmos kargs
- Bazaar, Firefox e Extension Manager instalados no **primeiro boot** via `flatpak preinstall`

Os aplicativos não fazem parte da imagem: eles estão listados em
`config/flatpak/flatpaks.preinstall` e são baixados do Flathub no primeiro boot
pelo `post-install.service`, disparado pelo `post-install.timer` 10 segundos
após o `graphical.target`. Assim a imagem base continua pequena, os apps são
atualizados pelo próprio Flatpak e você não precisa rebuildar a imagem para
mudar a lista.

---

## 4. Conceitos que você vai encontrar

| Termo | Significado |
| --- | --- |
| **Imagem** | Sistema de arquivos empacotado no formato OCI. É o "produto final" do build. |
| **Containerfile** | Receita de build da imagem (igual a um Dockerfile). |
| **Camada (layer)** | Cada `RUN`, `COPY` ou `ADD` gera uma camada. O `bootc` usa camadas para baixar só o que mudou. |
| **Tag** | Apelido de uma imagem, como `latest` ou `45-20261105-0345`. |
| **Digest** | Identificador único e imutável de uma imagem (`sha256:...`). |
| **Registro** | Servidor que guarda imagens. Aqui usamos o **GHCR** (`ghcr.io`). |
| **Rechunk** | Reorganização das camadas da imagem para que as atualizações baixem menos dados. |
| **Deployment** | Uma "entrada" de sistema instalado. O `bootc` mantém a atual e a anterior para rollback. |
| **Flatpak** | Formato de aplicativo isolado, instalado fora da imagem base. |

---

## 5. Estrutura do projeto

```text
.
├── Containerfile                     # receita do build
├── config/                           # tudo que entra na imagem
│   ├── flatpak/
│   │   └── flatpaks.preinstall       # lista de apps do primeiro boot
│   ├── kernel/
│   │   └── 10-btrfs-compress.toml    # kargs de compressão btrfs e splash do Plymouth
│   ├── packages/
│   │   ├── pacotes_necessarios       # pacotes base do sistema
│   │   └── pacotes_desktop           # pacotes do ambiente gráfico
│   ├── system/
│   │   ├── locale.conf               # idioma e formato regional
│   │   ├── vconsole.conf             # teclado e console
│   │   └── zram-generator.conf       # swap comprimido na RAM
│   ├── systemd/
│   │   ├── post-install.service      # roda o flatpak preinstall no boot
│   │   └── post-install.timer        # dispara o serviço 10s após o graphical.target
│   └── tmpfiles/
│       └── tuned-log.conf            # tmpfiles.d do log do tuned-ppd
├── .github/workflows/build-image.yml # build e publicação automáticos
├── LICENSE.md                        # licença do projeto
└── README.md                         # esta documentação
```

| Pasta | Conteúdo |
| --- | --- |
| `config/flatpak/` | Lista de Flatpaks instalados no primeiro boot |
| `config/kernel/` | Argumentos de kernel aplicados pelo `bootc` (compressão btrfs e Plymouth) |
| `config/packages/` | Listas de pacotes do sistema e do ambiente gráfico |
| `config/system/` | Configurações de locale, teclado do console e swap em RAM (zram) |
| `config/systemd/` | Unidades systemd que instalam os Flatpaks após o `graphical.target` |
| `config/tmpfiles/` | Regra de `tmpfiles.d` que corrige o diretório de log do `tuned-ppd` |

| Arquivo | Para que serve |
| --- | --- |
| `Containerfile` | Define a imagem base, o que instalar e as configurações |
| `config/packages/pacotes_necessarios` | Lista de pacotes essenciais (um por linha) |
| `config/packages/pacotes_desktop` | Lista de pacotes do GNOME (um por linha) |
| `config/flatpak/flatpaks.preinstall` | Lista de Flatpaks instalados no primeiro boot (formato do `flatpak preinstall`) |
| `config/systemd/post-install.service` | Serviço systemd que espera a rede e roda `flatpak preinstall` |
| `config/systemd/post-install.timer` | Timer que dispara o serviço 10 segundos após o `graphical.target` |
| `config/kernel/10-btrfs-compress.toml` | Kargs da imagem: compressão `zstd:1` no btrfs e splash do Plymouth (`rhgb quiet`) |
| `config/tmpfiles/tuned-log.conf` | tmpfiles.d que cria e rotula `/var/log/tuned` a cada boot |
| `config/system/locale.conf` | Idioma padrão (`pt_BR.UTF-8`) |
| `config/system/vconsole.conf` | Layout de teclado do console |
| `config/system/zram-generator.conf` | Cria swap comprimido em RAM |
| `.github/workflows/build-image.yml` | GitHub Actions: builda, otimiza e publica no GHCR |
| `LICENSE.md` | Licença do projeto (CC BY 4.0) |
| `README.md` | Documentação do projeto |

---

## 6. Como o `Containerfile` funciona

O arquivo tem poucas etapas. Entender cada uma é o suficiente para
personalizar quase tudo.

### `FROM`

```dockerfile
FROM quay.io/fedora/fedora-bootc:45
```

Toda imagem começa de outra imagem. Aqui partimos da imagem oficial do Fedora
preparada para `bootc`.

### `COPY`

```dockerfile
COPY config/ /run/build-inputs/config/
```

Copia a pasta `config/` do repositório para dentro do build, em
`/run/build-inputs/config/`. Cada etapa seguinte usa `install -Dm644` para
colocar cada arquivo no lugar definitivo com as permissões corretas. No fim do
build a pasta `/run/build-inputs` é removida para não deixar sobras em `/run`.

### `RUN`

Cada `RUN` executa comandos durante o build. Neste projeto eles fazem, em
ordem:

1. Atualizam **somente os pacotes de kernel** e instalam o `kernel-modules-extra`
   na mesma versão (o restante do sistema vem da imagem base, que é
   reconstruída diariamente);
2. Instalam os arquivos de configuração em `/etc` e `/usr`, o karg de
   compressão btrfs e o `tuned-log.conf`;
3. Criam `/opt` e `/usr/local` como links **relativos** para `/var`
   (para que esses diretórios persistam entre atualizações);
4. Instalam o `flatpaks.preinstall`, o `post-install.service` e o
   `post-install.timer`, e habilitam o timer;
5. Instalam o GNOME Shell em um bloco próprio, sem dependências fracas;
6. Instalam os pacotes das duas listas;
7. Limpam caches e diretórios temporários;
8. Rodam o `bootc container lint`.

> **Detalhe importante:** os links usam `ln -vrs`, com `r` de *relative*.
> Links absolutos (`/usr/local -> /var/usrlocal`) apontam para fora da raiz da
> imagem e fazem o lint falhar com `a path led outside of the filesystem`.

### Sobre as camadas

Cada `RUN` vira uma camada. Por isso os passos pesados (atualização e
instalação de pacotes) ficam separados das configurações finais: se você mudar
só uma configuração, o build reaproveita as camadas anteriores.

### Por que atualizar só o kernel?

A tag `quay.io/fedora/fedora-bootc:45` é reconstruída diariamente e já entrega
o restante do sistema atualizado. Rodar um `dnf upgrade` completo na imagem
criaria uma camada grande e volátil, que o `bootc upgrade` teria de baixar de
novo a cada atualização. Por isso o build atualiza apenas `'kernel*'` e instala
o `kernel-modules-extra` na **mesma versão** do kernel recém-atualizado,
evitando descompasso entre o kernel e os módulos extras.

### Por que limpar `/run` e `/tmp`?

O lint avisa quando encontra conteúdo em `/run` ou `/tmp` (`nonempty-run-tmp`),
porque essas pastas são recriadas a cada boot. Sobras de `dnf`, de políticas
SELinux e a própria pasta `/run/build-inputs` (usada para levar os arquivos de
`config/` até o lugar definitivo) aparecem ali durante o build, então são
removidas antes do lint.

### Flatpaks do primeiro boot

A imagem **não** instala aplicativos durante o build. Ela apenas deixa uma
lista em `/usr/share/flatpak/preinstall.d/flatpaks.preinstall`. O
`post-install.timer` é habilitado em `graphical.target` e dispara o
`post-install.service` 10 segundos depois que o desktop termina de subir.
Assim o boot não fica esperando download e a instalação começa com o sistema
já utilizável. O serviço então:

1. espera a rede ficar online pelo `NetworkManager-wait-online.service`;
2. troca o remote `fedora` pelo `flathub`;
3. roda `flatpak preinstall --system -y --noninteractive`.

Se a rede ou o Flathub falharem, o serviço tenta de novo a cada 60 segundos
(`Restart=on-failure`) e, se ainda assim não terminar, roda outra vez no
próximo boot junto com o timer.

Esse comando é **idempotente e sincronizador**: instala o que falta, não mexe
no que já existe e respeita apps que o usuário removeu. Se você adicionar um
app à lista e publicar uma nova imagem, o próximo boot instala só a diferença.

É por isso que ele é mais eficiente do que um script com vários
`flatpak install`: uma única chamada resolve a lista inteira, sem repetir
trabalho a cada boot.

### Kargs: compressão btrfs e splash do Plymouth

O arquivo `10-btrfs-compress.toml` é instalado em `/usr/lib/bootc/kargs.d/` e
reúne, em um único lugar, todos os argumentos de kernel da imagem:

```toml
kargs = ["rootflags=compress=zstd:1", "rhgb", "quiet"]
```

- `rootflags=compress=zstd:1` ativa a compressão zstd nível 1 no btrfs da raiz.
  Arquivos que já existiam continuam sem compressão até serem reescritos.
- `rhgb` faz o Plymouth mostrar o splash gráfico em vez do console. O
  `pacotes_desktop` instala o Plymouth, mas sem este argumento ele fica inativo.
- `quiet` esconde as mensagens do kernel e dos serviços durante o boot.

Manter tudo no mesmo arquivo de `kargs.d` simplifica a manutenção: em vez de
criar um arquivo para cada argumento, basta editar esta lista. O `bootc` aplica
os kargs ao instalar e a cada `bootc upgrade`/`switch`. Em uma máquina que já
está instalada, a mudança só aparece depois de atualizar para uma imagem que
contenha o arquivo e reiniciar — não basta editá-lo no sistema em execução,
porque `/usr` é somente leitura.

### tuned e tuned-ppd

A imagem inclui `tuned` e `tuned-ppd` e habilita os dois serviços.

O `tuned-ppd` grava o log em `/var/log/tuned/tuned-ppd.log`. Esse diretório
precisa ter o contexto SELinux `tuned_log_t`. O RPM do `tuned` entrega o
diretório, mas `/var` é criado na instalação e persiste entre atualizações —
se o diretório for recriado em runtime, nasce como `var_log_t` e o serviço
falha ao escrever o log (sai com status 1).

Para resolver isso de forma permanente, o arquivo `tuned-log.conf` é
instalado em `/usr/lib/tmpfiles.d/`:

```text
d /var/log/tuned 0755 root root -
Z /var/log/tuned - - - -
```

O `systemd-tmpfiles` roda a cada boot antes dos serviços: o `d` garante que o
diretório exista e o `Z` reaplica o contexto correto (`tuned_log_t`). Como o
arquivo vem da imagem, a correção também vale para máquinas que apenas fazem
`bootc upgrade`.

---

## 7. Passo a passo: crie a sua versão

### 7.1 Pré-requisitos

- Conta no GitHub (para o fork e para o GHCR).
- Opcional: uma máquina Fedora com `podman` para testar o build localmente.
  Se não tiver, pode deixar o build só no GitHub Actions.

### 7.2 Faça um fork e clone

Faça o fork no GitHub e clone o **seu** repositório:

```bash
git clone https://github.com/SEU-USUARIO/gnome-minimal.git
cd gnome-minimal
```

### 7.3 Ajuste o nome da imagem

Abra `.github/workflows/build-image.yml` e troque:

```yaml
env:
  IMAGE_NAME: ferlinuxdebian/gnome-minimal
```

por:

```yaml
env:
  IMAGE_NAME: SEU-USUARIO/gnome-minimal
```

O nome precisa ser **minúsculo** e seguir o padrão do GHCR:
`usuario/nome-da-imagem`.

### 7.4 Escolha os pacotes

Quase toda personalização começa em dois arquivos:

- **`config/packages/pacotes_necessarios`** — base do sistema, ferramentas e serviços.
- **`config/packages/pacotes_desktop`** — tudo que é do ambiente gráfico.

Cada linha é um pacote. Linhas com `#` são comentários. Exemplo:

```text
htop
fastfetch
neovim
```

O `gnome-shell` fica em `config/packages/pacotes_desktop`, mas é instalado em
um passo próprio do `Containerfile`, com `--setopt=install_weak_deps=False`
(só dependências obrigatórias). O restante da lista é instalado normalmente,
com as dependências fracas habilitadas.

O `Containerfile` procura `gnome-shell` na lista antes de rodar esse passo.
Se a linha existir, instala o GNOME sem dependências fracas; se não existir,
o passo é ignorado automaticamente.

> **Para trocar de ambiente gráfico:** substitua os pacotes do GNOME pelos do
> novo ambiente (KDE, XFCE etc.) em `config/packages/pacotes_desktop`. Ao
> remover a linha `gnome-shell`, o passo do GNOME no `Containerfile` deixa de
> rodar — não é preciso editar o `Containerfile`.

Para descobrir o nome exato de um pacote no Fedora:

```bash
dnf5 search nome-do-pacote
```

> **Atenção:** um nome errado derruba o build com
> `No match for argument`. Confira antes de enviar.

### 7.5 Personalize o sistema

- **Idioma:** `config/system/locale.conf`
- **Teclado do console:** `config/system/vconsole.conf`
- **Swap em RAM:** `config/system/zram-generator.conf`
- **Flatpaks do primeiro boot:** `config/flatpak/flatpaks.preinstall` (lista),
  `config/systemd/post-install.service` (quem executa) e
  `config/systemd/post-install.timer` (quando executa)
- **Argumentos de kernel:** `config/kernel/10-btrfs-compress.toml` (compressão btrfs)
- **Log do `tuned-ppd`:** `config/tmpfiles/tuned-log.conf` (diretório e contexto SELinux)
- **Arquivos novos:** adicione o arquivo na pasta `config/` mais adequada e um
  `install -Dm644` no `Containerfile` para o destino final dentro de um `RUN`

### 7.6 Teste o build localmente (opcional, mas recomendado)

```bash
sudo podman build \
  --security-opt label=disable \
  -t localhost/gnome-minimal:test \
  -f Containerfile .
```

O parâmetro `--security-opt label=disable` evita problemas de SELinux durante o
build. Se o lint passar, a imagem está consistente.

Para abrir um shell dentro da imagem e conferir pacotes:

```bash
sudo podman run --rm -it localhost/gnome-minimal:test bash
```

Dentro dele você pode rodar, por exemplo:

```bash
rpm -q gnome-shell
bootc container lint
```

### 7.7 Publique no GHCR

```bash
git add -A
git commit -m "Minha personalização"
git push origin main
```

O GitHub Actions vai:

1. buildar a imagem;
2. otimizar as camadas com `bootc-base-imagectl rechunk`;
3. publicar em `ghcr.io/SEU-USUARIO/gnome-minimal`;
4. criar as tags `latest`, `main`, `45-latest` e `sha-<commit>`.

Acompanhe em **Actions** no GitHub. No fim, a imagem aparece em **Packages**.

### 7.8 Deixe o pacote público (ou faça login)

Por padrão, pacotes do GHCR podem ficar privados. Para instalar sem login:

1. Abra **Packages** no seu perfil do GitHub;
2. Entre em `gnome-minimal`;
3. **Package settings** → **Change visibility** → **Public**.

Se preferir manter privado, faça login na máquina que vai instalar:

```bash
podman login ghcr.io
```

### 7.9 Instale a sua imagem

Em uma máquina que já usa `bootc` (Fedora Silverblue, Kinoite, outra imagem
bootc, etc.):

```bash
sudo bootc switch ghcr.io/SEU-USUARIO/gnome-minimal:latest
sudo systemctl reboot
```

Após o reboot, confira:

```bash
bootc status
```

Você verá a imagem e o digest em uso.

> **Dica de segurança:** teste primeiro em uma máquina virtual. O repositório
> [anaconda-webui-bootc-installer](https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer)
> gera uma ISO que instala a imagem do zero em VM ou hardware real.

### 7.10 Atualize depois de mudar algo

Sempre que você alterar o repositório e fizer push, uma nova imagem é
publicada. Na máquina:

```bash
sudo bootc upgrade --check   # existe versão nova?
sudo bootc upgrade           # baixa e prepara
sudo systemctl reboot        # aplica
```

---

## 8. Atualização, inspeção e rollback

```bash
# Ver a imagem atual, o digest e o deployment anterior
bootc status

# Verificar se há atualização disponível
sudo bootc upgrade --check

# Aplicar a atualização
sudo bootc upgrade
sudo systemctl reboot

# Voltar para a imagem anterior
sudo bootc rollback
sudo systemctl reboot
```

O rollback é a maior vantagem do sistema atômico: a imagem anterior continua
no disco. Se uma atualização quebrar o boot ou um driver, você volta em um
comando, sem reinstalar nada.

---

## 9. Cuidados importantes

- **`/usr` é somente leitura.** O sistema monta `/usr` como read-only; não há
  como alterá-lo na máquina em execução. Toda mudança permanente entra na
  imagem, neste repositório.
- **Não instale pacotes com `dnf install` no sistema rodando.** O lugar certo
  é a imagem ou um Flatpak.
- **`/etc` e `/var` persistem.** Configurações e dados ficam, mas evite
  depender de ajustes manuais que não estejam documentados na imagem.
- **Teste em VM antes de trocar a máquina principal.**
- **Cada push na `main` gera uma imagem.** Se quiser testar sem publicar,
  use um branch e ajuste o workflow, ou faça o build local.
- **O build precisa de espaço em disco.** O passo de limpeza no topo do
  workflow existe para isso.

---

## 10. Problemas comuns

**`No match for argument: <pacote>`**
O pacote não existe no Fedora 45 ou o nome está errado. Confira com
`dnf5 search`.

**`Linting: Unexpected runtime error running lint runtime-deps: ... a path led outside of the filesystem`**
Algum link simbólico dentro da imagem aponta para fora da raiz. Use links
relativos (`ln -vrs`), como no `Containerfile` deste projeto.

**`Lint warning: nonempty-run-tmp`**
Sobrou conteúdo em `/run` ou `/tmp`. Remova esses arquivos antes do
`bootc container lint` (o projeto já faz isso com `/run/dnf` e
`/run/selinux-policy`).

**`bootc switch` pede login**
A imagem está privada. Torne o pacote público no GitHub ou rode
`podman login ghcr.io`.

**O workflow falha no login do GHCR**
Verifique se `permissions: packages: write` está presente no job e se o
pacote ainda não existe com outro dono.

**A máquina não sobe depois do switch**
No menu do bootloader, selecione a entrada anterior, ou rode
`sudo bootc rollback` a partir de um sistema de recuperação.

**`tuned-ppd.service` aparece como failed**
O sintoma clássico é o contexto SELinux de `/var/log/tuned`:

```bash
ls -Zd /var/log/tuned
```

Se aparecer `var_log_t` em vez de `tuned_log_t`, o `tuned-ppd` não consegue
escrever o log e sai com status 1. A imagem nova corrige isso sozinha no boot
seguinte depois do upgrade, porque o `tuned-log.conf` reaplica o contexto via
`systemd-tmpfiles`. Para corrigir na hora, sem esperar o upgrade:

```bash
sudo restorecon -Rv /var/log/tuned
sudo systemctl reset-failed tuned-ppd.service
sudo systemctl restart tuned-ppd.service
```

Para ver o erro real, não use `-p err` — o traceback do Python é registrado
com prioridade `info`:

```bash
journalctl -u tuned-ppd.service -b --no-pager
```

Se aparecer `TuneD not found on the DBus`, o problema é o `tuned.service`:

```bash
systemctl status tuned.service
journalctl -u tuned.service -b --no-pager
```

**Os Flatpaks não instalaram no primeiro boot**
O `post-install.timer` dispara o `post-install.service` 10 segundos depois do
`graphical.target`. O serviço espera a rede e roda `flatpak preinstall`; a
primeira execução baixa os três apps e pode demorar alguns minutos. Verifique:

```bash
systemctl status post-install.timer
systemctl status post-install.service
journalctl -u post-install.service -b
flatpak list --system
```

Se a rede ainda não estiver disponível, o serviço tenta de novo a cada 60
segundos; ele também roda outra vez no próximo boot junto com o timer. Para
forçar manualmente:

```bash
sudo flatpak preinstall --system -y --noninteractive
```

Se o timer estiver inativo, confira se ele está habilitado para o
`graphical.target`:

```bash
systemctl is-enabled post-install.timer
systemctl list-timers post-install.timer
```

Se um app não existir mais no Flathub, o `preinstall` falha naquele item.
Confira o ID em `config/flatpak/flatpaks.preinstall` e remova ou corrija a
linha.

---

## 11. Gerando uma ISO de instalação

A geração de ISO **não fica neste repositório**. Use o projeto dedicado, que
usa o Anaconda WebUI para instalar uma imagem `bootc` em disco:

**https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer**

```bash
git clone https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer.git
cd anaconda-webui-bootc-installer

sudo just build ghcr.io/SEU-USUARIO/gnome-minimal:latest
sudo just create-iso
```

É a forma mais simples de testar a sua imagem em uma máquina virtual.

---

## 12. Próximos passos

- **Assinatura e verificação de imagens bootc:**
  https://github.com/Ferlinuxdebian/bootc-gnome-minimal-f45
- **ISO com Anaconda WebUI:**
  https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer
- **Documentação oficial do bootc:**
  https://bootc.dev

---

## 13. Glossário rápido

- **Atômico**: sistema cuja base é trocada em bloco, não pacote a pacote.
- **bootc**: ferramenta que instala e atualiza sistemas a partir de imagens OCI.
- **Containerfile**: receita de build da imagem.
- **Digest**: identificador imutável de uma imagem (`sha256:...`).
- **GHCR**: GitHub Container Registry, onde as imagens são publicadas.
- **Imagem OCI**: pacote padronizado com o sistema de arquivos base.
- **Lint**: validação automática das regras de uma imagem bootc.
- **Rechunk**: reorganização de camadas para reduzir o download de updates.
- **Rollback**: voltar para o deployment anterior.
- **Tag**: apelido móvel de uma imagem, como `latest`.

---

## Licença

CC BY 4.0 — veja `LICENSE.md`.
