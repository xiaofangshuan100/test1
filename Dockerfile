FROM debian as base
ENV DEBIAN_FRONTEND noninteractive
ARG USERNAME=code
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV NVM_DIR=/usr/local/share/nvm
ARG NPM_GLOBAL=/usr/local/share/npm-global
ARG SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWdb5nIjRvmCiLYBcoKXX6Qd4AdNv3pvgj7GPE6m1l1"
COPY ./vendors/library-scripts/*.sh /tmp/library-scripts/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && mkdir ~/.ssh -m 700 \
    #连pip一起安装，因为安装python3.9的脚本用到 python3 -m pip
    && apt install -y python3-pip python3-venv python3-dev python3-distutils \
    # Remove imagemagick due to https://security-tracker.debian.org/tracker/CVE-2019-10131
    && apt-get purge -y imagemagick imagemagick-6-common \
    # Install common packages, non-root user
    && echo "安装 common-debian.sh" \
    && bash /tmp/library-scripts/common-debian.sh "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    # && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
    && echo "安装 node-debian.sh" \
    && bash /tmp/library-scripts/node-debian.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}"\
    # 自定义包
    && DEBIAN_FRONTEND=noninteractive && apt update && apt install -y --no-install-recommends \
    apt-transport-https \
    gnupg2 \
    pass \
    sudo \
    curl \
    wget \
    ssh \
    iptables \
    dnsutils \
    net-tools \
    tree \
    rsync \
    sqlite3 \
    ncat \
    socat \
    openvpn \
    tor \
    git \
    inetutils-ping \
    nginx \
    traceroute \
    dnsmasq \
    firejail \
    busybox \
    unzip \
    python3-venv \
    python3-distutils \
    gcc \
    g++ \
    make \
    htop \
    nano \
    ncdu \
    uwsgi \
    uwsgi-plugin-python3 

RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get install -y nodejs \
    # Install npm , yarn, nvm
    && npm install -g npm@7.18.1 \
    && rm -rf /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg \
    && bash /tmp/library-scripts/azcli-debian.sh \    
    && echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable-wireguard.list \
    && printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable \
    && apt update && apt install -y wireguard-dkms wireguard-tools \
    # 由于 wg-quick命令依赖resolvconf包,安装时处理服务的过程失败，所以报纸RUN安装不成功。用bash -c 的方式，目的是屏蔽exit 非零，好让docker build 继续执行后面的指令
    #&& bash -c "apt install -y resolvconf; exit 0" \
    #
    && mkdir ~/.ssh -m 700 ; ssh-keyscan github.com >> ~/.ssh/known_hosts \
    && git config --global user.name a  \
    && git config --global user.email a@a.a \
    # 
    && touch ~/.ssh/authorized_keys \
    && chmod 700 ~/.ssh/authorized_keys \
    && echo ${SSH_PUB_KEY} > ~/.ssh/authorized_keys \
    #
    # 安装dind环境,容器启动后，启动docker服务的命令是：/usr/local/share/docker-init.sh \
    && apt-get update -q && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh \
    && sudo apt remove -y docker-compose \
    && sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && sudo chmod +x /usr/local/bin/docker-compose \
    && sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose \    
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*


COPY ./vendors/docker_build_scripts/install-base.sh /tmp/install-base.sh
RUN bash /tmp/install-base.sh
COPY ./entry /entry
RUN chmod +x /entry
ENTRYPOINT [ "/entry" ]
VOLUME [ "/var/lib/docker" ]

FROM base as base-desktop

RUN apt update && export DEBIAN_FRONTEND=noninteractive  && apt-get install --no-install-recommends -q -y \
    tigervnc-standalone-server \
    tigervnc-common \
    fluxbox \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xdg-utils \
    fbautostart \
    at-spi2-core \
    xterm \
    eterm \
    tilix \
    nautilus\
    mousepad \
    seahorse \
    gnome-icon-theme \
    gnome-keyring \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    libgbm-dev \
    libnotify4 \
    libnss3 \
    libxss1 \
    libasound2 \
    xfonts-base \
    xfonts-terminus \
    fonts-noto \
    fonts-wqy-microhei \
    fonts-droid-fallback \
    locales \
    #
    && apt update -q && export DEBIAN_FRONTEND=noninteractive && apt install -y -q \
    apt-transport-https gnupg2 sudo curl wget ssh openssh-server iptables net-tools \
    ncat socat openvpn tor git inetutils-ping nginx traceroute dnsmasq firejail busybox unzip \    
    && apt-get autoremove -y && apt-get clean -y \
    # 先安装必备软件
    && apt update && apt install -y firefox-esr && \
    apt install -y -q fonts-liberation libasound2 libgbm1 libnspr4 libnss3 libnss3 xdg-utils && \
    wget -q -O 1.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    sudo dpkg -i 1.deb \
    && rm 1.deb \
    && apt-get autoremove -y && apt-get clean -y \
    # 微软的安装chrome方法。
    &&apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb \
    && apt-get -y install /tmp/chrome.deb \
    && ALIASES="alias google-chrome='google-chrome --disable-dev-shm-usage'\nalias google-chrome-stable='google-chrome-stable --disable-dev-shm-usage'\n\alias x-www-browser='x-www-browser --disable-dev-shm-usage'\nalias gnome-www-browser='gnome-www-browser --disable-dev-shm-usage'" \
    && echo "${ALIASES}" >> tee -a /etc/bash.bashrc \
    && if type zsh > /dev/null 2>&1; then echo "${ALIASES}" >> /etc/zsh/zshrc; fi \
    ##  安装vscode
    && apt install -q -y gnupg libgbm1 libxss1 libgtk-3-0 libnss3 libxkbfile1 libsecret-1-0 && \
    wget -q -O 1.deb https://go.microsoft.com/fwlink/?LinkID=760868 \
    && sudo dpkg -i 1.deb && sudo rm 1.deb \
    && apt-get autoremove -y && apt-get clean -y

RUN bash /tmp/library-scripts/desktop-lite-debian.sh
