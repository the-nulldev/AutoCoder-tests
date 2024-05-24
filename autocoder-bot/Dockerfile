{
  "content": "FROM python:3.9-slim AS build-stage

WORKDIR /app

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.9-slim AS final-stage

WORKDIR /app

COPY --from=build-stage /app .

COPY entrypoint.sh ./

CMD [\"./entrypoint.sh\"]"
}
