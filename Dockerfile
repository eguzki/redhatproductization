FROM registry.access.redhat.com/ubi7/ubi:latest

MAINTAINER Eguzki Astiz Lezaun <eastizle@redhat.com>

# User and password for Red Hat subscription.
ARG RHEL_SUB_USER
ARG RHEL_SUB_PASSWD

RUN if test "x${RHEL_SUB_USER}" != "x" -a "x${RHEL_SUB_PASSWD}" != "x"; then \
        (subscription-manager unregister || true) \
        && subscription-manager clean \
        && echo "Subscribing (takes a while)" \
        && subscription-manager register --auto-attach \
          --username=${RHEL_SUB_USER} --password=${RHEL_SUB_PASSWD} ; \
    else \
        echo >&2 "RHEL_SUB_USER and RHEL_SUB_PASSWD are required for subscriptions." ; \
        exit 1 ; \
    fi

RUN echo "Installing Red Hat CA certificates" \
 && yum install -y wget sudo yum-utils \
 && rpm -i http://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/redhat-internal-cert-install-0.1-9.el7.csb.noarch.rpm

RUN echo "Fetching RCM tools" \
 && cd /etc/yum.repos.d \
 && curl -L -O https://download.devel.redhat.com/devel/candidate-trees/RCMTOOLS/rcm-tools-rhel-7-server.repo \
 && INSTALL_PKGS="authconfig \
    krb5-workstation \
    koji \
    brewkoji \
    rhpkg" \
 && yum install -y ${INSTALL_PKGS} \
 && rpm -V ${INSTALL_PKGS} \
 && yum clean all -y \
 && rm -rf /var/cache/yum \
 && echo "Configuring system files" \
 && sed -i -E -e 's/^\# default_realm =.*/&\n default_realm = REDHAT.COM/' /etc/krb5.conf

RUN echo "Installing Docker CE client" \
 && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
 && yum install -y docker-ce-cli

RUN echo "Installing several tools" \
 && INSTALL_PKGS="bind-utils \
    python3-pip.noarch \
    vim-enhanced" \
 && yum install -y ${INSTALL_PKGS} \
 && rpm -V ${INSTALL_PKGS} \
 && yum clean all -y \
 && rm -rf /var/cache/yum \
 && pip3 install operator-courier 

WORKDIR /home/prod

ADD clone_repos.sh /home/prod

CMD ["/bin/bash"]
