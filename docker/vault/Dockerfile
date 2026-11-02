FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        openssh-server python3 python3-venv python3-pip supervisor sudo openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /opt/shared

RUN python3 -m venv /opt/venv
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 cryptography==43.0.3

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/flagcrypto.py /opt/shared/flagcrypto.py
COPY docker/vault/entrypoint.sh /opt/entrypoint.sh
COPY docker/vault/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

RUN useradd -m -s /bin/bash traveler

EXPOSE 22
# Never published in docker-compose.yml -- internal-only on purpose.

ENTRYPOINT ["/opt/entrypoint.sh"]
