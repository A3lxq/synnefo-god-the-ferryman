FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor \
        openssh-client sshpass \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /opt/shared

RUN python3 -m venv /opt/venv
COPY docker/waystation/requirements.txt /opt/app/requirements.txt
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
        -r /opt/app/requirements.txt

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/waystation/app.py /opt/app/app.py
COPY docker/waystation/entrypoint.sh /opt/entrypoint.sh
COPY docker/waystation/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

EXPOSE 7000
# Never published in docker-compose.yml -- internal-only on purpose.

ENTRYPOINT ["/opt/entrypoint.sh"]
