# Imagem única para montar uma instalação mínima do Fedora 45 com interface gráfica GNOME
FROM quay.io/fedora/fedora-bootc:45
COPY locale.conf flatpaks.preinstall pacotes_desktop pacotes_necessarios post-install.service vconsole.conf zram-generator.conf 10-btrfs-compress.toml tuned-ppd-retry.conf ./

RUN mkdir -vp /var/roothome /data /var/home && \
    dnf5 -y upgrade --refresh --setopt=tsflags=nodocs && \
    dnf5 -y install kernel-modules-extra wget --refresh --setopt=tsflags=nodocs && \
    # Configurações de sistema
    mv -v zram-generator.conf /usr/lib/systemd/zram-generator.conf.d/10-zram.conf || mv -v zram-generator.conf /etc/systemd/ && \
    mv -v vconsole.conf /etc/vconsole.conf && \
    mv -v locale.conf /etc/locale.conf && \
    # Organização de diretórios e links simbólicos para persistência.
    # Os links precisam ser RELATIVOS (ln -r). Links absolutos apontam para
    # fora da raiz da imagem e o `bootc container lint` falha.
    rm -rvf /opt && mkdir -vp /var/opt && ln -vrs /var/opt /opt && \
    mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null && \
    rm -rvf /usr/local && ln -vrs /var/usrlocal /usr/local && \
    # Flatpaks do primeiro boot e serviço que os instala
    install -Dm644 flatpaks.preinstall /usr/share/flatpak/preinstall.d/flatpaks.preinstall && \
    install -Dm644 post-install.service /usr/lib/systemd/system/post-install.service && \
    # Compressão btrfs na raiz e retry do tuned-ppd
    install -Dm644 10-btrfs-compress.toml /usr/lib/bootc/kargs.d/10-btrfs-compress.toml && \
    install -Dm644 tuned-ppd-retry.conf /etc/systemd/system/tuned-ppd.service.d/10-retry.conf && \
    systemctl enable post-install.service && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/*

# 3. Pacotes base do ambiente gráfico GNOME Minimalista (REMOVA ESSE BLOCO SE FOR USAR OUTRA INTERFACE GRÁFICA)
# E coloque os pacotes da outra interface no arquivo pacotes_desktop
RUN dnf5 install gnome-shell --setopt=tsflags=nodocs --setopt=install_weak_deps=False -y && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/dnf/* /var/log/* /tmp/* /var/tmp/*

# Instalação dos pacotes definidos nos arquivos de lista
RUN grep -v '^#' pacotes_necessarios | tr '\n' ' ' | xargs dnf5 install --setopt=tsflags=nodocs -y && \
    grep -v '^#' pacotes_desktop | tr '\n' ' ' | xargs dnf5 install --setopt=tsflags=nodocs -y && \
    systemctl mask systemd-remount-fs.service && \
    systemctl enable spice-vdagentd.service tuned.service tuned-ppd.service && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/* \
    /var/usrlocal/share/applications/mimeinfo.cache \
    /var/roothome/.*

# Limpeza de diretórios de runtime.
# O `bootc container lint` avisa (nonempty-run-tmp) quando sobra conteúdo
# em /run ou /tmp, porque essas pastas são recriadas a cada boot.
RUN rm -rfv /run/dnf /run/selinux-policy /tmp/* /var/tmp/*

# Verificação da imagem
RUN bootc container lint