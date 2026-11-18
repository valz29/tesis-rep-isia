FROM python:3.12-slim
WORKDIR /srv/retinazo
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.lock pyproject.toml ./
RUN pip install --no-cache-dir -r requirements.lock
COPY retinazo_api ./retinazo_api
RUN pip install --no-cache-dir --no-deps . && useradd --create-home --uid 10001 app
USER app
EXPOSE 8000
CMD ["sh", "-c", "exec uvicorn retinazo_api.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1 --limit-concurrency 4 --no-access-log"]
