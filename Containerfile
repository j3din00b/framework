ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR}:-main"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-${BASE_IMAGE_NAME}${IMAGE_FLAVOR}}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-38}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS framework
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-38}"

# Store a copy of files so we not have to polute
# every image with image specific files.
COPY system_files/ /tmp/
# Copy shared files between all images.
COPY system_files/shared /
COPY framework-install.sh /tmp/framework-install.sh
COPY framework-packages.json /tmp/framework-packages.json

# Remove Deck services when building for Ally
RUN if grep -q "deck" <<< ${BASE_IMAGE_NAME}; then \
    systemctl disable jupiter-fan-control.service && \
    systemctl disable jupiter-biosupdate.service && \
    systemctl disable jupiter-controller-update.service && \
    systemctl disable vpower.service && \
    systemctl --global disable sdgyrodsu.service && \
    rpm-ostree override remove \
        jupiter-fan-control \
        jupiter-hw-support-btrfs \
        powerbuttond \
        vpower \
        sdgyrodsu && \
    rm -rf /usr/lib/jupiter-dock-updater \
; fi

# Setup specific files and commands for Silverblue based flavors
# like bluefin so they end up with nice backgrounds and settings
RUN if grep -q "silverblue\|bluefin\|bazzite-gnome\|bazzite-deck-gnome" <<< "${BASE_IMAGE_NAME}"; then \
    rsync -rvK /tmp/silverblue/ / && \    
    systemctl enable dconf-update \
; fi

# Setup things which are the same for every image
RUN wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-$(rpm -E %fedora)/ublue-os-staging-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_ublue-os_staging.repo && \
    /tmp/framework-install.sh && \
    systemctl enable tlp && \
    systemctl enable fprintd && \
    cat /tmp/just/custom.just >> /usr/share/ublue-os/just/60-custom.just && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os_staging.repo && \
    rm -rf /tmp/* /var/* && \
    ostree container commit && \
    mkdir -p /var/tmp && chmod -R 1777 /tmp /var/tmp
