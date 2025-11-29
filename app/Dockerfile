FROM python:3.12-slim

WORKDIR /app

# Basic security hardening: no cache, minimal packages
RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

ENV APP_ENV=dev
ENV PORT=8080

EXPOSE 8080

CMD ["python", "main.py"]
