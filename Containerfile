# Imagem base única (não precisa mais de multi-stage builder para drivers)
FROM quay.io/fedora/fedora-bootc:44 AS final
LABEL ostree.bootable="true"
LABEL containers.bootc="1"

# Copia apenas os arquivos necessários (removido scripts e configs da NVIDIA)
COPY locale.conf post-install.sh pacotes_desktop pacotes_necessarios post-install.service vconsole.conf zram-generator.conf ./

RUN mkdir -vp /var/roothome /data /var/home && \
    dnf5 -y upgrade --refresh && \
    dnf5 -y install kernel-modules-extra --refresh && \
    # Otimização do Dracut para remover módulos NFS desnecessários
    printf 'omit_dracutmodules+=" nfs "\nomit_drivers+=" nfs nfsv3 nfsv4 nfs_acl nfs_common sunrpc rxrpc rpcrdma auth_rpcgss rpcsec_gss_krb5 "\n' | tee /etc/dracut.conf.d/no-nfs.conf >/dev/null && \
    kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dracut -f /usr/lib/modules/${kver}/initramfs.img ${kver} && \
    dnf5 -y install wget && \
    # Configurações de sistema
    mv -v zram-generator.conf /etc/systemd/ && \
    mv -v vconsole.conf /etc/vconsole.conf && \
    mv -v locale.conf /etc/locale.conf && \
    # Organização de diretórios e links simbólicos para persistência
    mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null && \
    rm -rvf /usr/local && ln -vs /var/usrlocal /usr/local && \
    # Script de pós-instalação
    mv -v post-install.sh /usr/bin/post-install.sh && \
    mv -v post-install.service /usr/lib/systemd/system/post-install.service && \
    chmod +x /usr/bin/post-install.sh && \
    systemctl enable post-install.service && \
    # instalação do FortiClient
    rm -rvf /opt && mkdir -vp /usr/opt && ln -vs /usr/opt /opt && \
    wget -O /etc/yum.repos.d/fortinet.repo \
    https://repo.fortinet.com/repo/forticlient/8.0/el/os/x86_64/fortinet.repo && \
    dnf -y install forticlient && \
    # limpeza final
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/*

# Instalação do gnome-shell minimalista
RUN dnf5 install gnome-shell --setopt=install_weak_deps=False -y && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/*

# Instalação dos pacotes definidos nos arquivos de lista
RUN grep -v '^#' pacotes_necessarios | tr '\n' ' ' | xargs dnf5 install -y && \
    grep -v '^#' pacotes_desktop | tr '\n' ' ' | xargs dnf5 install -y && \
    systemctl mask systemd-remount-fs.service && \
    systemctl enable spice-vdagentd.service && \
    dnf5 clean all && \
    rm -rfv /var/cache/* /var/lib/* /var/log/* /var/tmp/* \
    /var/usrlocal/share/applications/mimeinfo.cache \
    /var/roothome/.*

# Verificação da imagem
RUN bootc container lint

# Estágio final de otimização com Chunkah
FROM quay.io/coreos/chunkah AS chunkah
ARG CHUNKAH_CONFIG_STR
RUN --mount=from=final,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
    chunkah build --max-layers 128 \
    --label ostree.commit- \
    --label ostree.final-diffid- \
    > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive
LABEL ostree.bootable="true"
LABEL containers.bootc="1"
