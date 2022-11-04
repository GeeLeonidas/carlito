FROM docker.io/mambaorg/micromamba:0.27.0
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yaml /tmp/env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes

COPY --chown=$MAMBA_USER:$MAMBA_USER ./src/bot.py /usr/bin/carlito.py
CMD ["/usr/bin/pypy3", "/usr/bin/carlito.py"]