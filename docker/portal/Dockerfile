FROM debian:12-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends -qq \
        python3 python3-venv python3-pip supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/supervisor /opt/shared /var/lib/portal

RUN python3 -m venv /opt/venv
COPY docker/portal/requirements.txt /opt/app/requirements.txt
RUN /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
        -r /opt/app/requirements.txt

COPY docker/generate_flags.py /opt/shared/generate_flags.py
COPY docker/portal/app.py /opt/app/app.py
COPY docker/portal/seed.py /opt/app/seed.py
COPY docker/portal/entrypoint.sh /opt/entrypoint.sh
COPY docker/portal/supervisord.conf /etc/supervisor/conf.d/ctf.conf
RUN chmod +x /opt/entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/opt/entrypoint.sh"]
