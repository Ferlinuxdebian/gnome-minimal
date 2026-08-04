# Imagem base única (não precisa mais de multi-stage builder para drivers)
FROM quay.io/fedora/fedora-bootc:44 
# Copia apenas os arquivos necessários (removido scripts e configs da NVIDIA)
COPY locale.conf post-install.sh pacotes_desktop pacotes_necessarios post-install.service vconsole.conf zram-generator.conf ./

RUN mkdir -vp /var/roothome /data /var/home && \
    dnf5 -y upgrade --refresh --setopt=tsflags=nodocs && \
    dnf5 -y install kernel-modules-extra wget --refresh --setopt=tsflags=nodocs && \
    # Configurações de sistema
    mv -v zram-generator.conf /usr/lib/systemd/zram-generator.conf.d/10-zram.conf || mv -v zram-generator.conf /etc/systemd/ && \
    mv -v vconsole.conf /etc/vconsole.conf && \
    mv -v locale.conf /etc/locale.conf && \
    # Organização de diretórios e links simbólicos para persistência
    rm -rvf /opt && mkdir -vp /var/opt && ln -vs /var/opt /opt && \
    mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null && \
    rm -rvf /usr/local && ln -vs /var/usrlocal /usr/local && \
    # Script de pós-instalação
    mv -v post-install.sh /usr/bin/post-install.sh && \
    mv -v post-install.service /usr/lib/systemd/system/post-install.service && \
    chmod +x /usr/bin/post-install.sh && \
    systemctl enable post-install.service && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/*

# Instalação dos pacotes definidos nos arquivos de lista
RUN grep -v '^#' pacotes_necessarios | tr '\n' ' ' | xargs dnf5 install --setopt=tsflags=nodocs -y && \
    grep -v '^#' pacotes_desktop | tr '\n' ' ' | xargs dnf5 install --setopt=tsflags=nodocs -y && \
    systemctl mask systemd-remount-fs.service && \
    systemctl enable spice-vdagentd.service && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/* \
    /var/usrlocal/share/applications/mimeinfo.cache \
    /var/roothome/.*

# Verificação da imagem
RUN bootc container lint