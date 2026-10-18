FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/library/python:3.12-slim-bookworm

WORKDIR /app

RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple uv

COPY pyproject.toml uv.lock langgraph.json README.md ./
COPY src ./src

ENV UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
RUN uv sync --dev --frozen || uv sync --dev
ENV LC_OUTPUT_VERSION=v0

EXPOSE 2024

CMD ["uv", "run", "langgraph", "dev", "--host", "0.0.0.0", "--port", "2024", "--no-browser", "--no-reload"]
