# Python Web Service

This is a Python web service containerized for production.

## Setup

To build the container, run:

```
docker build -t my-python-app . 
```

To run the container, execute:

```
docker run -d -p 5000:5000 my-python-app
```
