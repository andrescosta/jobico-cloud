FROM quay.io/buildah/stable:latest

RUN yum -y install git

RUN touch /etc/subgid /etc/subuid \
 && chmod g=u /etc/subgid /etc/subuid /etc/passwd \
 && echo build:10000:65536 > /etc/subuid \
 && echo build:10000:65536 > /etc/subgid

RUN echo "export BUILDAH_ISOLATION=chroot" >> /home/build/.bashrc

# Use overlay
RUN mkdir -p /home/build/.config/containers \
 && (echo '[storage]';echo 'driver = "overlay"') > /home/build/.config/containers/storage.conf

USER build
WORKDIR /home/build

CMD ["/bin/bash"]
