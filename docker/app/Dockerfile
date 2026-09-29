# Customizes infrastructureascode/hello-world (upstream already serves "/" hello message,
# "/health" health check, and "/metrics" Prometheus metrics on port 8080).
FROM infrastructureascode/hello-world:latest

LABEL maintainer="broken-cloud-pipeline" \
      description="App image deployed to the 10.40.0.0/16 ECS cluster via Jenkins"

EXPOSE 8080
