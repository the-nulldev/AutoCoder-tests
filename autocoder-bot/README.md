# Python Web Service

This is a Python web service containerized using Docker. To build and run the container, follow these steps:

1. Build the Docker image:
```
docker build -t my-python-web-service .
```

2. Run the Docker container:
```
docker run -d -p 5000:5000 my-python-web-service
```
